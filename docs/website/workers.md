# Website – Workers per sessie

[← Terug naar de website-map](README.md)

Elke sessie krijgt een eigen tijdelijke worker: een kleine container waarop de challenges van die sessie draaien. Deze pagina beschrijft hoe dat werkt en wat er in de app is aangepast. De automatisering (Terraform en Ansible) staat in [automatisering.md](../cluster1/automatisering.md) en de firewallregels in [netwerk-workers.md](netwerk-workers.md).

## Overzicht

| Onderdeel | Waarde |
| --- | --- |
| Wat is een worker | Tijdelijke LXC-container met Docker en Traefik, één per sessie |
| Waar draait het | Verdeeld over pve001, pve002 en pve003 (VMID 300 t/m 399), disk op `ceph-vm` |
| Netwerk | Challenges-VLAN (VLAN 20), IP-adres `192.168.20.<VMID min 200>`, dus `192.168.20.100` t/m `.199` |
| Formaat | 2 cores, 4 GB RAM, 1 GB swap, 25 GB disk |
| Aangemaakt door | CT101 (`Ubuntu-server-automation`, 192.168.10.21) met Terraform en Ansible |
| Aangeroepen door | WEB-01 (192.168.10.22), via SSH met een beperkte sleutel |
| Maximum | 5 workers tegelijk |
| Levensduur | Tot de sessie stopt of klaar is, anders na 8 uur automatisch verwijderd |
| Challenge-images | Private registry op CT213 (docker02): `192.168.20.31:5000` |

## Hoe het werkt

1. De beheerder start een sessie voor een team in het admin panel (**Start** of **Pakket**).
2. De API op WEB-01 vraagt CT101 om een worker: `create <sessie-id> <challenge-id's>`.
3. CT101 kiest een vrije VMID (300 t/m 399), maakt de container met Terraform en zet er met Ansible Docker, Traefik en de challenge-images op. Dat duurt ongeveer 50 seconden. CT101 antwoordt met `WORKER_IP=192.168.20.1xx`.
4. De API start de eerste challenge op die worker (`docker run` via SSH, gebruiker `team`). De challenge krijgt een id met het worker-nummer ervoor, bijvoorbeeld `100-3ed1f80c`. Het `100` is de worker `192.168.20.100`.
5. De speler opent `/c/100-3ed1f80c/`. Nginx haalt het worker-nummer uit het pad en stuurt door naar `192.168.20.100:8081` (Traefik op de worker).
6. Bij een goed antwoord start de volgende challenge op **dezelfde worker** en wordt de vorige verwijderd.
7. Bij **Stop**, bij het afronden van de sessie of bij een mislukte start roept de API `destroy <sessie-id>` aan en verdwijnt de worker. Een cron op CT101 verwijdert workers die ouder zijn dan 8 uur.

Antwoorden en scores gaan niet via de worker: de speler stuurt het antwoord naar de API op WEB-01 en die schrijft het resultaat naar DB01. De workers hebben geen toegang tot DB01.

```
Beheerder start sessie (admin panel)
        │
        ▼
WEB-01 (API) ── SSH: create <sessie-id> <challenges> ──► CT101 (Terraform + Ansible)
        │                                                  │ maakt de worker (±50 s)
        │◄──────────── WORKER_IP=192.168.20.1xx ───────────┘
        │
        ├── SSH: docker run ──────────────► Worker 192.168.20.1xx (Traefik :8081 + challenge)
        │
Speler ─► Nginx /c/1xx-<id>/ ────────────► Worker 192.168.20.1xx:8081
```

## Wat is er veranderd in de app

De app staat op WEB-01 in `/opt/challengelab`. Er is één bestand bij gekomen en twee zijn aangepast. Ook nginx is aangepast.

| Bestand | Wijziging |
| --- | --- |
| `worker_service.py` (nieuw) | Praat met CT101: `create_worker` en `destroy_worker`. Time-out van 270 seconden. Bij een fout wordt de melding van CT101 doorgegeven en wordt de worker opgeruimd. |
| `docker_service.py` | `run_remote()` krijgt een optionele `host`. `start_instance()` krijgt een `worker`-parameter en zet het worker-nummer voor de instance-id. `remove_instance()` en `instance_exists()` halen de worker uit de instance-id. Zonder nummer in de id gebruikt de app nog `DOCKER_HOST` (DOCKER01). |
| `session_service.py` | `start_session` maakt eerst de worker. Stoppen, afronden en een mislukte start verwijderen de worker. De volgende challenge start op de worker van de vorige. Een slot per team voorkomt dat een sessie twee keer tegelijk wordt gestart. |
| nginx (`/etc/nginx/sites-available/challenges`) | Nieuw blok voor `/c/1xx-…` naar `192.168.20.1xx:8081`. Bij `/api/` staat `proxy_read_timeout 300s`, omdat starten ongeveer een minuut duurt. Het oude `/c/`-blok blijft voor sessies zonder worker. |
| `/etc/challengelab.env` | Met `CHALLENGELAB_WORKERS=0` zet je de workers uit. Standaard staan ze aan. |

De kern in `docker_service.py`:

```python
def start_instance(challenge_id: str, worker: str | None = None) -> dict:
    ...
    if worker:
        instance_id = f"{worker}-{instance_id}"
    ...
    container_id = run_remote(command, host=worker_host(instance_id))
```

De bestanden staan in [configs/workers/](configs/workers/). De volledige verschillen staan op CT101 in `~/ansible-ironhold/webapp-wijzigingen/` (git-commit `a0488bb`).

---

## Installatie (zo is het gedaan)

### Stap 1: snapshot maken

Waar: **pve002 > Shell** (CT102 staat daar)

```
pct snapshot 102 voor-worker-aanpassing --description "voor aanpassing naar per-sessie workers"
pct listsnapshot 102
```

### Stap 2: app aanpassen

Waar: **pve002 > Shell**

1. Zet [worker_service.py](configs/workers/app/worker_service.py) in `/opt/challengelab`:

```
pct push 102 worker_service.py /opt/challengelab/worker_service.py --user team --group team --perms 664
```

2. Pas `docker_service.py` en `session_service.py` aan zoals in de tabel hierboven. Werk op een kopie (`pct pull`), controleer met `diff` en `python3 -m py_compile` en zet het daarna terug met `pct push`.

### Stap 3: nginx aanpassen

Waar: **pve002 > Shell**

1. Maak een back-up: `pct exec 102 -- cp /etc/nginx/sites-available/challenges /etc/nginx/sites-available/challenges.bak-<datum>`
2. Voeg het blok uit [nginx/workers-blok.conf](configs/workers/nginx/workers-blok.conf) toe vóór `location /c/ {` en zet `proxy_read_timeout 300s;` bij `location /api/`.
3. Test en laad opnieuw:

```
pct exec 102 -- nginx -t
pct exec 102 -- systemctl reload nginx
```

### Stap 4: app herstarten

Waar: **pve002 > Shell**

```
pct exec 102 -- systemctl restart challengelab
pct exec 102 -- journalctl -u challengelab -n 6 --no-pager
```

Verwacht: `Application startup complete` en geen `Traceback`.

---

## Controleren

Getest op 16 oktober 2026.

| Test | Resultaat |
| --- | --- |
| Sessie starten in het admin panel (**Start** of **Pakket**) | Na ongeveer 1 minuut "Sessie gestart". De URL bevat `/c/1xx-…/` en de challenge laadt. |
| `breachout-worker list` op CT101 | Regel met sessie-id, VMID en IP |
| Twee keer snel op **Start** klikken | De tweede klik geeft "Er wordt al een sessie voor dit team gestart". Er komt geen extra worker. |
| `MAX_WORKERS=1 breachout-worker create test-limiet-0001 vergeten-medewerker` op CT101 | "maximum aantal workers (1) bereikt", exitcode 1, niets aangemaakt |
| Goed antwoord geven | De volgende challenge start op dezelfde worker. De oude container is weg (`ssh root@<worker-ip> docker ps` op CT101). |
| **Stop** bij Sessies in het admin panel | De worker verdwijnt uit `breachout-worker list` en uit Proxmox |
| Spreiding over de nodes | Bij 6 workers: 2 per node |

## Beheer

Waar: **CT101** (`root@Ubuntu-server-automation`)

| Wat | Commando |
| --- | --- |
| Draaiende workers bekijken | `breachout-worker list` |
| Een worker verwijderen | `breachout-worker destroy <sessie-id>` |
| Workers ouder dan 8 uur verwijderen | `breachout-worker cleanup` |
| Logboek van het aanmaken | `tail -f /var/log/breachout-worker.log` |
| Docker op een worker bekijken | `ssh root@192.168.20.1xx docker ps` |

Waar: **pve002 > Shell** (WEB-01)

| Wat | Commando |
| --- | --- |
| Logboek van de app | `pct exec 102 -- journalctl -u challengelab -n 50 --no-pager` |
| Workers uitzetten (terug naar DOCKER01) | Zet `CHALLENGELAB_WORKERS=0` in `/etc/challengelab.env` en draai `pct exec 102 -- systemctl restart challengelab` |
| Alles terugzetten naar de situatie van vóór de aanpassing | `pct rollback 102 voor-worker-aanpassing` |

## Problemen oplossen

| Probleem | Oplossing |
| --- | --- |
| Starten duurt ongeveer een minuut | Dat is normaal, de worker wordt dan aangemaakt. Klik niet nog een keer. |
| "Er wordt al een sessie voor dit team gestart" | Wacht tot de eerste start klaar is (ongeveer 1 minuut). |
| "maximum aantal workers (5) bereikt" | Stop een sessie in het admin panel, of verwijder een oude worker met `breachout-worker list` en `breachout-worker destroy <sessie-id>`. |
| "Worker aanmaken duurde te lang" | Probeer het opnieuw. Kijk in `/var/log/breachout-worker.log` op CT101. Een achtergebleven worker staat in `breachout-worker list`. |
| Challenge laadt niet via `/c/1xx-…` | Controleer of de worker draait (`breachout-worker list`, Proxmox), of FortiGate-regel 22 hits heeft (zie [netwerk-workers.md](netwerk-workers.md)) en of de challenge draait (`docker ps` op de worker). |
| Worker staat nog terwijl de sessie weg is | `breachout-worker destroy <sessie-id>` op CT101. De cron ruimt hem na 8 uur op, maar alleen als CT101 en het cluster aan stonden. |
| Alles hangt en Proxmox toont vraagtekens na een herstart | Waarschijnlijk zijn Ceph-OSD's niet gestart. Zie [automatisering.md](../cluster1/automatisering.md#problemen-oplossen). |

## Let op

- De workers staan in hetzelfde VLAN (VLAN 20). Sessies kunnen elkaar daardoor op netwerkniveau bereiken. Isolatie per sessie (FW-05) is nog niet ingesteld.
- Workers worden achter elkaar aangemaakt (ongeveer 50 seconden per worker). Bij meerdere sessies tegelijk wacht de laatste het langst.
- De app start nog steeds één challenge tegelijk per team. De volgende start na een goed antwoord.
- De start-knop in het admin panel is tijdens het wachten niet uitgeschakeld. De API vangt een tweede klik wel af.
- Sessies van vóór deze aanpassing (zonder worker) draaien nog op DOCKER01.
- Zet nooit wachtwoorden of tokens in deze map.

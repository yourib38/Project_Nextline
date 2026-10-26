# Cluster1 – Automatisering (Ansible en Terraform)

[← Terug naar README](../../README.md)

Met Ansible en Terraform maken we per sessie automatisch een worker aan en weer weg. Dit staat op CT101. De uitleg voor de website staat in [workers.md](../website/workers.md), de firewallregels in [netwerk-workers.md](../website/netwerk-workers.md).

## Overzicht

| Onderdeel | Waarde |
| --- | --- |
| Waar draait het | Container 101 (`Ubuntu-server-automation`), 192.168.10.21 (Node-VLAN) |
| Terraform | Map `/root/terraform-workers`, provider `bpg/proxmox` (versie `~> 0.66`), endpoint `https://192.168.10.11:8006/` |
| Ansible | Map `~/ansible-ironhold` (git, alleen lokaal), rol `breachout_worker` |
| Aanmelden bij Proxmox | API-token in de omgevingsvariabele `PROXMOX_VE_API_TOKEN`, het script leest die uit `/root/.pve_token` (buiten git) |
| SSH naar de workers | Sleutel `/root/.ssh/ansible_key` |
| Beheerscript | `/usr/local/bin/breachout-worker` (maakt, verwijdert en toont workers) |
| Aanroep door de webserver | `/usr/local/bin/breachout-provision`, alleen via een beperkte SSH-sleutel van WEB-01 |
| Registry voor de challenge-images | Container 213 (docker02), `192.168.20.31:5000` |

## Hoe het werkt

Terraform maakt de container, Ansible richt hem in en een script verbindt die twee.

1. WEB-01 roept via SSH `create <sessie-id> <challenge-id's>` aan. De sleutel van WEB-01 mag alleen `breachout-provision` uitvoeren.
2. `breachout-provision` controleert de invoer en roept `breachout-worker` aan.
3. `breachout-worker create` kiest een vrije VMID (300 t/m 399) en maakt met Terraform een workspace per sessie. De node volgt uit de VMID (VMID modulo 3: pve001, pve002 of pve003).
4. Het script wacht tot SSH op de worker antwoordt en draait daarna het Ansible-playbook `worker.yml`.
5. Het script geeft `WORKER_IP=192.168.20.1xx` terug. Mislukt Terraform of Ansible, dan ruimt het script de worker zelf op.
6. `breachout-worker destroy <sessie-id>` verwijdert de worker en de workspace.
7. Een cron op CT101 (elke 10 minuten, als root) draait `breachout-worker cleanup` en verwijdert workers die ouder zijn dan 8 uur.

Alle acties lopen achter elkaar (`flock`), zodat twee aanvragen niet tegelijk in dezelfde Terraform-map werken. Een worker maken duurt ongeveer 50 seconden, verwijderen ongeveer 4 seconden.

## De worker

| Onderdeel | Waarde |
| --- | --- |
| Type | Unprivileged LXC met alleen `nesting` (geen `keyctl`) |
| Naam | `worker-<eerste 8 tekens van het sessie-id>` |
| IP-adres | `192.168.20.<VMID min 200>/24`, gateway en DNS `192.168.20.1`, VLAN 20 op `vmbr0` |
| Formaat | 2 cores, 4096 MB RAM, 1024 MB swap, 25 GB op `ceph-vm` |
| Template | `local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst` (staat op alle drie de nodes) |
| Opstarten | `start_on_boot = false`, geen HA: een worker wordt vervangen en niet hersteld |
| Tag | `breachout-worker` |

Wat de Ansible-rol `breachout_worker` doet:

| Taak | Wat gebeurt er |
| --- | --- |
| Docker | Installeert `docker.io` en zet de registry als insecure registry in `/etc/docker/daemon.json` |
| Gebruiker | Maakt de gebruiker `team` in de groep `docker` en zet de publieke sleutel van WEB-01 in `authorized_keys` |
| Netwerk | Maakt het Docker-netwerk `challenge-net` |
| Traefik | Start `challengelab-proxy` (`traefik:v3`) op poort 8081, met `--restart unless-stopped` |
| Images | Haalt per challenge `192.168.20.31:5000/challengelab/<id>:1.0` op en geeft de image ook de naam `challengelab/<id>:1.0` |

De bestanden staan in [../website/configs/workers/](../website/configs/workers/).

---

## Installatie (zo is het gedaan)

### Stap 1: Terraform voorbereiden

Waar: **CT101**

1. Zet de bestanden uit `configs/workers/terraform/` in `/root/terraform-workers` (zelfde mappenstructuur).
2. Maak een API-token in Proxmox (Datacenter > Permissions > API Tokens) en zet de waarde in `/root/.pve_token`. Zet dit bestand nooit in git.
3. Initialiseer: `cd /root/terraform-workers && terraform init`

### Stap 2: registry starten

Waar: **CT101**

```
cd ~/ansible-ironhold
ansible-playbook -i inventory-v2.ini registry.yml
```

Het playbook draait op de groep `docker` van de inventory (docker02). Dit start `challengelab-registry` (`registry:2`) op docker02 (poort 5000, data in `/opt/registry`). De challenge-images zijn daarna in de registry gezet (20 stuks).

### Stap 3: Ansible-rol en variabelen

Waar: **CT101**

1. Zet `roles/breachout_worker/`, `worker.yml` en `worker_vars.yml` in `~/ansible-ironhold`.
2. In `worker_vars.yml` staat de publieke sleutel van WEB-01 (`breachout_web_pubkey`). Dit is een publieke sleutel, geen geheim.

### Stap 4: beheerscript en beperkte aanroep

Waar: **CT101**

1. Zet [breachout-worker.sh](../website/configs/workers/scripts/breachout-worker.sh) als `/usr/local/bin/breachout-worker` en [breachout-provision.sh](../website/configs/workers/scripts/breachout-provision.sh) als `/usr/local/bin/breachout-provision` (`chmod +x`).
2. Zet de publieke sleutel van WEB-01 in `/root/.ssh/authorized_keys`, met opties die de sleutel beperken:

```
from="192.168.10.22",command="/usr/local/bin/breachout-provision",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding ssh-ed25519 AAAA... team@WEB-01
```

(Voorbeeld, sleutel ingekort.) Met `command=` kan WEB-01 alleen dit ene script uitvoeren, en alleen vanaf zijn eigen adres.

3. Maak een cron als root die elke 10 minuten `/usr/local/bin/breachout-worker cleanup` draait.

### Stap 5: Prometheus

Docker02 en web02 draaien `prometheus-node-exporter` (Ansible-playbook `node_exporter.yml`). In `/etc/prometheus/prometheus.yml` op MON-01 staat de job `node` met `192.168.40.22:9100` en `192.168.20.31:9100` onder de targets. De workers zelf worden niet gemonitord, want ze zijn tijdelijk.

---

## Controleren

Waar: **CT101**

```
breachout-worker create test-sessie-0001 vergeten-medewerker,het-dns-spoor
breachout-worker list
ssh root@192.168.20.1xx docker ps
breachout-worker destroy test-sessie-0001
```

| Test | Verwacht resultaat |
| --- | --- |
| `create` | Na ongeveer 50 seconden `WORKER_IP=192.168.20.1xx` |
| `list` | Regel met sessie-id, VMID en IP |
| `docker ps` op de worker | `challengelab-proxy` draait |
| `destroy` | "worker voor sessie … verwijderd", container weg in Proxmox |
| `MAX_WORKERS=1 breachout-worker create test-limiet-0001 vergeten-medewerker` | "maximum aantal workers (1) bereikt" |

## Beheer

Waar: **CT101**

| Wat | Commando |
| --- | --- |
| Workers bekijken | `breachout-worker list` |
| Worker verwijderen | `breachout-worker destroy <sessie-id>` |
| Oude workers verwijderen | `breachout-worker cleanup` |
| Logboek | `tail -f /var/log/breachout-worker.log` |
| Maximum aanpassen | Pas `MAX_WORKERS` (standaard 5) aan in `/usr/local/bin/breachout-worker` |
| Firewallwijziging testen | `~/fwtest.sh` (test de eerdere proefmachines web01 en docker01, niet regel 22; die test je met Policy match) |

## Problemen oplossen

| Probleem | Oplossing |
| --- | --- |
| Terraform geeft 403 bij `keyctl` | Het API-token mag `keyctl` niet instellen. Daarom staat alleen `nesting` aan. Docker werkt ook zonder `keyctl`. |
| `terraform init` kent `hashicorp/proxmox` niet | In de module staat `versions.tf` met de provider-bron `bpg/proxmox`. |
| `breachout-worker list` doet niets | Er wordt op dat moment een worker aangemaakt. Het script houdt dan een slot vast. Wacht tot het klaar is. |
| Worker bleef staan | `breachout-worker destroy <sessie-id>`. De cron ruimt na 8 uur op, maar alleen als CT101 en het cluster aan stonden. |
| `curl` naar de registry vanaf CT101 geeft HTTP 000 | Dat is zo bedoeld, zie [netwerk-workers.md](../website/netwerk-workers.md). Test vanaf een worker. |
| Alle containers hangen en Proxmox toont vraagtekens na een herstart | Zie hieronder. |

### Ceph-OSD's starten na een herstart niet

Na een herstart van het cluster starten de OSD's niet altijd vanzelf (meerdere keren gezien, laatst op 26 oktober). Dan zijn de PG's niet actief en hangen alle containers op `ceph-vm`.

Waar: **de node zelf (pve001, pve002 en pve003 > Shell)**

```
ceph osd tree
systemctl start ceph-osd@0 ceph-osd@1
ceph -s
```

Op pve001 zijn dat osd.0 en osd.1, op pve002 osd.2 en osd.3 en op pve003 osd.4 en osd.5. Start ze één node tegelijk en controleer met `ceph osd tree` dat ze `up` zijn en met `ceph -s` dat de PG's weer actief worden. Staat een OSD nog op `out` (REWEIGHT 0), draai dan `ceph osd in <id>`. De oorzaak (waarom ze niet vanzelf starten) is nog niet uitgezocht.

## Let op

- Tokens, wachtwoorden en privésleutels staan niet in git: `/root/.pve_token`, `/root/.ssh/ansible_key` en `~/.vault_pass` (voor de versleutelde variabelen van de eerdere proefopstelling).
- De git-repository `~/ansible-ironhold` staat alleen op CT101 en is niet naar GitHub gepusht.
- Terraform gebruikt `insecure = true` voor het zelfondertekende certificaat van Proxmox.
- Containers 210 (docker01), 211 (web01) en 212 (web02) zijn een eerdere proefopstelling. Container 213 (docker02) is nu de registry.
- Een worker heeft geen HA en wordt niet hersteld. Valt hij uit, verwijder hem dan met `breachout-worker destroy` en start de sessie opnieuw.

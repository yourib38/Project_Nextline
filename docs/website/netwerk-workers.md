# Website – Netwerk en firewall voor de workers

[← Terug naar de website-map](README.md)

## Overzicht

| Onderdeel | Waarde |
| --- | --- |
| Waar draait het | FortiGate 70G (FG-NextLine), FortiOS 7.6.7 |
| Netwerk van de workers | Challenges-VLAN (VLAN 20), 192.168.20.0/24, workers op `192.168.20.100` t/m `.199` |
| Wel bereikbaar | Vanaf WEB-01: SSH, TCP 8081 (Traefik) en PING naar de workers. Vanaf CT101: SSH en PING naar het Challenges-VLAN. |
| Niet bereikbaar | Vanaf de workers: DB01 (192.168.10.24) en de rest van het Node-VLAN. Vanaf `web01` (testcontainer 211): de workers. |
| Regels | 22 `WEB01-naar-Workers` en 8 `Node-naar-Challenges` |

## Hoe het werkt

De workers staan in het Challenges-VLAN. De FortiGate laat alleen verkeer door dat in een regel staat. Al het andere valt onder Implicit Deny.

- **WEB-01 naar de workers.** Regel 22 laat WEB-01 (192.168.10.22) naar de workers `192.168.20.100-199`. De app gebruikt SSH om `docker run` uit te voeren en nginx gebruikt TCP 8081 om de challenge te laten zien.
- **CT101 naar de workers.** Regel 8 laat CT101 (192.168.10.21) met SSH naar het hele Challenges-VLAN. Zo kan Ansible de worker inrichten. Poort 5000 (de registry) is vanaf CT101 niet nodig en niet toegestaan. De workers halen de images zelf op, binnen hetzelfde VLAN.
- **Workers naar DB01.** Er is geen regel, dus de workers kunnen niet bij de database.

## Firewallregels

| ID | Naam | Van | Naar | Bron | Bestemming | Service | Actie | NAT |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 22 | WEB01-naar-Workers | Node-VLAN (Management vlan) | Challenges-VLAN | WEB-01 | workers | SSH, Traefik-8081, PING | ACCEPT | uit |
| 8 | Node-naar-Challenges | Node-VLAN (Management vlan) | Challenges-VLAN | ct101 | Challenges-VLAN address | SSH, PING | ACCEPT | uit |

Beide regels loggen alle sessies (Log Allowed Traffic: All Sessions).

## Adresobjecten

| Naam | Waarde |
| --- | --- |
| WEB-01 | 192.168.10.22/32 |
| workers | IP-bereik 192.168.20.100 t/m 192.168.20.199 |
| ct101 | 192.168.10.21/32 |
| Challenges-VLAN address | 192.168.20.0/24 |

`web01` (kleine letters) is het adres van testcontainer 211, niet van de website. Kies bij regel 22 altijd `WEB-01`.

De groep `Grp-Docker` (docker01 en docker02) bevat de workers niet. Zet ze daar ook niet in, want dan krijgen de workers de rechten van de docker-machines.

---

## Installatie (zo is het gedaan)

### Stap 1: adres `workers` aanmaken

Waar: **FortiGate > Policy & Objects > Addresses > Create new > Address**

Vul in: Name `workers`, Type **IP Range**, Start `192.168.20.100`, End `192.168.20.199`. Klik op OK.

### Stap 2: regel 22 aanmaken

Waar: **FortiGate > Policy & Objects > Firewall Policy > Create new**

1. Name `WEB01-naar-Workers`.
2. Incoming Interface **Node-VLAN (Management vlan)**, Outgoing Interface **Challenges-VLAN**.
3. Source `WEB-01`, Destination `workers`, Schedule `always`.
4. Service `SSH`, `Traefik-8081` (TCP 8081) en `PING`.
5. Action **ACCEPT**, NAT uit, Log Allowed Traffic **All Sessions**.
6. Klik op **OK** en controleer of de regel in de lijst staat. Bij de eerste poging stond hij er niet, omdat de regel niet was opgeslagen. Het verkeer viel dan onder Implicit Deny.

---

## Controleren

Waar: **FortiGate > Policy & Objects > Firewall Policy > Policy match**

Vul bij elke test de interface, het protocol, de bron, de bestemming en de poort in en klik op **Search**.

| Test | Interface | Bron | Bestemming | Verwacht | Gemeten |
| --- | --- | --- | --- | --- | --- |
| WEB-01 naar een worker | Node-VLAN | 192.168.10.22 | 192.168.20.100, TCP 8081 | Regel 22, Accept | Regel 22, Accept |
| `web01` naar een worker | Publiek-VLAN | 192.168.40.12 | 192.168.20.100, TCP 8081 | Implicit Deny | Implicit Deny |
| Worker naar DB01 | Challenges-VLAN | 192.168.20.100 | 192.168.10.24, TCP 5432 | Implicit Deny | Implicit Deny |

Kies je de verkeerde interface, dan meldt de tool "No route exists from source address". Dat zegt niets over de regel.

## Beheer

| Wat | Waar |
| --- | --- |
| Verkeer naar de workers bekijken | Log & Report > Forward Traffic, filter op bestemming `192.168.20.100-199` |
| Hit count van regel 22 | Policy & Objects > Firewall Policy, kolom Bytes of Hit count |
| Alle regels op volgorde bekijken | Firewall Policy, rechtsboven **Interface Pair View** wisselen naar **By Sequence** |

## Problemen oplossen

| Probleem | Oplossing |
| --- | --- |
| Challenge laadt niet (nginx 502) | Controleer of regel 22 hits heeft en of de service `Traefik-8081` erin staat. Test met Policy match. |
| De app kan geen docker-commando op de worker uitvoeren | Controleer of SSH in regel 22 staat en of de bron `WEB-01` is (niet `web01`). |
| Ansible kan de worker niet bereiken vanaf CT101 | Controleer regel 8 (bron `ct101`, SSH naar Challenges-VLAN). |
| `curl` naar de registry (poort 5000) vanaf CT101 geeft HTTP 000 | Dat is zo bedoeld. Test de registry vanaf een worker: `ssh root@192.168.20.1xx 'curl -s http://192.168.20.31:5000/v2/_catalog'`. |
| Een nieuwe regel werkt niet | Controleer of je op OK hebt geklikt en of de regel in de lijst staat. |

## Let op

- Alle workers staan in VLAN 20. De firewall scheidt de sessies dus niet van elkaar (FW-05 is nog niet ingesteld).
- De registry (`192.168.20.31:5000`) werkt zonder HTTPS binnen het VLAN. Daarom staat hij als insecure registry op de workers.
- WEB-01 staat in het Node-VLAN. Zie [netwerk.md](netwerk.md) voor dat restrisico.

# Website – BreachOut (challenges.ms-dev.nl)

[← Terug naar README](../../README.md)

Alles over de website van BreachOut staat in deze map: hoe hij draait, hoe hij beveiligd is en wie erbij kan.

## Overzicht

| Onderdeel | Waarde |
| --- | --- |
| Adres | https://challenges.ms-dev.nl |
| Webserver | Container 102 (WEB-01), nginx, 192.168.10.22 (Node-VLAN) |
| API | uvicorn in WEB-01 op `127.0.0.1:8000`, bereikbaar via `/api/` |
| Challenges | Container 103 (DOCKER01), `192.168.10.23:8081`, bereikbaar via `/c/` |
| Database | Container 104 (DB01), PostgreSQL op `192.168.10.24:5432` |
| Admin panel | https://challenges.ms-dev.nl/admin, alleen vanaf de WiFi NextLine en het Node-VLAN |
| Deelnemersnetwerk | WiFi `BreachOut-Nextline`, 192.168.70.0/24 |

## Hoe het werkt

Deelnemers verbinden met de WiFi `BreachOut-Nextline` en openen https://challenges.ms-dev.nl. Nginx in WEB-01 levert de website, stuurt `/api/` door naar de API en `/c/` naar de challenges op DOCKER01. De API slaat gebruikers, sessies en scores op in DB01.

```
Deelnemer (WiFi BreachOut-Nextline, 192.168.70.x)
        │  HTTP/HTTPS
        ▼
    FortiGate
        │
        ▼
WEB-01 (nginx, 192.168.10.22)
   ├── /        → website-bestanden (/var/www/challenges)
   ├── /admin   → alleen voor beheer-netwerken
   ├── /api/    → API (127.0.0.1:8000) ──► DB01 (192.168.10.24:5432)
   └── /c/      → DOCKER01 (192.168.10.23:8081)
```

## Inhoud van deze map

| Document | Beschrijving |
| --- | --- |
| [https.md](https.md) | HTTPS-certificaat van Let's Encrypt via Cloudflare |
| [netwerk.md](netwerk.md) | Deelnemersnetwerk BreachOut-Nextline en de firewallregels op de FortiGate |
| [admin-panel.md](admin-panel.md) | Het admin panel afschermen in nginx |
| [configs/nginx/challenges](configs/nginx/challenges) | Kopie van de nginx-config van WEB-01 |
| [configs/certbot/cloudflare.ini.example](configs/certbot/cloudflare.ini.example) | Voorbeeld van het Cloudflare-tokenbestand (zonder token) |

## Mappenstructuur

```
docs/website/
├── README.md          ← dit bestand
├── https.md
├── netwerk.md
├── admin-panel.md
└── configs/           ← kopieën van configuratiebestanden (zonder wachtwoorden)
    ├── nginx/
    │   └── challenges
    └── certbot/
        └── cloudflare.ini.example
```

Nieuwe documentatie over de website? Zet die in deze map, gebruik [_sjabloon.md](../_sjabloon.md) en voeg een regel toe aan de tabel hierboven.

## Let op

- WEB-01, DOCKER01 en DB01 staan in hetzelfde netwerk als de Proxmox-nodes (Node-VLAN). Volgens het TO hoort de webserver in het Publiek-VLAN (40). Dat is een bekend restrisico, zie [netwerk.md](netwerk.md).
- Zet nooit wachtwoorden of tokens in deze map.

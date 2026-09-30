# Project Nextline

Documentatie van ons schoolproject Nextline. Alles wat we bouwen en instellen, leggen we hier vast zodat iedereen in de groep er altijd bij kan.

## Inhoud

| Onderdeel | Beschrijving | Status |
| --- | --- | --- |
| [Cluster1 – overzicht](docs/cluster1/overzicht.md) | Nodes, IP-adressen, hardware en netwerk | Klaar |
| [Cluster1 – Ceph-storage](docs/cluster1/ceph.md) | Gedeelde opslag voor VM's, containers en ISO's | Klaar |
| [Cluster1 – Monitoring](docs/cluster1/monitoring.md) | Prometheus + Grafana in `Ubuntu-server` | Klaar |
| Cluster1 – High Availability (HA) | HA-groepen, load balancing en live migration | Klaar |

## Mappenstructuur

```
Project_Nextline/
├── README.md              ← dit bestand, de inhoudsopgave
├── docs/
│   ├── _sjabloon.md       ← sjabloon voor nieuwe documentatie
│   └── cluster1/          ← alles over het Proxmox-cluster
│       ├── overzicht.md
│       ├── ceph.md
│       ├── monitoring.md
│       └── afbeeldingen/
└── configs/               ← kopieën van configuratiebestanden (zonder wachtwoorden)
    ├── prometheus/
    └── systemd/
```

## Nieuwe documentatie toevoegen

1. Kopieer [docs/_sjabloon.md](docs/_sjabloon.md) naar de juiste map in `docs/`. Hoort het niet bij een bestaand onderdeel, maak dan een nieuwe map aan.
2. Zet screenshots in de map `afbeeldingen/` naast het document.
3. Zet configuratiebestanden in `configs/<programma>/`. Vervang wachtwoorden en tokens door een placeholder en geef het bestand de extensie `.example`.
4. Voeg een regel toe aan de tabel **Inhoud** hierboven.

## Afspraken

- **Zet nooit wachtwoorden of tokens in deze repository.** Gebruik voorbeeldbestanden met een placeholder, zoals `pve.yml.example`.
- Zet geen screenshots online waarop een wachtwoord of token staat.
- Verander je iets aan het cluster? Pas dan ook de documentatie aan.
- Houd deze repository **Private**. Er staan IP-adressen en de netwerkopbouw in.

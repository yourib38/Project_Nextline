# Cluster1 – overzicht

[← Terug naar README](../../README.md)

Ons Proxmox VE-cluster met drie nodes, Ceph-storage en monitoring (Prometheus + Grafana). Op het cluster draaien vooral LXC-containers.

## Documentatie van dit cluster

| Onderdeel | Bestand |
| --- | --- |
| Ceph-storage | [ceph.md](ceph.md) |
| Monitoring (Prometheus + Grafana) | [monitoring.md](monitoring.md) |
| Configuratiebestanden monitoring | [configs/](../../configs/) |

## Cluster in het kort

| Onderdeel | Gegevens |
| --- | --- |
| Clusternaam | Cluster1 |
| Proxmox VE | 9.2, No-Subscription-repository |
| pve001 | 192.168.10.11/24 |
| pve002 | 192.168.10.12/24 |
| pve003 | 192.168.10.13/24 |
| Webinterface | `https://192.168.10.11:8006` (werkt ook via .12 en .13) |
| Gedeelde storage | `ceph-vm` (schijven van VM's en containers), `isoimages` (ISO's en templates) |
| Monitoring | Grafana op `http://<IP-Ubuntu-server>:3000` |

## Hardware per node

Alle drie de nodes hebben dezelfde hardware.

| Onderdeel | Gegevens |
| --- | --- |
| Bootschijf | 1× SK hynix 256 GB (Proxmox) |
| Ceph-schijven | 2× Samsung SSD 990 PRO 2 TB |
| nic0 | 1 Gbit/s, in gebruik via `vmbr0` |
| nic1 | 10 Gbit/s, nog niet in gebruik |

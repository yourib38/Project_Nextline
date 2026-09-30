# Ceph-storage

[← Terug naar README](../../README.md) · [Cluster1 – overzicht](overzicht.md)

## Overzicht

| Onderdeel | Waarde |
| --- | --- |
| Ceph-versie | 20.2.4 (Tentacle) |
| Repository | No-Subscription |
| Ceph-netwerk | 192.168.10.0/24 via nic0 (1 Gbit/s) |
| Monitors | pve001, pve002, pve003 |
| Managers | pve001, pve002, pve003 (1 actief, 2 stand-by) |
| Metadata servers (CephFS) | pve001, pve002, pve003 |
| OSD's | 6 (2 per node) |

## Schijven per node

| Node | Bootschijf (Proxmox) | Ceph-schijven (OSD's) |
| --- | --- | --- |
| pve001 | nvme2n1 | nvme0n1, nvme1n1 |
| pve002 | nvme0n1 | nvme1n1, nvme2n1 |
| pve003 | nvme1n1 | nvme0n1, nvme2n1 |

> **Let op:** de apparaatnamen verschillen per node. Kies schijven altijd op basis van de kolom **Model** (Samsung SSD 990 PRO 2TB), nooit op naam.

## Storage en pools

| Storage in Proxmox | Type | Ceph-pool(s) | Inhoud | Size / Min. Size |
| --- | --- | --- | --- | --- |
| `ceph-vm` | RBD | `ceph-vm` | Disk image, Container | 3 / 2 |
| `isoimages` | CephFS | `cephfs_data`, `cephfs_metadata` | ISO image, Container template | 3 / 2 |

## Capaciteit

| | Waarde |
| --- | --- |
| Ruwe opslag | 6 × 2 TB = 12 TB (±10,9 TiB) |
| Bruikbaar met 3 kopieën | ±3,6 TiB |
| Maximaal gebruik | 80% |
| Veilig bij uitval van 1 schijf | onder ±40% |

---

## Installatie (zo is het gedaan)

### Stap 1: schijven leegmaken

Waar: **node > Shell**, per node

1. Bekijk de volumegroepen:

```
vgs
```

2. Verwijder elke groep die begint met `ceph-` of `pve-OLD-`. Verwijder **nooit** de groep `pve`.

```
vgremove -f <naam-van-de-volumegroep>
```

3. Ga naar **node > Disks**, selecteer beide Samsung-schijven een voor een en klik op **Wipe Disk**.
4. Klik op **Reload**. Bij Usage hoort **No** te staan.

### Stap 2: Ceph installeren op pve001

Waar: **pve001 > Ceph**

1. Klik op **Install Ceph**.
2. Kies de nieuwste versie en de repository **No-Subscription**. Klik op **Start installation**.
3. Typ `Y` en druk op Enter. Klik op **Next** als de installatie klaar is.
4. Vul in:
   - Public Network: `192.168.10.11/24`
   - Cluster Network: leeg laten
   - Monitor node: `pve001`
   - Number of replicas: `3`
   - Minimum replicas: `2`
5. Klik op **Next** en daarna op **Finish**.

### Stap 3: Ceph installeren op pve002 en pve003

Waar: **pve002 > Ceph** en **pve003 > Ceph**

1. Klik op **Install Ceph**.
2. Kies dezelfde versie en **No-Subscription**. Klik op **Start installation**.
3. Typ `Y` en druk op Enter.
4. Klik op **Next** en daarna op **Finish**.

### Stap 4: monitors en managers toevoegen

Waar: **pve001 > Ceph > Monitor**

1. Monitor: klik op **Create** en kies `pve002`. Herhaal dit voor `pve003`.
2. Manager: klik op **Create** en kies `pve002`. Herhaal dit voor `pve003`.

### Stap 5: OSD's aanmaken

Waar: **node > Ceph > OSD**, per node

1. Klik op **Create: OSD**.
2. Kies bij Disk de eerste Samsung-schijf en klik op **Create**.
3. Herhaal dit voor de tweede Samsung-schijf.

### Stap 6: pool `ceph-vm` aanmaken

Waar: **pve001 > Ceph > Pools**

1. Klik op **Create**.
2. Vul in:
   - Name: `ceph-vm`
   - Size: `3`
   - Min. Size: `2`
   - Crush Rule: `replicated_rule`
   - PG Autoscale Mode: `on`
   - Add as Storage: aangevinkt
3. Klik op **Create**.

### Stap 7: CephFS `isoimages` aanmaken

Waar: **pve001 > Ceph > CephFS**

1. Metadata Servers: klik op **Create** en kies `pve001`. Herhaal dit voor `pve002` en `pve003`.
2. CephFS: klik op **Create CephFS**. Laat de Name op `cephfs` staan en vink **Add as Storage** uit. Klik op **Create**.
3. Ga naar **Datacenter > Storage > Add > CephFS**.
4. Vul in:
   - ID: `isoimages`
   - FS Name: `cephfs`
   - Nodes: All
   - Content: ISO image, Container template
5. Klik op **Add**.

---

## Controleren

Waar: **Datacenter > Ceph**. Hier hoort **HEALTH_OK** te staan, met 6 OSD's **Up** en **In**.

Of in de Shell van een willekeurige node:

```
ceph -s
ceph osd tree
ceph df
ceph health detail
```

## Problemen oplossen

| Probleem | Oplossing |
| --- | --- |
| Wipe Disk geeft `has a holder` | Verwijder eerst de oude volumegroep (stap 1). |
| Geen schijven zichtbaar bij Create: OSD | De schijf is niet leeg. Voer stap 1 uit. |
| `OSD count 2 < osd_pool_default_size 3` | Er zijn nog niet op alle 3 de nodes OSD's. Maak ze aan (stap 5). |
| `clock skew detected` | Controleer de tijd met `chronyc tracking`. |
| FS Name is leeg bij Add CephFS | Er bestaat nog geen CephFS. Voer stap 7.1 en 7.2 uit. |

## Let op

- Zet **Min. Size nooit op 1**. Dan kun je data kwijtraken.
- Onderhoud en tests: **altijd één node tegelijk**.
- Houd het gebruik van `ceph-vm` onder 80%.
- Clusterverkeer, Ceph en VM's lopen allemaal over nic0 (1 Gbit/s). Bij veel Ceph-verkeer kan een node onterecht herstart worden. nic1 (10 Gbit/s) is nog niet in gebruik.

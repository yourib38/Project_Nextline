# Website – Deelnemersnetwerk en firewall

[← Terug naar de website-map](README.md)

## Overzicht

| Onderdeel | Waarde |
| --- | --- |
| Waar draait het | FortiGate 70G (FG-NextLine), FortiOS 7.6.7, WiFi via FortiAP FAP-NextLine |
| WiFi (SSID) | `BreachOut-Nextline`, WPA2 Personal |
| Interface | `Deelnemers` (WiFi SSID, tunnelmodus) |
| Netwerk | 192.168.70.0/24, gateway en DNS 192.168.70.1, DHCP 192.168.70.2 t/m .254 |
| Wel bereikbaar | De website (WEB-01, poort 80 en 443) en internet (HTTP en HTTPS) |
| Niet bereikbaar | Proxmox, Grafana, DB01, DOCKER01, de FortiGate, de andere VLAN's, het schoolnetwerk en elkaar |
| FO/TO | FR8, NFR3, NFR6; TO Tabel 11 en Tabel 13 (FW-01, FW-06) |

## Hoe het werkt

Deelnemers verbinden met de WiFi `BreachOut-Nextline`. Dat is een apart netwerk op de FortiGate: de interface `Deelnemers`. De FortiGate laat vanaf dit netwerk alleen verkeer door dat in een firewallregel staat. Al het andere valt onder **Implicit Deny** en wordt geweigerd.

- **Website.** De regel `Deelnemers-naar-Website` laat alleen HTTP en HTTPS naar WEB-01 (192.168.10.22) door. Proxmox, Grafana en de rest van het Node-VLAN zijn dus niet bereikbaar, ook al staat WEB-01 in hetzelfde VLAN.
- **DNS.** De FortiGate beantwoordt de DNS-vragen zelf (DNS-service op de interface `Deelnemers`) en stuurt ze door naar FortiGuard. `challenges.ms-dev.nl` wijst in Cloudflare naar 192.168.10.22.
- **Internet.** De regel `Deelnemers-naar-internet` laat HTTP en HTTPS naar wan1 door. wan1 zit aan het schoolnetwerk. Daarom staat er eerst `Deelnemers-blokkeer-prive`: die blokkeert alle privé-adressen (10.0.0.0/8, 172.16.0.0/12 en 192.168.0.0/16) richting wan1. Deelnemers kunnen zo wel op internet, maar niet bij apparaten in het schoolnetwerk.
- **Onderling.** Door **Block intra-SSID traffic** kunnen apparaten op BreachOut-Nextline elkaar niet bereiken.
- **Admin panel.** De firewall ziet niet welke pagina iemand opvraagt. `/admin` wordt daarom in nginx afgeschermd, zie [admin-panel.md](admin-panel.md).

### Firewallregels

| Naam | Van | Naar | Bron | Bestemming | Service | Actie | NAT |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Deelnemers-naar-Website | Deelnemers | Node-VLAN | all | WEB-01 | HTTP, HTTPS | ACCEPT | uit |
| Deelnemers-blokkeer-prive | Deelnemers | wan1 | all | Prive-netwerken | ALL | DENY | – |
| Deelnemers-naar-internet | Deelnemers | wan1 | all | all | HTTP, HTTPS | ACCEPT | aan |
| Implicit Deny | alle | alle | all | all | ALL | DENY | – |

`Deelnemers-blokkeer-prive` moet boven `Deelnemers-naar-internet` staan. De FortiGate leest de regels van boven naar beneden.

### Adresobjecten

| Naam | Waarde |
| --- | --- |
| WEB-01 | 192.168.10.22/32 |
| Prive-10 | 10.0.0.0/8 |
| Prive-172 | 172.16.0.0/12 |
| Prive-192 | 192.168.0.0/16 |
| Prive-netwerken | Adresgroep met Prive-10, Prive-172 en Prive-192 |

`web01` (kleine letters) is het adres van testcontainer 211, niet van de website.

---

## Installatie (zo is het gedaan)

### Stap 1: WiFi aanmaken

Waar: **FortiGate > WiFi & Switch Controller > SSIDs > Create New > SSID**

1. Vul in: Interface name `Deelnemers`, Alias `BreachOut-Nextline`, Traffic mode `Tunnel`, IP/Netmask `192.168.70.1/255.255.255.0`.
2. Zet bij **Administrative Access** alleen **PING** aan.
3. Zet **DHCP Server** aan en kies bij **DNS server** `Same as Interface IP`.
4. Vul bij **SSID** `BreachOut-Nextline` in, kies Security mode `WPA2 Personal` en vul een passphrase in.
5. Zet **Block intra-SSID traffic** en **Broadcast SSID** aan en klik op **OK**.

### Stap 2: DNS op de interface aanzetten

Waar: **FortiGate > CLI (het >_-icoon rechtsboven)**

```
config system dns-server
    edit "Deelnemers"
        set mode forward-only
    next
end
```

Controleer met `show system dns-server`.

### Stap 3: adressen aanmaken

Waar: **FortiGate > Policy & Objects > Addresses > Create new**

1. Maak de adressen uit de tabel **Adresobjecten** aan (Type `Subnet`).
2. Maak de adresgroep `Prive-netwerken` aan met Prive-10, Prive-172 en Prive-192.

### Stap 4: firewallregels aanmaken

Waar: **FortiGate > Policy & Objects > Firewall Policy > Create new**

1. Maak de regels uit de tabel **Firewallregels** aan, in die volgorde.
2. Zet bij de ACCEPT-regels **Log Allowed Traffic** op `All Sessions` en bij de DENY-regel **Log Violation Traffic** aan.
3. Klap **Implicit** uit, dubbelklik op **Implicit Deny** en zet **Log Violation Traffic** aan.

---

## Controleren

Verbind een laptop met **BreachOut-Nextline** en voer uit:

```
ipconfig
nslookup challenges.ms-dev.nl
```

| Test | Verwacht resultaat |
| --- | --- |
| IP-adres van de laptop | 192.168.70.x |
| `nslookup challenges.ms-dev.nl` | Server 192.168.70.1, adres 192.168.10.22 |
| https://challenges.ms-dev.nl | Website en challenges werken |
| https://www.google.com | Werkt |
| https://192.168.10.11:8006 (Proxmox) | Laadt niet |
| http://192.168.50.10:3000 (Grafana) | Laadt niet |
| https://challenges.ms-dev.nl/admin | `403 Forbidden` |

Bewijs: ga op de FortiGate naar **Log & Report > Forward Traffic** en filter op source interface `Deelnemers`. Daar zie je de toegestane en de geweigerde verbindingen (T-05 en T-08).

## Beheer

| Wat | Waar |
| --- | --- |
| Verbonden apparaten bekijken | WiFi & Switch Controller > WiFi Clients |
| Verkeer en blokkades bekijken | Log & Report > Forward Traffic, filter op `Deelnemers` |
| WiFi-wachtwoord wijzigen | WiFi & Switch Controller > SSIDs > BreachOut-Nextline > Passphrase |
| Internet voor deelnemers uitzetten | Policy & Objects > Firewall Policy > `Deelnemers-naar-internet` > Disable |

## Problemen oplossen

| Probleem | Oplossing |
| --- | --- |
| Laptop kan niet verbinden ("Unable to connect to this network") | Verwijder het opgeslagen netwerk met `netsh wlan delete profile name="BreachOut-Nextline"` en verbind opnieuw. |
| Verbonden, maar de website laadt niet | Controleer of `Deelnemers-naar-Website` als bestemming `WEB-01` heeft (niet `web01`) en of de Hit count oploopt. |
| `nslookup` geeft geen antwoord | Controleer met `show system dns-server` in de CLI of de DNS-service op `Deelnemers` staat. |
| Deelnemers kunnen bij het schoolnetwerk | Controleer of `Deelnemers-blokkeer-prive` boven `Deelnemers-naar-internet` staat. |

## Let op

- Het WiFi-wachtwoord staat niet in deze repository. Vraag het aan de groep.
- WEB-01 staat in het Node-VLAN, samen met de Proxmox-nodes. Deelnemers kunnen alleen poort 80 en 443 van WEB-01 bereiken, maar wie inbreekt op WEB-01 zit wel in het servernetwerk. Dit is een restrisico. De vervolgstap is WEB-01 naar het Publiek-VLAN (40) verhuizen, zoals in het TO staat.
- De admin-accounts van de FortiGate hebben nog geen trusted hosts. Stel die nog in (192.168.60.0/24 en 192.168.10.0/24), anders kunnen deelnemers mogelijk de inlogpagina van de FortiGate openen.
- Met internet kunnen deelnemers tijdens een sessie antwoorden opzoeken.

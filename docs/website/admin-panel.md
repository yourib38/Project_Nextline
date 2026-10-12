# Website – Admin panel afschermen

[← Terug naar de website-map](README.md)

## Overzicht

| Onderdeel | Waarde |
| --- | --- |
| Waar draait het | Container 102 (WEB-01), nginx |
| Config | `/etc/nginx/sites-available/challenges`, kopie in [configs/nginx/challenges](configs/nginx/challenges) |
| Adres | https://challenges.ms-dev.nl/admin |
| Toegestaan | 192.168.10.0/24 (Node-VLAN) en 192.168.60.0/24 (WiFi NextLine) |
| Geweigerd | Alle andere adressen, ook BreachOut-Nextline (192.168.70.0/24): `403 Forbidden` |
| FO/TO | NFR3 (toegang volgens rol), FR8 |

## Hoe het werkt

Het admin panel draait op hetzelfde adres en dezelfde poort als de rest van de website. Omdat het verkeer versleuteld is, ziet de FortiGate niet welke pagina iemand opvraagt. Nginx doet de controle daarom zelf: bij alles wat met `/admin` begint, kijkt nginx naar het IP-adres van de bezoeker.

Laptops op de WiFi NextLine komen bij WEB-01 binnen als `192.168.10.1`, omdat de regel NextLine → Node-VLAN op de FortiGate NAT gebruikt. Daarom staat `192.168.10.0/24` in de lijst. `192.168.60.0/24` staat er ook in, zodat het blijft werken als die NAT later uitgaat.

Deelnemers komen binnen met hun eigen adres (192.168.70.x), want de regel `Deelnemers-naar-Website` gebruikt geen NAT. Zij krijgen `403 Forbidden`.

Het blok in de nginx-config:

```nginx
location ^~ /admin {
    allow 192.168.10.0/24;
    allow 192.168.60.0/24;
    deny all;

    try_files $uri $uri/ =404;
}
```

Door `^~` krijgt geen andere regel in de config voorrang op dit blok.

---

## Installatie (zo is het gedaan)

### Stap 1: back-up maken

Waar: **102 (WEB-01) > Console**

```
cp /etc/nginx/sites-available/challenges /root/challenges-voor-admin.bak
```

### Stap 2: admin-blok toevoegen

Waar: **102 (WEB-01) > Console**

1. Zet het blok in een apart bestand. Kopieer alles in één keer, inclusief de laatste regel `EOF`:

```
cat > /root/admin-blok.conf << 'EOF'
    location ^~ /admin {
        allow 192.168.10.0/24;
        allow 192.168.60.0/24;
        deny all;

        try_files $uri $uri/ =404;
    }

EOF
```

2. Zet het blok vóór `location /api/ {`:

```
sed -i '/location \/api\/ {/e cat /root/admin-blok.conf' /etc/nginx/sites-available/challenges
```

3. Controleer de volgorde. Je moet precies vier regels zien: `location /`, `location ^~ /admin`, `location /api/` en `location /c/`.

```
grep -n "location" /etc/nginx/sites-available/challenges
```

4. Test de config en herlaad nginx. Je moet `syntax is ok` en `test is successful` zien.

```
nginx -t && systemctl reload nginx
```

5. Maak een back-up van de werkende versie:

```
cp /etc/nginx/sites-available/challenges /root/challenges-werkend.bak
```

---

## Controleren

| Test | Verwacht resultaat |
| --- | --- |
| https://challenges.ms-dev.nl/admin vanaf BreachOut-Nextline | `403 Forbidden` |
| https://challenges.ms-dev.nl vanaf BreachOut-Nextline | Website en challenges werken |
| https://challenges.ms-dev.nl/admin vanaf de WiFi NextLine | Admin panel opent |

Zo zie je welke bezoekers zijn geweigerd:

```
grep '/admin' /var/log/nginx/access.log | grep ' 403 ' | tail
```

## Beheer

| Wat | Commando of actie |
| --- | --- |
| Config testen | `nginx -t` |
| Config herladen | `systemctl reload nginx` |
| Laatste bezoeken van /admin bekijken | `grep '/admin' /var/log/nginx/access.log \| tail` |
| Netwerk toegang geven | Extra regel `allow <netwerk>;` boven `deny all;`, daarna testen en herladen |

## Problemen oplossen

| Probleem | Oplossing |
| --- | --- |
| `nginx -t` geeft `location "/c/" is outside location "/api/"` | Het bestand is beschadigd, bijvoorbeeld door plakken in nano via de Proxmox-console. Zet de werkende versie terug: `cp /root/challenges-werkend.bak /etc/nginx/sites-available/challenges` |
| Ook beheerders krijgen `403 Forbidden` | Kijk in `/var/log/nginx/access.log` met welk IP-adres je binnenkomt en voeg dat netwerk toe aan de allow-lijst. |
| Deelnemers kunnen `/admin` wel openen | Controleer of NAT uit staat in de regel `Deelnemers-naar-Website`. Met NAT aan komen deelnemers binnen als `192.168.10.1` en vallen ze onder `allow 192.168.10.0/24`. |

## Let op

- Dit blokkeert alleen de pagina `/admin`. Gebruikt het admin panel API-adressen onder `/api/`, dan zijn die nog niet afgeschermd. Dat moet nog worden nagekeken.
- Zorg dat het admin panel een eigen login met een sterk wachtwoord heeft. De IP-blokkade is een extra laag, geen vervanging.
- Plak geen blokken in nano via de Proxmox-console: daarbij raakten regels door elkaar. Gebruik de commando's hierboven.
- Pas bij elke wijziging ook [configs/nginx/challenges](configs/nginx/challenges) aan.

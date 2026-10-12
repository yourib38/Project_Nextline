# Website – HTTPS-certificaat

[← Terug naar de website-map](README.md)

## Overzicht

| Onderdeel | Waarde |
| --- | --- |
| Waar draait het | Container 102 (WEB-01) op pve003 |
| Versie | Ubuntu 25.04, nginx 1.26.3, certbot met Cloudflare-plugin |
| IP-adres / poort | 192.168.10.22, poort 80 (doorsturen) en 443 (HTTPS) |
| Domein | https://challenges.ms-dev.nl |
| DNS | Cloudflare, record `challenges` op DNS only (grijze wolk) |
| Certificaat | Let's Encrypt, 90 dagen geldig, wordt automatisch verlengd |

## Hoe het werkt

De website draait op nginx in WEB-01. Het certificaat komt van Let's Encrypt. Certbot bewijst dat wij eigenaar zijn van het domein via een DNS-controle: met een Cloudflare API-token zet certbot tijdelijk een TXT-record in Cloudflare, en Let's Encrypt controleert dat record. Daardoor hoeft de server niet vanaf internet bereikbaar te zijn.

Het certificaat wordt automatisch verlengd door `certbot.timer`. Na het verlengen herlaadt nginx vanzelf.

Wie de website via het IP-adres opent, wordt doorgestuurd naar het domein. Voor die doorverwijzing gebruikt nginx een certificaat van onze eigen interne CA (zie [Interne CA](#interne-ca-voor-toegang-via-ip-adres)).

Nginx stuurt het verkeer zo door:

| Pad | Gaat naar |
| --- | --- |
| `/` | Website-bestanden in `/var/www/challenges` |
| `/api/` | API (uvicorn) op `127.0.0.1:8000` |
| `/c/` | Challenges op `192.168.10.23:8081` |

De volledige nginx-config staat in [configs/nginx/challenges](configs/nginx/challenges).

---

## Installatie (zo is het gedaan)

### Stap 1: Cloudflare API-token aanmaken

Waar: **Cloudflare-dashboard**

1. Klik rechtsboven op je profiel > **My Profile** > **API Tokens** > **Create Token**.
2. Klik bij **Edit zone DNS** op **Use template**.
3. Kies bij **Zone Resources**: **Include** > **Specific zone** > **ms-dev.nl**.
4. Klik op **Continue to summary** > **Create Token**.
5. Kopieer het token. Je ziet het maar één keer.

### Stap 2: certbot installeren

Waar: **102 (WEB-01) > Console**

```
apt update
apt install -y certbot python3-certbot-dns-cloudflare
```

### Stap 3: token opslaan

Waar: **102 (WEB-01) > Console**

1. Open het tokenbestand:

```
mkdir -p /root/.secrets
nano /root/.secrets/cloudflare.ini
```

2. Zet het token erin, zoals in [configs/certbot/cloudflare.ini.example](configs/certbot/cloudflare.ini.example):

```
dns_cloudflare_api_token = PLAK-HIER-JE-TOKEN
```

3. Sla op met **Ctrl+O**, druk op **Enter** en sluit af met **Ctrl+X**.
4. Stel de rechten in:

```
chmod 600 /root/.secrets/cloudflare.ini
```

### Stap 4: certificaat aanvragen

Waar: **102 (WEB-01) > Console**

1. Voer dit uit. Vul een e-mailadres in en typ **Y** bij de voorwaarden:

```
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.secrets/cloudflare.ini --dns-cloudflare-propagation-seconds 60 -d challenges.ms-dev.nl --deploy-hook "systemctl reload nginx"
```

2. Je moet `Successfully received certificate` zien. Het certificaat staat in `/etc/letsencrypt/live/challenges.ms-dev.nl/`.

### Stap 5: nginx instellen

Waar: **102 (WEB-01) > Console**

1. Maak een back-up van de oude config:

```
cp /etc/nginx/sites-available/challenges /root/challenges-ip.bak
```

2. Zet de inhoud van [configs/nginx/challenges](configs/nginx/challenges) in `/etc/nginx/sites-available/challenges`.
3. Test de config en herlaad nginx:

```
nginx -t && systemctl reload nginx
```

### Stap 6: automatisch verlengen testen

Waar: **102 (WEB-01) > Console**

```
certbot renew --dry-run
systemctl list-timers | grep certbot
```

Je moet `Congratulations, all simulated renewals succeeded` zien, en een regel met `certbot.timer`.

---

## Interne CA (voor toegang via IP-adres)

Voordat we het domein hadden, hebben we een eigen CA gemaakt. Nginx gebruikt dit certificaat nu alleen nog om bezoekers van `https://192.168.10.22` door te sturen naar het domein.

| Bestand | Plek |
| --- | --- |
| CA-sleutel en -certificaat | `/root/my-ca/ca.key`, `/root/my-ca/ca.crt` |
| Servercertificaat WEB-01 | `/etc/ssl/web01/web01.crt`, `/etc/ssl/web01/web01.key` |

Zo is het gemaakt (in `/root/my-ca`):

```
openssl genrsa -aes256 -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/C=NL/O=MijnNetwerk/OU=IT/CN=Mijn Interne Root CA"
openssl genrsa -out web01.key 2048
openssl req -new -key web01.key -out web01.csr -config web01.cnf
openssl x509 -req -in web01.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out web01.crt -days 825 -sha256 -extfile web01.cnf -extensions req_ext
mkdir -p /etc/ssl/web01
chmod 700 /etc/ssl/web01
cp web01.crt web01.key /etc/ssl/web01/
chmod 600 /etc/ssl/web01/web01.key
```

`web01.cnf` bevat het IP-adres `192.168.10.22` als Subject Alternative Name.

Wil je `https://192.168.10.22` zonder waarschuwing openen? Importeer dan `ca.crt` op je pc in **Trusted Root Certification Authorities**. Het bestand staat op `https://challenges.ms-dev.nl/ca.crt`.

---

## Controleren

1. Open `https://challenges.ms-dev.nl`. Er staat geen "Not secure" in de adresbalk.
2. Bekijk de certificaten en de vervaldatum:

```
certbot certificates
```

3. Controleer of nginx op poort 80 en 443 luistert:

```
ss -tlnp | grep nginx
```

## Beheer

| Wat | Commando |
| --- | --- |
| Certificaten en vervaldatum bekijken | `certbot certificates` |
| Verlengen testen | `certbot renew --dry-run` |
| Timer voor verlengen bekijken | `systemctl list-timers \| grep certbot` |
| Nginx-config testen en herladen | `nginx -t && systemctl reload nginx` |
| Logboek nginx | `journalctl -u nginx -n 50 --no-pager` |
| Logboek certbot | `tail -n 50 /var/log/letsencrypt/letsencrypt.log` |

## Problemen oplossen

| Probleem | Oplossing |
| --- | --- |
| "Not secure" via `https://192.168.10.22` | `ca.crt` is niet geïmporteerd op die pc. Gebruik het domein, of importeer `ca.crt`. |
| certbot meldt een fout bij Cloudflare | Het token is ingetrokken of verkeerd. Maak een nieuw token (stap 1) en zet het in `/root/.secrets/cloudflare.ini`. |
| Website laadt niet meer na een wijziging | Voer `nginx -t` uit en los de fout op, of zet de back-up `/root/challenges-ip.bak` terug. |
| Domein werkt niet, IP-adres wel | Controleer in Cloudflare of het record `challenges` bestaat en op DNS only staat. |
| `apt update` geeft 404-fouten | Ubuntu 25.04 krijgt geen updates meer. Stap over naar een LTS-versie. |

## Let op

- Het Cloudflare-token staat alleen in `/root/.secrets/cloudflare.ini` op WEB-01. Zet het nooit in deze repository.
- Deel `ca.key` en `web01.key` nooit. Alleen `ca.crt` mag naar andere pc's.
- Laat het record `challenges` in Cloudflare op **DNS only** (grijze wolk) staan.
# Website – HTTPS-certificaat

[← Terug naar README](../../README.md)

## Overzicht

| Onderdeel | Waarde |
| --- | --- |
| Waar draait het | Container 102 (WEB-01) op pve003 |
| Versie | Ubuntu 25.04, nginx 1.26.3, certbot met Cloudflare-plugin |
| IP-adres / poort | 192.168.10.22, poort 80 (doorsturen) en 443 (HTTPS) |
| Domein | https://challenges.ms-dev.nl |
| DNS | Cloudflare, record `challenges` op DNS only (grijze wolk) |
| Certificaat | Let's Encrypt, 90 dagen geldig, wordt automatisch verlengd |

## Hoe het werkt

De website draait op nginx in WEB-01. Het certificaat komt van Let's Encrypt. Certbot bewijst dat wij eigenaar zijn van het domein via een DNS-controle: met een Cloudflare API-token zet certbot tijdelijk een TXT-record in Cloudflare, en Let's Encrypt controleert dat record. Daardoor hoeft de server niet vanaf internet bereikbaar te zijn.

Het certificaat wordt automatisch verlengd door `certbot.timer`. Na het verlengen herlaadt nginx vanzelf.

Wie de website via het IP-adres opent, wordt doorgestuurd naar het domein. Voor die doorverwijzing gebruikt nginx een certificaat van onze eigen interne CA (zie [Interne CA](#interne-ca-voor-toegang-via-ip-adres)).

Nginx stuurt het verkeer zo door:

| Pad | Gaat naar |
| --- | --- |
| `/` | Website-bestanden in `/var/www/challenges` |
| `/api/` | API (uvicorn) op `127.0.0.1:8000` |
| `/c/` | Challenges op `192.168.10.23:8081` |

De volledige nginx-config staat in [configs/nginx/challenges](../../configs/nginx/challenges).

---

## Installatie (zo is het gedaan)

### Stap 1: Cloudflare API-token aanmaken

Waar: **Cloudflare-dashboard**

1. Klik rechtsboven op je profiel > **My Profile** > **API Tokens** > **Create Token**.
2. Klik bij **Edit zone DNS** op **Use template**.
3. Kies bij **Zone Resources**: **Include** > **Specific zone** > **ms-dev.nl**.
4. Klik op **Continue to summary** > **Create Token**.
5. Kopieer het token. Je ziet het maar één keer.

### Stap 2: certbot installeren

Waar: **102 (WEB-01) > Console**

```
apt update
apt install -y certbot python3-certbot-dns-cloudflare
```

### Stap 3: token opslaan

Waar: **102 (WEB-01) > Console**

1. Open het tokenbestand:

```
mkdir -p /root/.secrets
nano /root/.secrets/cloudflare.ini
```

2. Zet het token erin, zoals in [configs/certbot/cloudflare.ini.example](../../configs/certbot/cloudflare.ini.example):

```
dns_cloudflare_api_token = PLAK-HIER-JE-TOKEN
```

3. Sla op met **Ctrl+O**, druk op **Enter** en sluit af met **Ctrl+X**.
4. Stel de rechten in:

```
chmod 600 /root/.secrets/cloudflare.ini
```

### Stap 4: certificaat aanvragen

Waar: **102 (WEB-01) > Console**

1. Voer dit uit. Vul een e-mailadres in en typ **Y** bij de voorwaarden:

```
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.secrets/cloudflare.ini --dns-cloudflare-propagation-seconds 60 -d challenges.ms-dev.nl --deploy-hook "systemctl reload nginx"
```

2. Je moet `Successfully received certificate` zien. Het certificaat staat in `/etc/letsencrypt/live/challenges.ms-dev.nl/`.

### Stap 5: nginx instellen

Waar: **102 (WEB-01) > Console**

1. Maak een back-up van de oude config:

```
cp /etc/nginx/sites-available/challenges /root/challenges-ip.bak
```

2. Zet de inhoud van [configs/nginx/challenges](../../configs/nginx/challenges) in `/etc/nginx/sites-available/challenges`.
3. Test de config en herlaad nginx:

```
nginx -t && systemctl reload nginx
```

### Stap 6: automatisch verlengen testen

Waar: **102 (WEB-01) > Console**

```
certbot renew --dry-run
systemctl list-timers | grep certbot
```

Je moet `Congratulations, all simulated renewals succeeded` zien, en een regel met `certbot.timer`.

---

## Interne CA (voor toegang via IP-adres)

Voordat we het domein hadden, hebben we een eigen CA gemaakt. Nginx gebruikt dit certificaat nu alleen nog om bezoekers van `https://192.168.10.22` door te sturen naar het domein.

| Bestand | Plek |
| --- | --- |
| CA-sleutel en -certificaat | `/root/my-ca/ca.key`, `/root/my-ca/ca.crt` |
| Servercertificaat WEB-01 | `/etc/ssl/web01/web01.crt`, `/etc/ssl/web01/web01.key` |

Zo is het gemaakt (in `/root/my-ca`):

```
openssl genrsa -aes256 -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/C=NL/O=MijnNetwerk/OU=IT/CN=Mijn Interne Root CA"
openssl genrsa -out web01.key 2048
openssl req -new -key web01.key -out web01.csr -config web01.cnf
openssl x509 -req -in web01.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out web01.crt -days 825 -sha256 -extfile web01.cnf -extensions req_ext
mkdir -p /etc/ssl/web01
chmod 700 /etc/ssl/web01
cp web01.crt web01.key /etc/ssl/web01/
chmod 600 /etc/ssl/web01/web01.key
```

`web01.cnf` bevat het IP-adres `192.168.10.22` als Subject Alternative Name.

Wil je `https://192.168.10.22` zonder waarschuwing openen? Importeer dan `ca.crt` op je pc in **Trusted Root Certification Authorities**. Het bestand staat op `https://challenges.ms-dev.nl/ca.crt`.

---

## Controleren

1. Open `https://challenges.ms-dev.nl`. Er staat geen "Not secure" in de adresbalk.
2. Bekijk de certificaten en de vervaldatum:

```
certbot certificates
```

3. Controleer of nginx op poort 80 en 443 luistert:

```
ss -tlnp | grep nginx
```

## Beheer

| Wat | Commando |
| --- | --- |
| Certificaten en vervaldatum bekijken | `certbot certificates` |
| Verlengen testen | `certbot renew --dry-run` |
| Timer voor verlengen bekijken | `systemctl list-timers \| grep certbot` |
| Nginx-config testen en herladen | `nginx -t && systemctl reload nginx` |
| Logboek nginx | `journalctl -u nginx -n 50 --no-pager` |
| Logboek certbot | `tail -n 50 /var/log/letsencrypt/letsencrypt.log` |

## Problemen oplossen

| Probleem | Oplossing |
| --- | --- |
| "Not secure" via `https://192.168.10.22` | `ca.crt` is niet geïmporteerd op die pc. Gebruik het domein, of importeer `ca.crt`. |
| certbot meldt een fout bij Cloudflare | Het token is ingetrokken of verkeerd. Maak een nieuw token (stap 1) en zet het in `/root/.secrets/cloudflare.ini`. |
| Website laadt niet meer na een wijziging | Voer `nginx -t` uit en los de fout op, of zet de back-up `/root/challenges-ip.bak` terug. |
| Domein werkt niet, IP-adres wel | Controleer in Cloudflare of het record `challenges` bestaat en op DNS only staat. |
| `apt update` geeft 404-fouten | Ubuntu 25.04 krijgt geen updates meer. Stap over naar een LTS-versie. |

## Let op

- Het Cloudflare-token staat alleen in `/root/.secrets/cloudflare.ini` op WEB-01. Zet het nooit in deze repository.
- Deel `ca.key` en `web01.key` nooit. Alleen `ca.crt` mag naar andere pc's.
- Laat het record `challenges` in Cloudflare op **DNS only** (grijze wolk) staan.

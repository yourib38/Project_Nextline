# Configs – workers per sessie

[← Terug naar de website-map](../../README.md)

Kopieën van de bestanden waarmee de workers worden aangemaakt (zonder wachtwoorden of tokens). Uitleg: [workers.md](../../workers.md) en [automatisering.md](../../../cluster1/automatisering.md).

| Bestand | Waar het staat | Wat het doet |
| --- | --- | --- |
| `terraform/providers.tf` | CT101, `/root/terraform-workers/` | Proxmox-provider (`bpg/proxmox`) |
| `terraform/main.tf` | CT101, `/root/terraform-workers/` | Variabelen en aanroep van de module |
| `terraform/modules/session_worker/*.tf` | CT101, `/root/terraform-workers/modules/session_worker/` | De worker-container (LXC) |
| `ansible/roles/breachout_worker/` | CT101, `~/ansible-ironhold/roles/` | Docker, Traefik en images op de worker |
| `ansible/worker.yml` | CT101, `~/ansible-ironhold/` | Playbook dat de rol uitvoert |
| `ansible/worker_vars.yml` | CT101, `~/ansible-ironhold/` | Publieke sleutel van WEB-01 |
| `ansible/registry.yml` | CT101, `~/ansible-ironhold/` | Start de private registry op docker02 |
| `scripts/breachout-worker.sh` | CT101, `/usr/local/bin/breachout-worker` | Workers maken, verwijderen en tonen |
| `scripts/breachout-provision.sh` | CT101, `/usr/local/bin/breachout-provision` | Beperkte aanroep door WEB-01 |
| `app/worker_service.py` | WEB-01, `/opt/challengelab/` | App praat met CT101 |
| `nginx/workers-blok.conf` | WEB-01, `/etc/nginx/sites-available/challenges` | Nginx-aanpassing voor `/c/1xx-…` |

Let op:

- De module heeft ook een `versions.tf` met `source = "bpg/proxmox"` voor de provider.
- Het API-token van Proxmox staat in `/root/.pve_token` op CT101 en niet in deze map.
- De volledige verschillen in `docker_service.py` en `session_service.py` staan op CT101 in `~/ansible-ironhold/webapp-wijzigingen/` (git-commit `a0488bb`).

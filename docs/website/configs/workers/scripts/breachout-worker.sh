#!/bin/bash
# breachout-worker: beheer van tijdelijke session-workers (Terraform + Ansible)
set -euo pipefail
BASE=/root/terraform-workers
STATE_DIR=$BASE/sessions
ANSIBLE_DIR=/root/ansible-ironhold
MAX_AGE_MIN=480
MAX_WORKERS=${MAX_WORKERS:-5}
export PROXMOX_VE_API_TOKEN=$(cat /root/.pve_token)
mkdir -p "$STATE_DIR"
exec 9>"$BASE/.lock"
flock 9

do_destroy() {
  local sid=$1
  [ -f "$STATE_DIR/$sid" ] || { echo "onbekende sessie: $sid"; return 1; }
  local vmid; vmid=$(cat "$STATE_DIR/$sid")
  cd "$BASE"
  terraform workspace select "$sid" >/dev/null
  terraform destroy -input=false -auto-approve -var "session_id=$sid" -var "vm_id=$vmid" >/dev/null
  terraform workspace select default >/dev/null
  terraform workspace delete "$sid" >/dev/null
  rm -f "$STATE_DIR/$sid"
  echo "worker voor sessie $sid verwijderd"
}

do_create() {
  local sid=${1:-} ids=${2:-} log=/var/log/breachout-worker.log
  [ -n "$sid" ] && [ -n "$ids" ] || { echo "gebruik: create <sessie-id> <id1,id2,...>"; return 1; }
  [ ! -f "$STATE_DIR/$sid" ] || { echo "sessie bestaat al: $sid"; return 1; }
  [ "$(find "$STATE_DIR" -type f | wc -l)" -lt "$MAX_WORKERS" ] || { echo "maximum aantal workers ($MAX_WORKERS) bereikt"; return 1; }
  local used vmid=""
  used=$(cat "$STATE_DIR"/* 2>/dev/null || true)
  for n in $(seq 300 399); do
    if ! grep -qx "$n" <<< "$used"; then vmid=$n; break; fi
  done
  [ -n "$vmid" ] || { echo "geen vrije worker-plekken (max 100)"; return 1; }
  echo "$vmid" > "$STATE_DIR/$sid"
  local ip="192.168.20.$((vmid - 200))"
  local nodes=(pve001 pve002 pve003); local node=${nodes[$((vmid % 3))]}
  cd "$BASE"
  terraform workspace new "$sid" >/dev/null
  if ! terraform apply -input=false -auto-approve -var "session_id=$sid" -var "vm_id=$vmid" -var "node_name=$node" >>"$log" 2>&1; then
    echo "Terraform mislukt, ruim op (zie $log)"; do_destroy "$sid" || true; return 1
  fi
  for i in $(seq 1 40); do
    ssh -o ConnectTimeout=3 -o BatchMode=yes "$ip" true 2>/dev/null && break
    sleep 3
  done
  local ids_json='["'"${ids//,/\",\"}"'"]'
  if ! ansible-playbook -i "$ip," "$ANSIBLE_DIR/worker.yml" -e @"$ANSIBLE_DIR/worker_vars.yml" -e "{\"breachout_challenge_ids\": $ids_json}" >>"$log" 2>&1; then
    echo "Ansible mislukt, ruim op (zie $log)"; do_destroy "$sid" || true; return 1
  fi
  echo "WORKER_IP=$ip"
}

do_list() {
  for f in "$STATE_DIR"/*; do
    [ -f "$f" ] || continue
    local vmid; vmid=$(cat "$f")
    echo "$(basename "$f")  vmid=$vmid  ip=192.168.20.$((vmid - 200))  aangemaakt=$(date -r "$f" '+%F %T')"
  done
}

do_cleanup() {
  local f
  for f in $(find "$STATE_DIR" -type f -mmin +"$MAX_AGE_MIN"); do
    do_destroy "$(basename "$f")" || true
  done
}

case "${1:-}" in
  create)  do_create "${2:-}" "${3:-}" ;;
  destroy) do_destroy "${2:-}" ;;
  list)    do_list ;;
  cleanup) do_cleanup ;;
  *) echo "gebruik: breachout-worker create <sessie-id> <id1,id2,...> | destroy <sessie-id> | list | cleanup"; exit 1 ;;
esac

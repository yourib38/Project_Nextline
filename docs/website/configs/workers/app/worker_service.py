import os
import re
import subprocess

from fastapi import HTTPException

from config import SSH_KEY

WORKERS_ENABLED = os.environ.get("CHALLENGELAB_WORKERS", "1") == "1"
WORKER_MANAGER = os.environ.get("CHALLENGELAB_WORKER_MANAGER", "root@192.168.10.21")
WORKER_USER = "team"
PREFIX = re.compile(r"^(1[0-9][0-9])-")


def _ssh(host, command, timeout):
    return subprocess.run(
        ["/usr/bin/ssh", "-i", SSH_KEY, "-o", "BatchMode=yes",
         "-o", "StrictHostKeyChecking=no", host, command],
        capture_output=True, text=True, timeout=timeout,
    )


def worker_number(instance_id):
    match = PREFIX.match(instance_id or "")
    return match.group(1) if match else None


def worker_host(instance_id):
    number = worker_number(instance_id)
    return f"{WORKER_USER}@192.168.20.{number}" if number else None


def create_worker(session_id, challenge_ids):
    if not WORKERS_ENABLED:
        return None
    ids = ",".join(challenge_ids)
    try:
        result = _ssh(WORKER_MANAGER, f"create {session_id} {ids}", 270)
    except Exception:
        destroy_worker(session_id)
        raise HTTPException(
            status_code=504,
            detail="Worker aanmaken duurde te lang. Probeer het opnieuw.",
        )
    ip = ""
    for line in result.stdout.splitlines():
        if line.startswith("WORKER_IP="):
            ip = line.split("=", 1)[1].strip()
    if result.returncode != 0 or not ip:
        lines = result.stdout.strip().splitlines()
        message = lines[-1] if lines else "Worker aanmaken mislukt"
        raise HTTPException(status_code=503, detail=message)
    return ip.rsplit(".", 1)[1]


def destroy_worker(session_id):
    if not WORKERS_ENABLED:
        return
    try:
        _ssh(WORKER_MANAGER, f"destroy {session_id}", 120)
    except Exception:
        pass

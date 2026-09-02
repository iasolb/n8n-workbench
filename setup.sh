#!/usr/bin/env bash
# Stand up the n8n container on a machine that has never run it.
#
# Safe to re-run: it never overwrites an existing .env, because that file holds
# the encryption key and regenerating it silently would orphan every stored
# credential in the data volume.
#
#   ./setup.sh              set up and start
#   ./setup.sh --no-start   write config only
set -euo pipefail

start=1
[[ "${1:-}" == "--no-start" ]] && start=0

cd "$(dirname "${BASH_SOURCE[0]}")"

command -v docker >/dev/null || { echo "docker not found. Install Docker Desktop first." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "docker compose v2 not found." >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "The Docker daemon is not running. Start Docker Desktop and re-run." >&2; exit 1; }

if [ -f .env ]; then
    echo ".env already exists, keeping it (it holds the encryption key)."
else
    key="$(openssl rand -hex 32)"
    sed "s|^N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=$key|" .env.example > .env
    chmod 600 .env
    echo "Wrote .env with a fresh encryption key."
    echo "BACK THAT KEY UP. Losing it loses every credential stored in the volume."
fi

# The mounts are declared read-only and narrow, so a missing directory fails at
# container start with a confusing error rather than here with a clear one.
bank="$(grep -E '^MEMORY_BANK=' .env | cut -d= -f2-)"
bank="${bank:-../ai-memory-bank}"
for d in "$bank/automation/workflows" "$bank/state"; do
    [ -d "$d" ] || { echo "Missing mount source: $d" >&2; exit 1; }
done

if [ "$start" -eq 0 ]; then
    echo "Config written. Start it with: docker compose up -d"
    exit 0
fi

docker compose up -d

echo "Waiting for n8n to answer on 5678..."
for i in $(seq 1 60); do
    if curl -fsS --max-time 3 http://127.0.0.1:5678/healthz >/dev/null 2>&1; then
        echo "n8n is up: http://127.0.0.1:5678"
        docker compose exec -T n8n n8n --version 2>/dev/null | sed 's/^/version: /' || true
        exit 0
    fi
    sleep 2
done

# Never report success we did not observe: a start that never became healthy
# must look different from one that did.
echo "n8n did not answer on 5678 within 120s. Check: docker compose logs n8n" >&2
exit 1

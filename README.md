# n8n-workbench

The n8n instance as a file: the compose definition, its environment contract,
and the setup script that stands it up on a machine that has never run it.

## Why this repo has contents now

The PC had been running an n8n container since 2026-08-21, and the compose file
that defined it lived nowhere: not here, not in the memory bank, not anywhere in
git. This repo existed for exactly this purpose and held a single placeholder
file. So on 2026-09-01, asked to run the same thing on the Mac, there was nothing
to copy and nothing to read. That is the gap this closes.

If the PC's container differs from what is here, **the PC is the one that is
undocumented**, not this file. Reconcile toward this and record any difference.

## Setup

```bash
./setup.sh
```

It checks Docker is installed and actually running, writes `.env` with a freshly
generated encryption key (never overwriting an existing one), confirms the mount
sources exist, starts the container, and waits until n8n really answers on
`/healthz` before claiming success.

Then open <http://127.0.0.1:5678>.

**Back up `N8N_ENCRYPTION_KEY` from `.env`.** It decrypts the stored credentials
in the data volume, it is not recoverable from the volume alone, and `.env` is
gitignored so nothing else is keeping a copy.

## What the container can and cannot see

Set by `docs/n8n-config-design.md` in the memory bank, which grants this
container its own `/state` and `/workflows` and nothing else on the host.

| Mount | Source | Mode |
|---|---|---|
| `/workflows` | the memory bank's `automation/workflows/` | **read-only** |
| `/state` | the memory bank's `state/` | read-write |
| `/home/node/.n8n` | the `n8n_data` named volume | read-write |

`/workflows` is read-only deliberately: the repo is the source of truth for
workflow definitions, and an instance that can rewrite its own definitions
behind git's back is how the two drift.

The port is bound to `127.0.0.1` here. The PC exposes 5678 to the tailnet; if
this machine should too, that is a one-line change in `docker-compose.yml` and it
means anything on the tailnet can reach the editor.

## Workflows

Import the repo's workflow files:

```bash
docker compose exec -T n8n n8n import:workflow --separate --input=/workflows
```

**Ten of the files carry `active: true`, and import preserves it.** On a fresh
instance with no credentials an activated schedule cannot do much, but several of
these workflows are pointed at a real mailbox, so activating them is a decision
rather than a side effect of setup. Force them off after any import, and restart,
because the CLI says plainly that a running instance will not pick the change up:

```bash
docker compose exec -T n8n n8n update:workflow --all --active=false
docker compose restart n8n
```

Verify rather than trust it, since "deactivated" and "the command printed
something" are not the same claim:

```bash
docker compose exec -T n8n node -e "const{DatabaseSync}=require('node:sqlite');const db=new DatabaseSync('/home/node/.n8n/database.sqlite',{readOnly:true});const r=db.prepare('SELECT name,active FROM workflow_entity').all();console.log('total',r.length,'active',r.filter(x=>x.active).length)"
```

Credentials (Gmail, GitHub, Calendar) are OAuth and must be added by hand in the
editor. Nothing here can or should do that for you.

## State on the Mac, 2026-09-01

Container `n8n-n8n-1`, n8n **2.36.9**, healthy on `127.0.0.1:5678`. All 14
workflow files imported, **0 active**, verified against the instance database.
No credentials configured, so nothing runs until you add them and activate
deliberately.

# Auto-Notify — Agent Guide

## What it does

Scrapes Epic Games Store free games and posts Discord embeds via webhooks. Runs as a periodic Cloud Function (2nd gen).

## Entrypoint & structure

- `main.py` — single entrypoint, no CLI args
- `Utility.py` — scrapes Epic Games API, reads/writes Firestore
- `APIResponseDict.py` — Pydantic models for Epic Games API shape
- `embed_builder.py` — dataclass Discord embed builder
- `cloud_function_entrypoint(_request)` in `main.py` — GCF HTTP trigger

## Env loading

1. If all three (`GOOGLE_CLOUD_PROJECT`, `GOOGLE_DATABASE`, `AUTO_NOTIFY_COLLECTION`) are already set → skip (GCF with `--set-env-vars`).
2. If `.env` exists → `load_dotenv()` reads it, then validates all three are present.
3. Otherwise → falls back to **Google Cloud Secret Manager** for `GOOGLE_DATABASE` and `AUTO_NOTIFY_COLLECTION`. Requires valid GCP credentials and `GOOGLE_CLOUD_PROJECT` in env.

## Required env vars

| Var | Source |
|---|---|
| `GOOGLE_CLOUD_PROJECT` | env/`--set-env-vars` |
| `GOOGLE_DATABASE` | env/`--set-env-vars` |
| `AUTO_NOTIFY_COLLECTION` | env/`--set-env-vars` |
| `FUNCTION_NAME` | deploy only |
| `FUNCTION_SERVICE_ACCOUNT` | deploy only |
| `CRON_SCHEDULE` | deploy only |
| `GOOGLE_CLOUD_REGION` | deploy only |

GitLab CI uses Workload Identity Federation — no service account key variable needed.

Firestore collection stores `url` (webhook URL map) and `notified` (game IDs).

## Run locally

```sh
python main.py
```

## Deploy

```bash
# via deploy script
./deployment/deploy.sh
```

Or pushed to `main` branch → GitLab CI in `.gitlab-ci.yml` deploys automatically.

Cloud Functions 2nd gen via `--source .` — Cloud Buildpacks auto-detect Python.

Env vars are set via `--set-env-vars`, not Secret Manager (the Secret Manager fallback is only for local dev without `.env`).

## Package management

- `pyproject.toml` with Poetry (`package-mode = false` — app, not library)
- `requirements.txt` frozen via `poetry-plugin-export`
- Python >=3.13

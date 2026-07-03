# Auto-Notify

[![GitHub License](https://img.shields.io/github/license/AhdaAI/Auto-Notify)](https://github.com/AhdaAI/Auto-Notify/blob/main/LICENSE)

Scrapes Epic Games Store free games daily and posts Discord embeds via webhook. Runs as a Cloud Function (2nd gen) with Cloud Scheduler.

## How it works

1. Scrapes the Epic Games Store for current free games
2. Compares against previously notified game IDs (stored in Firestore)
3. Sends Discord embeds only for new/unnotified games
4. Overwrites `notified` list with all current game IDs

## Database (Firestore)

One document per source (e.g., `epic_games`):

```json
{
  "url": {
    "server_name": "https://discord.com/api/webhooks/..."
  },
  "notified": []
}
```

- `url` — webhook URL map per Discord server
- `notified` — game IDs that have already been sent (auto-populated, never modify by hand)

## Prerequisites

- Python >=3.13
- [Poetry](https://python-poetry.org/)
- Google Cloud project with Firestore, Cloud Functions, Cloud Scheduler APIs enabled
- A service account with Firestore read/write and Cloud Functions Invoker permissions

## Setup

```sh
git clone https://github.com/AhdaAI/Auto-Notify.git
cd Auto-Notify
poetry install
poetry export --format requirements.txt --output requirements.txt
cp .env.example .env
# edit .env with your values
```

## Run locally

```sh
python main.py
```

Requires either `.env` file or valid GCP credentials with Secret Manager access.

## Deploy

### Manual (deploy script)

```sh
./deployment/deploy.sh
```

Loads variables from `.env` (or `$ENV_FILE`). Creates/updates the Cloud Function and Cloud Scheduler job.

### CI/CD (GitLab)

Push to `main` branch with Python changes → `.gitlab-ci.yml` validates and deploys automatically. Uses Workload Identity Federation (no service account key variable).

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `GOOGLE_CLOUD_PROJECT` | Yes | GCP project ID |
| `GOOGLE_DATABASE` | Yes | Firestore database ID |
| `AUTO_NOTIFY_COLLECTION` | Yes | Firestore collection name |
| `FUNCTION_NAME` | Deploy only | Cloud Function name (default: `auto-notify`) |
| `FUNCTION_SERVICE_ACCOUNT` | Deploy only | Service account email for the function |
| `CRON_SCHEDULE` | Deploy only | Cloud Scheduler cron expression |
| `GOOGLE_CLOUD_REGION` | Deploy only | GCP region |
| `GOOGLE_APPLICATION_CREDENTIALS` | Local only | Path to service account key JSON |

## Project Structure

```
├── main.py                 # Entrypoint, GCF trigger, orchestration
├── Utility.py              # Epic Games scraper, Firestore read/write
├── Google.py               # Firestore client wrapper
├── embed_builder.py        # Discord embed dataclass builder
├── APIResponseDict.py      # Pydantic models for Epic Games API
├── SecretManager.py        # GCP Secret Manager wrapper
├── deployment/
│   └── deploy.sh           # Manual deployment script
├── .gitlab-ci.yml          # GitLab CI/CD pipeline
├── AGENTS.md               # Agent guidance for AI coding tools
├── .env.example            # Environment variable template
├── pyproject.toml          # Poetry config
└── requirements.txt        # Pinned dependencies
```

## License

MIT

# Auto-Notify

[![GitHub License](https://img.shields.io/github/license/AhdaAI/Auto-Notify)](https://github.com/AhdaAI/Auto-Notify/blob/main/LICENSE)

Scrapes Epic Games Store free games daily and posts Discord embeds via webhook.

[`.env` setup](.env.example)

## How it works

1. Scrapes the Epic Games Store for current free games
2. Compares against previously notified games (tracked in Firestore)
3. Sends Discord embeds only for new free games
4. Updates the notified game list

## Database (Firestore)

One document per source. Document ID is the source name (e.g., `epic_games`).

```json
{
  "epic_games": {
    "url": {
      "server_name": "https://discord.com/api/webhooks/..."
    },
    "notified": []
  }
}
```

- `url` — webhook URL map per Discord server
- `notified` — game IDs that have already been sent (auto-populated, never modify by hand)

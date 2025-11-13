# Automate Discord Notification

Will automatically create an embedding for discord.

[.env](config-example.md)

## Currently automated

- Epic Games Store Free Games scraper
- Automate notify on discord (Webhook)

## Database

Currently you need to input the url manually.

```json
{
  "collection_name": {
    "timestamp" : {
        "last_updated": timestamp,
        "update_on": timestamp
    },
    "url": {
        "server_name": "https://discord.com/api/webhook/******/*****"
    }
  }
}
```

## Future Plan

- Local database (.json/.csv file)
- Simplified webhook url registration

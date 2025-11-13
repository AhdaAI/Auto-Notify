import os
import requests
import json
import time
from datetime import datetime, timezone
from dateutil.parser import isoparse
from rich import print
from pathlib import Path
from dotenv import load_dotenv
from embed_builder import Embed, AuthorObject, ImageObject, FieldObject

from Utility import Utility

EPIC_GAMES_URL = "https://store-site-backend-static-ipv4.ak.epicgames.com/freeGamesPromotions?locale=en-US&country=ID"
EPIC_GAMES_CONTENT = "https://store-content-ipv4.ak.epicgames.com/api/en-US/content/products/"
USE_GCP = False

if Path(".env").exists():
    load_dotenv()
else:
    from SecretManager import SecretManager
    manager = SecretManager()

    with open(Path("config.json"), "r") as f:
        data = json.load(f)
        for env in data.get("env"):
            secret = manager.get_secret(env)
            if secret[1]:
                os.environ[env] = secret[1]
            else:
                raise ValueError("Secret is empty.")


def main():
    """Main Function

    Scrape the epic games store for free game and notified in discord.
    """
    docs = Utility.get_info()

    if not docs.get("update"):
        print(f"[green]Nothing to update")
        return

    # --- Scrape Epic Games Store ---
    data = Utility.scrapper()
    end_date = ""
    embeds = []
    for game in data:  # Populate embed
        if not game.promotions:
            continue

        offers = game.promotions.promotionalOffers
        end_date = offers[0].promotionalOffers[0].endDate

        product_slug = game.productSlug
        if not product_slug:
            if not game.catalogNs or not game.catalogNs.mappings:
                continue
            product_slug = game.catalogNs.mappings[0].pageSlug

        key_image = game.keyImages
        image_tall = ""
        for image in key_image:
            if image.type == "OfferImageTall":
                image_tall = image.url

        short_description = game.description
        if game.title == short_description:
            game_content = requests.get(
                f"{EPIC_GAMES_CONTENT}{product_slug}", timeout=10000)
            if game_content.status_code == 200:
                game_content = game_content.json()
                short_description = game_content['pages'][0]['data']['about']['shortDescription']

        embed = Embed(
            color="1752220",
            author=AuthorObject("Epic Games", "https://store.epicgames.com"),
            image=ImageObject(image_tall),
            title=game.title,
            url=f"https://store.epicgames.com/en-US/p/{product_slug}",
            timestamp=end_date,  # type: ignore
            description=f"*Original Price : IDR {int(game.price.totalPrice.originalPrice)/100:,.2f}*",
            fields=[
                FieldObject("Description", f"```{short_description}```")
            ]
        )
        embeds.append(embed.to_dict())

    # --- Sent to webhook ---
    webhook_user = {
        "username": "Epic Free Games",
        "embeds": embeds
    }

    for key, value in docs.get("url", {}).items():
        try:
            result = requests.post(
                value,
                json=webhook_user,
                timeout=10000
            )
            result.raise_for_status()
        except requests.exceptions.HTTPError as err:
            print(f"[red]ERROR OCCURRED:\n{err}")
            continue
        print(f"[cyan]Updated [bold]{key}.")

    Utility.update_info("timestamp", {
        "last_updated": datetime.now(timezone.utc),
        "update_on": isoparse(end_date) if end_date else None
    })
    print(f"[green]Database updated")


if __name__ == "__main__":
    start = time.perf_counter()
    main()
    end = time.perf_counter()
    elapse = end - start
    print(f"[cyan]Elapsed: {elapse:.2f} Second")

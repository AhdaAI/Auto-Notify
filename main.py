import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests
from dotenv import load_dotenv
from rich import print

from embed_builder import Embed, EmbedAuthor, EmbedField, EmbedImage
from Utility import Utility

SOURCE = "epic_games"
EPIC_GAMES_CONTENT = (
    "https://store-content-ipv4.ak.epicgames.com/api/en-US/content/products/"
)

REQUIRED_ENV_VARS = ("GOOGLE_CLOUD_PROJECT", "GOOGLE_DATABASE", "AUTO_NOTIFY_COLLECTION")

if not all(map(os.getenv, REQUIRED_ENV_VARS)):
    if Path(".env").exists():
        load_dotenv()
        if not all(map(os.getenv, REQUIRED_ENV_VARS)):
            raise ValueError(
                f".env file is missing one or more required vars: {', '.join(REQUIRED_ENV_VARS)}"
            )
    else:
        project = os.getenv("GOOGLE_CLOUD_PROJECT")
        if not project:
            raise ValueError(
                "GOOGLE_CLOUD_PROJECT must be set when using Secret Manager fallback."
            )

        from SecretManager import SecretManager

        manager = SecretManager(parent=f"projects/{project}")

        for env in ("GOOGLE_DATABASE", "AUTO_NOTIFY_COLLECTION"):
            secret = manager.get_secret(env)
            if secret[1]:
                os.environ[env] = secret[1]
            else:
                raise ValueError("Secret is empty.")


def build_embed(game):
    product_slug = game.productSlug
    if not product_slug:
        if not game.catalogNs or not game.catalogNs.mappings:
            return None
        product_slug = game.catalogNs.mappings[0].pageSlug

    key_image = game.keyImages
    image_tall = ""
    for image in key_image:
        if image.type == "OfferImageTall":
            image_tall = image.url

    short_description = game.description
    if game.title == short_description:
        game_content = requests.get(
            f"{EPIC_GAMES_CONTENT}{product_slug}", timeout=10000
        )
        if game_content.status_code == 200:
            game_content = game_content.json()
            short_description = game_content["pages"][0]["data"]["about"][
                "shortDescription"
            ]

    return Embed(
        color=1752220,
        author=EmbedAuthor("Epic Games", "https://store.epicgames.com"),
        image=EmbedImage(image_tall),
        title=game.title,
        url=f"https://store.epicgames.com/en-US/p/{product_slug}",
        timestamp=game.promotions.promotionalOffers[0].promotionalOffers[0].endDate,
        description=f"*Original Price : IDR {int(game.price.totalPrice.originalPrice)/100:,.2f}*",
        fields=[
            EmbedField("Description", f"```{short_description}```")
        ]
    ).to_dict()


def main():
    """Main Function

    Scrape the epic games store for free game and notified in discord.
    """
    info = Utility.get_info(SOURCE)
    notified: list[str] = info["notified"]

    # --- Scrape Epic Games Store ---
    free_games = Utility.scrapper()

    new_games = [g for g in free_games if g.id not in notified]

    if not new_games:
        print("[green]No new free games to notify")
        return

    embeds = []
    with ThreadPoolExecutor(max_workers=5) as pool:
        futures = [pool.submit(build_embed, g) for g in new_games]
        for future in as_completed(futures):
            embed = future.result()
            if embed:
                embeds.append(embed)

    # --- Sent to webhook ---
    webhook_user = {"username": "Epic Free Games", "embeds": embeds}

    for key, value in info["url"].items():
        try:
            result = requests.post(value, json=webhook_user, timeout=10000)
            result.raise_for_status()
        except requests.exceptions.HTTPError as err:
            print(f"[red]ERROR OCCURRED:\n{err}")
            continue
        print(f"[cyan]Updated [bold]{key}.")

    all_ids = [g.id for g in free_games]
    if Utility.update_notified(SOURCE, all_ids):
        print("[green]Database updated")
    else:
        print("[red]Failed to update database")


def cloud_function_entrypoint(_request):
    main()
    return "OK", 200


if __name__ == "__main__":
    start = time.perf_counter()
    main()
    end = time.perf_counter()
    elapse = end - start
    print(f"[cyan]Elapsed: {elapse:.2f} Second")

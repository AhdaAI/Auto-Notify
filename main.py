"""
MAIN EXECUTION SCRIPT
Args:
    --dev: For development
    --env-file: Specified the .env file
    --deploy: Specified the deployment method. (GCP, Docker)
"""
import os
import sys
import platform
import subprocess
import json
from datetime import datetime, timezone
from pathlib import Path
from dateutil.parser import isoparse
import requests
from google.cloud import firestore
from dotenv import load_dotenv
from embed_builder import Embed, AuthorObject, ImageObject, FieldObject

EPIC_GAMES_URL = "https://store-site-backend-static-ipv4.ak.epicgames.com/freeGamesPromotions?locale=en-US&country=ID"
EPIC_GAMES_CONTENT = "https://store-content-ipv4.ak.epicgames.com/api/en-US/content/products/"


def deploy(terminal_input: list):
    """Deployment script.

    Parameters:
        provider: Provider for deployment. (Default: GCP)
    """
    print("Not implemented yet.")


def main():
    """Main Function

    Scrape the epic games store for free game and notified in discord.
    """
    gcp = True
    # --- Fetch database ---
    if not os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
        gcp = False
        print("No GCP Credential Detected.")
        print("Continuing without GCP.")
        print("Checking local database...")
        filepath = Path(os.getenv("DATABASE_FILENAME") or "")
        if not filepath.exists():
            print(f"ERROR: Cannot find database. ({filepath})")
            exit(1)
        with open(filepath, "r", encoding='utf8') as file:
            docs = json.load(file)
    else:
        db = firestore.Client(
            os.getenv("GCP_PROJECT_ID"),
            database=os.getenv("GCP_DATABASE_NAME")
        ).collection(f"{os.getenv("GCP_DATABASE_COLLECTION")}")
        docs = {}
        for doc in db.stream():
            data = doc.to_dict()
            docs[doc.id] = data

    update = []
    # --- Checking for update ---
    for doc in docs.values():
        temp = {}
        # Checking for epic and steam subs
        # Currently only scraping epic
        if not doc['subscription']['epic'] and not doc['subscription']['steam']:
            continue
        update_at = doc['webhook']['updateAt']
        if not update_at or update_at <= datetime.now(timezone.utc):
            temp[doc['id']] = doc['webhook']
            update.append(temp)
    if len(update) == 0:
        print("Nothing to update.")
        exit(0)

    # --- Scrape Epic Games Store ---
    response = requests.get(EPIC_GAMES_URL, timeout=10000)
    data = response.json()['data']['Catalog']['searchStore']['elements']
    end_date = ""
    embeds = []
    for game in data:
        discount_price = game['price']['totalPrice']['fmtPrice']['discountPrice']
        promotions = game['promotions']
        if not promotions or (game['status'] != "ACTIVE") or (discount_price != "0"):
            continue

        if not promotions['promotionalOffers'][0]['promotionalOffers']:
            continue

        end_date = promotions['promotionalOffers'][0]['promotionalOffers'][0]['endDate']

        product_slug = game['productSlug']
        if not product_slug:
            product_slug = game['catalogNs']['mappings'][0]['pageSlug']

        key_image = game['keyImages']
        image_tall = ""
        for image in key_image:
            if image['type'] == "OfferImageTall":
                image_tall = image['url']

        short_description = game['description']
        if game['title'] == short_description:
            game_content = requests.get(
                f"{EPIC_GAMES_CONTENT}{product_slug}", timeout=10000)
            if game_content.status_code == 200:
                game_content = game_content.json()
                short_description = game_content['pages'][0]['data']['about']['shortDescription']

        embed = Embed(
            color="1752220",
            author=AuthorObject("Epic Games", "https://store.epicgames.com"),
            image=ImageObject(image_tall),
            title=game['title'],
            url=f"https://store.epicgames.com/en-US/p/{product_slug}",
            timestamp=end_date,
            description=f"*Original Price : IDR {int(game['price']['totalPrice']['originalPrice'])/100:,.2f}*",
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

    for webhook_data in update:
        for key, value in webhook_data.items():
            try:
                result = requests.post(
                    value['url'],
                    json=webhook_user,
                    timeout=10000
                )
                result.raise_for_status()
            except requests.exceptions.HTTPError as err:
                print(err)
            else:
                print(f"{f" code {result.status_code}. ":=^40}")
                print("Payload delivered successfully.")

            if gcp:
                document = db.document(key)
                update_doc = document.get().to_dict()
                update_doc['webhook']['updateAt'] = isoparse(  # type: ignore
                    end_date)
                document.update(update_doc)  # type: ignore


if __name__ == "__main__":
    args = sys.argv
    DOTENV_FILENAME = ".env"

    # --- Dev Toggle ---
    if "--dev" in args:
        print('Expecting ".env.dev" or ".env.development"')
        for filename in [".env.dev", ".env.development"]:
            if Path(filename).exists():
                DOTENV_FILENAME = filename
        if DOTENV_FILENAME == ".env":
            print("ERROR: File cannot be found.")
            exit(1)

    # --- Checking Env File ---
    if "--env-file" in args:
        file_path = Path(args[args.index("--env-file") + 1])
        if file_path.exists():
            print(f"Env file detected. ({file_path})")
            DOTENV_FILENAME = file_path
        else:
            print(f"ERROR: File is not exist. ({file_path})")
            exit(1)

    load_dotenv(DOTENV_FILENAME)

    # --- Deployment Process ---
    if "--deploy" in args:
        deploy(args)

    main()

"""
MAIN EXECUTION SCRIPT
Args:
    --env-file: Specified the .env file
    --deploy: Specified the deployment method. (GCP, Docker)
"""
import os
import sys
import platform
import subprocess
import json
from pathlib import Path
from google.cloud import firestore
from dotenv import load_dotenv

EPIC_GAMES_URL = {
    "store": "https://store-site-backend-static-ipv4.ak.epicgames.com/freeGamesPromotions?locale=en-US&country=ID",
    "content": "https://store-content-ipv4.ak.epicgames.com/api/en-US/content/products/"
}


def deploy(project_name: str | None, provider: str = "GCP"):
    """Deployment script.

    Parameters:
        provider: Provider for deployment. (Default: GCP)
    """
    print("Not implemented yet.")


def main():
    """Main Function

    Scrape the epic games store for free game and notified in discord.
    """
    if not os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
        print("No GCP Credential Detected.")
        print("Continuing without GCP.")
        print("Checking local database...")
        with open("database.json", "r", encoding='utf8') as file:
            docs = json.load(file)
    else:
        db = firestore.Client(
            os.getenv("GCP_PROJECT_ID"),
            database=os.getenv("GCP_DATABASE_NAME")
        ).collection(f"{os.getenv("GCP_DATABASE_COLLECTION")}").stream()
        docs = {}
        for doc in db:
            data = doc.to_dict()
            print(data)
            docs[doc.id] = data

    print(docs)


if __name__ == "__main__":
    args = sys.argv

    # --- Checking Env File ---
    if not "--env-file" in args:
        load_dotenv()
    else:
        file_path = Path(args[args.index("--env-file") + 1])
        if file_path.exists():
            print(f"Env file detected. ({file_path})")
            load_dotenv(file_path)
        else:
            print(f"ERROR: File is not exist. ({file_path})")
            exit(1)

    # --- Deployment Process ---
    if "--deploy" in args:
        DEFAULT_DEPLOYMENT = "GCP"
        deployment_options = ['GCP', 'Docker']
        if not args[args.index("--deploy") + 1] in deployment_options:
            print(
                f"Please choose from the following list: {deployment_options}")
            exit(1)

        DEFAULT_DEPLOYMENT = args[args.index("--deploy") + 1]
        if DEFAULT_DEPLOYMENT == "Docker":
            subprocess.run(
                ["docker", "build", "deployment/Dockerfile"], check=True)
            exit(0)
        else:
            if not os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
                print(
                    f"ERROR: Cannot find Google Application Credential. ({os.getenv("GOOGLE_APPLICATION_CREDENTIALS")})")
                exit(1)
            deploy(DEFAULT_DEPLOYMENT)

    main()

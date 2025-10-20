import requests

from datetime import datetime, timezone

from APIResponseDict import APIResponse, Element
from Google import Google


BACKEND_URL = "https://store-site-backend-static-ipv4.ak.epicgames.com/freeGamesPromotions?locale=en-US&country=ID"


class Utility:
    @staticmethod
    def scrapper() -> list[Element]:
        """
        Get all free games based on the following filter

        - Elements promotions list (is empty?)
        - Promotions promotional offers (are there a promotion offer?)
        - Elements discount price (is it 0?)

        :return:
        List[ Element ]
        """
        response = requests.get(BACKEND_URL, timeout=10000)
        api_response = APIResponse(**response.json())
        elements = api_response.data.Catalog.searchStore.elements
        offer_list = [
            game for game in elements if game.promotions and game.promotions.promotionalOffers and (game.price.totalPrice.fmtPrice.discountPrice == "0")
        ]
        return offer_list

    @staticmethod
    def get_info(local: bool = False) -> dict:
        payload = {
            "update": False,
            "url": {}
        }

        google = Google()
        data = google.fetch_db()

        if data:
            if isinstance(data.get("timestamp"), dict):
                update_on = data["timestamp"].get("update_on")
                if isinstance(update_on, str):
                    update_on = datetime.fromisoformat(
                        update_on.replace('Z', '+00:00'))
                if update_on and update_on > datetime.now(timezone.utc):
                    return payload

            if isinstance(data.get("url"), dict):
                payload["update"] = True
                payload["url"] = data.get("url")

            return payload
        else:
            raise ValueError("Data is empty, check the database.")

    @staticmethod
    def update_info(document_id: str, data: dict):
        google = Google()
        google.update_db(document_id, data)

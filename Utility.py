import requests

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
    def get_info(source: str) -> dict:
        google = Google()
        data = google.fetch_doc(source)

        if not data:
            raise ValueError(f"Document '{source}' not found in database.")

        return {
            "url": data.get("url", {}),
            "notified": data.get("notified", []),
        }

    @staticmethod
    def update_notified(source: str, game_ids: list[str]) -> bool:
        google = Google()
        return google.update_db(source, {"notified": game_ids})

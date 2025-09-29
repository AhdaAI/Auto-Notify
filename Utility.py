import requests

from APIResponseDict import APIResponse, Element


BACKEND_URL = "https://store-site-backend-static-ipv4.ak.epicgames.com/freeGamesPromotions?locale=en-US&country=ID"


class Utility:
    @staticmethod
    def scrapper() -> list[Element]:
        response = requests.get(BACKEND_URL, timeout=10000)
        api_response = APIResponse(**response.json())
        elements = api_response.data.Catalog.searchStore.elements
        offer_list = [
            game for game in elements if game.promotions and game.promotions.promotionalOffers and (game.price.totalPrice.fmtPrice.discountPrice == "0")
        ]
        return offer_list

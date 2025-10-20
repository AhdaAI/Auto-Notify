import os
from datetime import datetime

from google.cloud import firestore
from google.cloud.firestore import CollectionReference, DocumentSnapshot


class Google:
    def __init__(self) -> None:
        self._client = firestore.Client(
            project=os.getenv("GOOGLE_CLOUD_PROJECT"),
            database=os.getenv("GOOGLE_DATABASE")
        )

    def fetch_db(self) -> dict[str, dict[str, str | datetime]]:
        data = {}
        collection: CollectionReference = self._client.collection(
            os.getenv("GOOGLE_DATABASE_COLLECTION", "")
        )

        docs: list[DocumentSnapshot] = list(collection.stream())
        for doc in docs:
            data[doc.id] = doc.to_dict()

        return data

    def update_db(self, document_id: str, data: dict):
        try:
            self._client.collection(
                os.getenv("GOOGLE_DATABASE_COLLECTION", "")
            ).document(document_id).update(data, timeout=10000)
            return True
        except:
            return False

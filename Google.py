import os

os.environ.setdefault("GRPC_VERBOSITY", "ERROR")
os.environ.setdefault("GRPC_ENABLE_FORK_SUPPORT", "0")

from google.cloud import firestore
from google.cloud.firestore import CollectionReference, DocumentSnapshot


class Google:
    def __init__(self) -> None:
        self._client = firestore.Client(
            project=os.getenv("GOOGLE_CLOUD_PROJECT"),
            database=os.getenv("GOOGLE_DATABASE"),
        )
        self._collection: CollectionReference = self._client.collection(
            os.getenv("AUTO_NOTIFY_COLLECTION", "")
        )

    def fetch_doc(self, document_id: str) -> dict | None:
        doc: DocumentSnapshot = self._collection.document(document_id).get()
        return doc.to_dict() if doc.exists else None

    def create_doc(self, document_id: str, data: dict) -> bool:
        try:
            self._collection.document(document_id).set(data, timeout=10000)
            return True
        except Exception as e:
            print(repr(e))
            return False

    def update_db(self, document_id: str, data: dict):
        try:
            self._collection.document(document_id).update(data, timeout=10000)
            return True
        except Exception as e:
            print(repr(e))
            return False

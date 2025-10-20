import os

from google.cloud import secretmanager


class SecretManager:
    def __init__(self, parent: str = f"projects/{os.getenv("GOOGLE_CLOUD_PROJECT")}"):
        self._client = secretmanager.SecretManagerServiceClient()
        self._parent = parent

    def get_secret(self, secret_id: str, version_id: str = "latest") -> tuple[str, str]:
        """Retrieves a secret from Google Cloud Secret Manager.

        Args
        ---
            secret_id (str): The ID of the secret to retrieve.
            version_id (str, optional): The version of the secret to retrieve. Defaults to "latest".
        Returns
        ---
            - tuple[str, str]: A tuple containing the secret ID as key and its corresponding value.
            - Format: (secret_id, secret_value)
        Raises
        ---
        - google.api_core.exceptions.PermissionDenied: If the caller doesn't have permission.
        - google.api_core.exceptions.NotFound: If the requested secret or version does not exist.
        """

        try:
            url = f"{self._parent}/secrets/{secret_id}/versions/{version_id}"
            response = self._client.access_secret_version(
                request={
                    "name": url
                }
            )
            payload = response.payload.data.decode("UTF-8")
        except Exception as e:
            raise Exception(f"Failed to get secret {secret_id}: {str(e)}")

        return (secret_id, payload)

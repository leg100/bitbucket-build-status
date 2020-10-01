import json
import os

from google.cloud import secretmanager


def access_secret_version(secret_id, version_id="latest"):
    client = secretmanager.SecretManagerServiceClient()

    project_id = os.environ['GCP_PROJECT']
    name = f"projects/{project_id}/secrets/{secret_id}/versions/{version_id}"
    response = client.access_secret_version(name=name)

    return response.payload.data.decode('UTF-8')


class Credentials:
    _data = {}

    @classmethod
    def get(cls, provider):
        if provider.__name__ not in cls._data:
            secret_value = access_secret_version(provider.__name__.lower())
            cls._data[provider.__name__] = json.loads(secret_value)

        creds = cls._data[provider.__name__]

        return (creds['username'], creds['password'])

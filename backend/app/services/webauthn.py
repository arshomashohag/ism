"""WebAuthn service for super-admin hardware-key authentication."""

import base64
import os

import webauthn
from webauthn.helpers.structs import (
    PublicKeyCredentialDescriptor,
)

from app.config import settings


def _rp_id() -> str:
    """
    Return the Relying Party ID from settings.

    :return: WebAuthn Relying Party ID string
    """
    return settings.webauthn_rp_id


def _rp_name() -> str:
    """
    Return the Relying Party display name from settings.

    :return: WebAuthn Relying Party name string
    """
    return settings.webauthn_rp_name


class WebAuthnService:
    """
    Service for WebAuthn registration and authentication flows.

    Wraps the ``webauthn`` package (py_webauthn) to provide:
    - Hardware-key registration for new super admins
    - Hardware-key challenge/response authentication

    :ivar _CHALLENGE_BYTE_LENGTH: Number of random bytes in a challenge
    """

    _CHALLENGE_BYTE_LENGTH = 32

    def generate_registration_options(
        self, email: str
    ) -> tuple[dict, str]:
        """
        Generate WebAuthn registration options for a super admin.

        Returns the serialised options dict and a base-64 encoded
        challenge to keep in server-side state until verification.

        :param email: Super admin email used as the user handle
        :return: Tuple of (options_dict, challenge_b64)
        """
        challenge = os.urandom(self._CHALLENGE_BYTE_LENGTH)
        options = webauthn.generate_registration_options(
            rp_id=_rp_id(),
            rp_name=_rp_name(),
            user_id=email.encode(),
            user_name=email,
            challenge=challenge,
        )
        import json
        options_dict = json.loads(
            webauthn.options_to_json(options)
        )
        challenge_b64 = base64.b64encode(challenge).decode()
        return options_dict, challenge_b64

    def verify_registration(
        self,
        credential_json: dict,
        expected_challenge_b64: str,
        expected_origin: str,
    ) -> dict:
        """
        Verify a WebAuthn registration response from the client.

        :param credential_json: Raw credential dict from the client
        :param expected_challenge_b64: Base-64 encoded challenge
        :param expected_origin: Expected request origin URL
        :return: Stored credential dict (credential_id, public_key,
                 sign_count)
        :raises ValueError: If verification fails
        """
        expected_challenge = base64.b64decode(
            expected_challenge_b64
        )
        try:
            verification = webauthn.verify_registration_response(
                credential=credential_json,
                expected_challenge=expected_challenge,
                expected_rp_id=_rp_id(),
                expected_origin=expected_origin,
            )
        except Exception as exc:
            raise ValueError(
                f"WebAuthn registration failed: {exc}"
            ) from exc

        return {
            "credential_id": base64.b64encode(
                verification.credential_id
            ).decode(),
            "public_key": base64.b64encode(
                verification.credential_public_key
            ).decode(),
            "sign_count": verification.sign_count,
        }

    def generate_authentication_options(
        self, credential_id_b64: str
    ) -> tuple[dict, str]:
        """
        Generate WebAuthn authentication challenge for a super admin.

        :param credential_id_b64: Base-64 credential ID stored at
                                  registration time
        :return: Tuple of (options_dict, challenge_b64)
        """
        import json

        challenge = os.urandom(self._CHALLENGE_BYTE_LENGTH)
        credential_id = base64.b64decode(credential_id_b64)
        options = webauthn.generate_authentication_options(
            rp_id=_rp_id(),
            challenge=challenge,
            allow_credentials=[
                PublicKeyCredentialDescriptor(id=credential_id)
            ],
        )
        options_dict = json.loads(
            webauthn.options_to_json(options)
        )
        challenge_b64 = base64.b64encode(challenge).decode()
        return options_dict, challenge_b64

    def verify_authentication(
        self,
        credential_json: dict,
        expected_challenge_b64: str,
        expected_origin: str,
        stored_credential: dict,
    ) -> int:
        """
        Verify a WebAuthn authentication response from the client.

        :param credential_json: Raw credential dict from the client
        :param expected_challenge_b64: Base-64 encoded challenge
        :param expected_origin: Expected request origin URL
        :param stored_credential: Credential dict saved at registration
        :return: Updated sign_count to persist
        :raises ValueError: If verification fails
        """
        expected_challenge = base64.b64decode(
            expected_challenge_b64
        )
        public_key = base64.b64decode(
            stored_credential["public_key"]
        )
        sign_count = stored_credential.get("sign_count", 0)

        try:
            verification = webauthn.verify_authentication_response(
                credential=credential_json,
                expected_challenge=expected_challenge,
                expected_rp_id=_rp_id(),
                expected_origin=expected_origin,
                credential_public_key=public_key,
                credential_current_sign_count=sign_count,
            )
        except Exception as exc:
            raise ValueError(
                f"WebAuthn authentication failed: {exc}"
            ) from exc

        return verification.new_sign_count

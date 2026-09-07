"""Standard cryptographic building blocks; no home-grown encryption."""

from __future__ import annotations

import secrets

from argon2 import PasswordHasher
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305


PASSWORDS = PasswordHasher()


def new_device_key() -> bytes:
    return secrets.token_bytes(32)


def new_challenge() -> bytes:
    return secrets.token_bytes(16)


def encrypt(key: bytes, nonce: bytes, plaintext: bytes, context: bytes) -> bytes:
    """Encrypt and authenticate one bounded RetroWire payload."""
    return ChaCha20Poly1305(key).encrypt(nonce, plaintext, context)


def decrypt(key: bytes, nonce: bytes, ciphertext: bytes, context: bytes) -> bytes:
    return ChaCha20Poly1305(key).decrypt(nonce, ciphertext, context)


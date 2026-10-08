#!/usr/bin/env python3
"""Generate the secrets a self-hosted Supabase .env needs.

Usage: python3 generate-keys.py >> keys.env   (then copy the values into supabase/docker/.env)

ANON_KEY and SERVICE_ROLE_KEY are JWTs signed with JWT_SECRET, so all three must be
replaced together. Never commit the output.
"""
import base64
import hashlib
import hmac
import json
import secrets
import time


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def sign_jwt(payload: dict, secret: str) -> str:
    header = b64url(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
    body = b64url(json.dumps(payload, separators=(",", ":")).encode())
    sig = hmac.new(secret.encode(), f"{header}.{body}".encode(), hashlib.sha256).digest()
    return f"{header}.{body}.{b64url(sig)}"


def token(n: int) -> str:
    # Alphanumeric only, so values are safe inside .env files and connection strings.
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return "".join(secrets.choice(alphabet) for _ in range(n))


now = int(time.time())
exp = now + 10 * 365 * 24 * 3600  # 10 years
jwt_secret = token(48)

print(f"POSTGRES_PASSWORD={token(32)}")
print(f"JWT_SECRET={jwt_secret}")
print(f"ANON_KEY={sign_jwt({'role': 'anon', 'iss': 'supabase', 'iat': now, 'exp': exp}, jwt_secret)}")
print(f"SERVICE_ROLE_KEY={sign_jwt({'role': 'service_role', 'iss': 'supabase', 'iat': now, 'exp': exp}, jwt_secret)}")
print("DASHBOARD_USERNAME=admin")
print(f"DASHBOARD_PASSWORD={token(24)}")
print(f"SECRET_KEY_BASE={token(64)}")
print(f"VAULT_ENC_KEY={token(32)}")
print(f"PG_META_CRYPTO_KEY={token(32)}")
print(f"LOGFLARE_PUBLIC_ACCESS_TOKEN={token(32)}")
print(f"LOGFLARE_PRIVATE_ACCESS_TOKEN={token(32)}")

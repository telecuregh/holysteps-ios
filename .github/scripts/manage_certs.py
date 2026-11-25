#!/usr/bin/env python3
"""
Revoke the oldest iOS Development certificate if the account is at Apple's
2-cert limit, so xcodebuild -allowProvisioningUpdates can always create a
fresh one without hitting the cap.

Required environment variables (set from GitHub Actions secrets):
  ASC_KEY_ID      App Store Connect API key ID
  ASC_ISSUER_ID   App Store Connect issuer ID
  RUNNER_TEMP     Path to the runner's temp folder (set by GitHub Actions)

The file $RUNNER_TEMP/AuthKey.p8 must already exist (written by the
"Write the API key" step that precedes this script).
"""
import os, json, time, base64, urllib.request, urllib.error

key_id    = os.environ["ASC_KEY_ID"]
issuer_id = os.environ["ASC_ISSUER_ID"]
key_path  = os.path.join(os.environ["RUNNER_TEMP"], "AuthKey.p8")

# ── Generate a JWT for the App Store Connect API ──────────────────────────────
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

with open(key_path, "rb") as f:
    private_key = serialization.load_pem_private_key(f.read(), password=None)

def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

now     = int(time.time())
header  = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
payload = b64url(json.dumps({"iss": issuer_id, "iat": now, "exp": now + 1200,
                              "aud": "appstoreconnect-v1"}).encode())
msg     = f"{header}.{payload}".encode()
r, s    = decode_dss_signature(private_key.sign(msg, ec.ECDSA(hashes.SHA256())))
token   = f"{header}.{payload}.{b64url(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"

# ── List iOS Development certificates ────────────────────────────────────────
BASE = "https://api.appstoreconnect.apple.com/v1"

def asc_get(path):
    req = urllib.request.Request(f"{BASE}/{path}",
                                 headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

def asc_delete(path):
    req = urllib.request.Request(f"{BASE}/{path}", method="DELETE",
                                 headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        return e.code

try:
    data  = asc_get("certificates?filter[certificateType]=IOS_DEVELOPMENT&limit=20")
    certs = data.get("data", [])
    print(f"iOS Development certificates on account: {len(certs)}")

    if len(certs) >= 2:
        # Sort ascending by expiration date — revoke the oldest
        oldest = sorted(certs, key=lambda c: c["attributes"].get("expirationDate", ""))[0]
        cid    = oldest["id"]
        name   = oldest["attributes"].get("name", cid)
        exp    = oldest["attributes"].get("expirationDate", "unknown")
        print(f"At limit. Revoking oldest cert: '{name}'  expires={exp}  id={cid}")
        status = asc_delete(f"certificates/{cid}")
        if status in (200, 204):
            print("Revoked successfully — the archive step can now create a fresh cert.")
        else:
            print(f"Revoke returned HTTP {status}. The archive may still succeed if one cert expired.")
    else:
        print("Under the 2-cert limit — nothing to revoke.")

except Exception as exc:
    # Non-fatal: print and let xcodebuild try anyway.
    print(f"Warning: certificate pre-check failed ({exc}). Continuing with the build.")

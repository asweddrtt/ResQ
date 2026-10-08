#!/usr/bin/env python3
"""Upload the storage files downloaded from the paused project into self-hosted Supabase.

Expected layout (one folder per bucket, as downloaded from the dashboard):
    storage-export/
      verification_docs/<user-id>/file.jpg
      support_attachments/...

Usage:
    python3 upload-storage.py storage-export https://api.example.com <SERVICE_ROLE_KEY> [--public bucket1,bucket2]

Files are uploaded with upsert, so the script is safe to re-run, and it works whether or
not restore-db.sh already restored the storage.objects rows. Buckets that don't exist
yet are created (private unless listed in --public).
"""
import argparse
import json
import mimetypes
import pathlib
import sys
import urllib.error
import urllib.parse
import urllib.request


def request(method, url, key, data=None, headers=None):
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {key}")
    req.add_header("apikey", key)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def ensure_bucket(base, key, bucket, public):
    status, _ = request("GET", f"{base}/storage/v1/bucket/{urllib.parse.quote(bucket)}", key)
    if status == 200:
        return
    body = json.dumps({"id": bucket, "name": bucket, "public": public}).encode()
    status, resp = request("POST", f"{base}/storage/v1/bucket", key, body, {"Content-Type": "application/json"})
    if status not in (200, 201):
        sys.exit(f"Could not create bucket {bucket}: {status} {resp[:200]!r}")
    print(f"created bucket {bucket} (public={public})")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", type=pathlib.Path)
    ap.add_argument("url", help="public API URL of the self-hosted stack, e.g. https://api.example.com")
    ap.add_argument("service_role_key")
    ap.add_argument("--public", default="", help="comma-separated buckets to create as public")
    args = ap.parse_args()

    base = args.url.rstrip("/")
    public = {b for b in args.public.split(",") if b}
    ok = failed = 0

    for bucket_dir in sorted(p for p in args.root.iterdir() if p.is_dir()):
        bucket = bucket_dir.name
        ensure_bucket(base, args.service_role_key, bucket, bucket in public)
        for f in sorted(p for p in bucket_dir.rglob("*") if p.is_file()):
            rel = f.relative_to(bucket_dir).as_posix()
            ctype = mimetypes.guess_type(f.name)[0] or "application/octet-stream"
            url = f"{base}/storage/v1/object/{urllib.parse.quote(bucket)}/{urllib.parse.quote(rel)}"
            status, resp = request("POST", url, args.service_role_key, f.read_bytes(),
                                   {"Content-Type": ctype, "x-upsert": "true"})
            if status in (200, 201):
                ok += 1
            else:
                failed += 1
                print(f"FAILED {bucket}/{rel}: {status} {resp[:200]!r}")
        print(f"{bucket}: done")

    print(f"\nuploaded {ok} file(s), {failed} failure(s)")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()

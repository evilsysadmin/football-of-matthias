#!/usr/bin/env python3
"""Read-only verification of Football V5 R2 public WebPs, no cloud credentials.

Does not activate the manifest or trust CDN content without comparing the
known SHA-256 of the already-approved four exact local files.
"""
import concurrent.futures
import hashlib
import json
import pathlib
import sys
import urllib.error
import urllib.request

HERE = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = HERE / "games/chess-football-godot/optional_hero_v5.json"
OUTPUT = HERE / ".artifacts/football-v5-r2-check/report.json"
ROOT = "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v5/"
ORIGIN = "https://staging.football.shadowops.dpdns.org"
EXPECTED = {
    "fc_matthias_locomotion_v5.webp": ("332d71b141db33af14ae755c80d00d26fc90eb9e3810e279de2e6a3b05c059e2", 545550, 16, 3),
    "fc_matthias_dribbles_v5.webp": ("0d98a751d53354f77fabf40ddb10fefa848ee70408e05e811cf88f0d409a26ad", 390132, 16, 2),
    "real_enroque_locomotion_v5.webp": ("b551b67dde35cd1a7df7c6e1c67004ab8650ef22b750b610d8e78efc049f1529", 523484, 16, 3),
    "real_enroque_dribbles_v5.webp": ("d8a90faccd102db66afd1f2c19096738974b54a6f8ea3bb32f09136a7f218da3", 400878, 16, 2),
}


def probe(filename, expected):
    sha, expected_len, columns, rows = expected
    url = ROOT + filename
    result = {"file": filename, "url": url, "ok": False}
    request = urllib.request.Request(
        url, headers={"Origin": ORIGIN, "User-Agent": "Football-R2-V5-Verify/1"}
    )
    try:
        with urllib.request.urlopen(request, timeout=18) as response:
            body = response.read(4 * 1024 * 1024 + 1)
            status = response.status
            actual_url = response.url
            cors = response.headers.get("Access-Control-Allow-Origin", "")
            ctype = response.headers.get("Content-Type", "")
        actual_sha = hashlib.sha256(body).hexdigest()
        checks = {
            "http_200": status == 200,
            "no_redirect": actual_url == url,
            "sha256": actual_sha == sha,
            "length": len(body) == expected_len,
            "webp_signature": body[:4] == b"RIFF" and body[8:12] == b"WEBP",
            "cors": cors in ("*", ORIGIN),
            "max_4mb": len(body) <= 4 * 1024 * 1024,
        }
        result.update({
            "status": status, "bytes": len(body), "sha256": actual_sha,
            "cors": cors or "MISSING", "content_type": ctype, "checks": checks,
            "dimensions_expected": [columns * 128, rows * 144],
            "ok": all(checks.values()),
        })
    except urllib.error.HTTPError as error:
        result.update({"status": error.code, "error": "HTTP %d" % error.code})
    except Exception as error:
        result.update({"error": type(error).__name__ + ": " + str(error)[:220]})
    return result


def main():
    manifest = json.loads(MANIFEST.read_text())
    assert manifest["enabled"] is False, "This probe must not activate assets"
    assert manifest["cdn_base"] == ROOT.rstrip("/")
    entries = manifest["entries"]
    assert len(entries) == 4
    assert {e["file"] for e in entries} == set(EXPECTED)
    for entry in entries:
        filename = entry["file"]
        sha, count, cols, rows = EXPECTED[filename]
        assert (
            entry["sha256"] == sha and entry["bytes"] == count
            and entry["columns"] == cols and entry["rows"] == rows
        ), "Manifest mismatch for " + filename
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        reports = list(pool.map(lambda item: probe(*item), EXPECTED.items()))
    passed = all(row["ok"] for row in reports)
    summary = {"status": "verified" if passed else "blocked", "origin": ORIGIN, "files": reports}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(summary, indent=2) + "\n")
    print("FOOTBALL_V5_R2_PUBLIC_CHECK " + json.dumps(summary, sort_keys=True))
    if not passed:
        print("Public R2 objects not fully verified: leave V5 disabled.", file=sys.stderr)
        print("Check expected prefix 'atlases/v5/', NOT 'atlases/v/'.", file=sys.stderr)
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())

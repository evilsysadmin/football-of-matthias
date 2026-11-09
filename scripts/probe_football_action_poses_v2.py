#!/usr/bin/env python3
"""Probe unpublished v2 action art without pretending the old v1 is approved.

Only the separate, exact *_poses_v2.webp keys can become a future release.
A missing object means PENDING (not a fake QA success). Once an object exists,
invalid bytes/CORS/SHA are errors; neither state activates the runtime.
"""
import hashlib
import os
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

BASE = "https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v2"
STAGING_ORIGIN = "https://staging.football.shadowops.dpdns.org"
EXPECTED = {
    "fc_matthias_dribble_cut_poses_v2.webp": "0ebe3ed766f9adf90e3c8327315cbf53282bdb3e1d6dbceac1fa0e4e81cd8c93",
    "fc_matthias_dribble_burst_poses_v2.webp": "d516759fb53668d5fc02daf0581b8d61e1bddbb29b9725e9e4fa3edcd9729d9b",
    "fc_matthias_tackle_poses_v2.webp": "a3c50d36bc62104bb88e60e96da2134c99180bd4afe50dc7d92115271d08b18c",
    "fc_matthias_slide_tackle_poses_v2.webp": "21b1f297d52752977d20d7d6d4f2952c5158605922157bf1edb6a063fdd76071",
    "real_enroque_dribble_cut_poses_v2.webp": "6acec93d0e91c227c9367ba326330083a4d358b965f78b1df339d588353c37aa",
    "real_enroque_dribble_burst_poses_v2.webp": "2625c30ae31784008c3f2c665ec22ce79bfa664f663510ce5d463933c67f54b5",
    "real_enroque_tackle_poses_v2.webp": "1e64f42753f9a30d4361008abb99e6f71092d74dc85f05104a822ae9fa82fb77",
    "real_enroque_slide_tackle_poses_v2.webp": "819e008a135797e4d3fd901457f2433e08f94358bc43b8b3ef0f1ddc756ec564",
}


def webp_size(payload: bytes) -> tuple[int, int]:
    if (len(payload) < 25 or payload[:4] != b"RIFF"
            or payload[8:12] != b"WEBP" or payload[12:16] != b"VP8L"
            or payload[20] != 0x2f):
        raise ValueError("Not a lossless VP8L WebP")
    bits = int.from_bytes(payload[21:25], "little")
    return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1


def main() -> int:
    verified = []
    missing = []
    invalid = []
    for filename, sha in EXPECTED.items():
        request = Request(
            f"{BASE}/{filename}",
            headers={"Origin": STAGING_ORIGIN, "User-Agent": "Football-action-v2-candidate-probe"},
        )
        try:
            with urlopen(request, timeout=12) as response:
                status = response.status
                content_type = response.headers.get("Content-Type", "").lower()
                cors = response.headers.get("Access-Control-Allow-Origin", "")
                data = response.read(4_194_305)
            if (status != 200 or "image/webp" not in content_type
                    or cors not in ("*", STAGING_ORIGIN)
                    or len(data) > 4_194_304 or webp_size(data) != (1024, 144)
                    or hashlib.sha256(data).hexdigest() != sha):
                raise ValueError("HTTP 200 / WebP / staging CORS / geometry / SHA check failed")
            verified.append(filename)
            print(f"ACTION_POSES_V2_VERIFIED {filename} bytes={len(data)}")
        except HTTPError as exc:
            if exc.code == 404:
                missing.append(filename)
                print(f"ACTION_POSES_V2_PENDING {filename} HTTP=404")
            else:
                invalid.append(filename)
                print(f"ACTION_POSES_V2_INVALID {filename} HTTP={exc.code}", file=sys.stderr)
        except (URLError, TimeoutError) as exc:
            missing.append(filename)
            print(f"ACTION_POSES_V2_NOT_YET_VERIFIABLE {filename} reason={type(exc).__name__}")
        except ValueError as exc:
            invalid.append(filename)
            print(f"ACTION_POSES_V2_INVALID {filename} reason={exc}", file=sys.stderr)
    ready = not missing and not invalid and len(verified) == len(EXPECTED)
    message = f"ACTION_POSES_V2_STATUS ready={str(ready).lower()} verified={len(verified)}/8 pending={len(missing)} invalid={len(invalid)}"
    print(message)
    if output := os.getenv("GITHUB_OUTPUT"):
        with open(output, "a", encoding="utf-8") as handle:
            handle.write(f"ready={str(ready).lower()}\n")
    if summary := os.getenv("GITHUB_STEP_SUMMARY"):
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write("### Football v2 candidate art · real R2 publication\n\n")
            handle.write(message + "\n\n")
            if missing:
                handle.write("Missing or not verifiable: " + ", ".join(missing) + "\n\n")
            if invalid:
                handle.write("**REJECT** invalid: " + ", ".join(invalid) + "\n\n")
            handle.write("This probe **never enables** candidate artwork; inspect Godot renders and run the required gate before merge.\n")
    # If files are missing, the user still needs to publish them: do not
    # break every unrelated PR test or silently treat missing as approved.
    return 1 if invalid else 0


if __name__ == "__main__":
    raise SystemExit(main())

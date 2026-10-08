#!/usr/bin/env python3
"""Read-only local submission checks; does not sign, upload or contact Apple."""
import argparse
import datetime
import json
import pathlib
import plistlib
import subprocess
import urllib.parse


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[1]
    checks = []

    def check(name, passed, detail, blocked=False):
        checks.append({"name": name, "status": "pass" if passed else "blocked" if blocked else "fail", "detail": detail})

    with (args.app / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    check("iPhone target", info.get("UIDeviceFamily") == [1], str(info.get("UIDeviceFamily")))
    check("minimum deployment", info.get("MinimumOSVersion") == "18.0", str(info.get("MinimumOSVersion")))
    check("version and build", bool(info.get("CFBundleShortVersionString") and info.get("CFBundleVersion")),
          f"{info.get('CFBundleShortVersionString')} ({info.get('CFBundleVersion')})")
    check("encryption declaration", info.get("ITSAppUsesNonExemptEncryption") is False, "Non-exempt encryption = false")
    with (args.app / "PrivacyInfo.xcprivacy").open("rb") as handle:
        privacy = plistlib.load(handle)
    reasons = privacy.get("NSPrivacyAccessedAPITypes", [])
    defaults = [x for x in reasons if x.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryUserDefaults"]
    check("UserDefaults reason", any("CA92.1" in x.get("NSPrivacyAccessedAPITypeReasons", []) for x in defaults), "App-private preferences: CA92.1")
    check("privacy collection", privacy.get("NSPrivacyTracking") is False and not privacy.get("NSPrivacyCollectedDataTypes"), "No tracking or collected data declared")
    icon = (root / "StoreAssets/AppIcon/AppStore-Icon-1024.png").read_bytes()
    check("store icon", icon[:8] == b"\x89PNG\r\n\x1a\n" and int.from_bytes(icon[16:20], "big") == 1024 and
          int.from_bytes(icon[20:24], "big") == 1024 and icon[25] in (0, 2) and b"tRNS" not in icon,
          "1024 square PNG, no alpha/transparency")
    shots = list((root / "StoreAssets/Screenshots/zh-Hans/current-6.9-inch").glob("*.png"))
    valid_shots = len(shots) == 6
    for shot in shots:
        header = shot.read_bytes()
        valid_shots = valid_shots and header[:8] == b"\x89PNG\r\n\x1a\n" and header[25] == 2 and (
            int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big")) == (1320, 2868)
    check("current screenshots", valid_shots, "Six current 1320×2868 RGB screenshots; submission specifications still require final account review")
    binary = args.app / info["CFBundleExecutable"]
    strings = subprocess.run(["strings", str(binary)], capture_output=True, text=True, check=True).stdout
    check("release test entry points", "-uiTesting" not in strings, "UI-test launch switches absent from compiled executable")
    signature = subprocess.run(["codesign", "--verify", "--strict", str(args.app)], capture_output=True, text=True)
    check("distribution signature", signature.returncode == 0, "Signature verified" if signature.returncode == 0 else signature.stderr.strip(), blocked=True)
    submission = json.loads((root / "StoreAssets/submission.json").read_text())
    formal_id = submission.get("bundleIdentifier")
    check("registered identifier", bool(formal_id and formal_id == info.get("CFBundleIdentifier") and not formal_id.startswith("com.local.")),
          "Current: " + str(info.get("CFBundleIdentifier")) + "; requires issuance account registration", blocked=True)
    for key in ("supportURL", "privacyPolicyURL"):
        url = urllib.parse.urlparse(submission.get(key) or "")
        check(key, url.scheme == "https" and bool(url.hostname) and url.hostname != "example.com", "Provide a public HTTPS URL; reachability must be checked before submission", blocked=True)
    for key in ("copyright", "sku"):
        check(key, bool(submission.get(key)), "Requires issuance account information", blocked=True)
    status = "fail" if any(c["status"] == "fail" for c in checks) else "blocked" if any(c["status"] == "blocked" for c in checks) else "pass"
    report = {"generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(), "app": str(args.app.resolve()),
              "status": status, "checks": checks,
              "limits": "A signature check is not App Store Validate App. This check does not verify URL reachability, account registration, runtime accessibility, energy usage or approval."}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f"{status}: {sum(c['status'] == 'pass' for c in checks)}/{len(checks)} local checks pass; {args.output}")
    return 1 if status == "fail" else 2 if status == "blocked" else 0


if __name__ == "__main__":
    raise SystemExit(main())

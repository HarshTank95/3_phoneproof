# PhoneProof — Play Store Listing

Copy-paste content for the Google Play Console listing.

## App name (max 30 chars)
`PhoneProof: Used Phone Check` *(28)*

## Short description (max 80 chars)
`Forensic scanner for used phones: real battery, specs & authenticity checks.` *(76)*

## Full description (max 4000 chars)
```
Buying or selling a second-hand phone? PhoneProof is a forensic scanner that exposes the truth a seller can't fake — the real battery health, the real specs, and whether the device is genuine and untampered. Then it produces a clean, shareable Trust Certificate.

PhoneProof is built on one rule: it never shows a guessed value. Every number is either measured on your device or clearly marked "Not reported." No fluff, no fake confidence.

WHAT IT CHECKS

• Battery Truth — live temperature, voltage, charge level and health flags, plus a guided Capacity Test that MEASURES real mAh using the fuel-gauge charge counter (no root needed).

• Spec Truth (anti-spoof) — storage capacity is verified by writing and reading back real data (catches fake-capacity chips); storage speed, RAM, measured display resolution and refresh rate, true camera megapixels, hardware media decoders, Wi-Fi/Bluetooth generation, and a CPU/GPU benchmark — measured, not read off the "About phone" screen.

• Authenticity — hardware-backed key attestation reveals the verified-boot state and bootloader lock (cryptographic proof, not a guess), plus SELinux state, biometric hardware class, emulator/root heuristics and an optional Google device-integrity check.

• Cross-checks — an anomaly engine compares signals against each other to catch contradictions (e.g. an unlocked bootloader, a GPU that doesn't match the chip, a flagship SoC with sub-spec storage).

• Functional tests — guided touch, dead-pixel & OLED burn-in, speaker/earpiece/mic, vibration, flashlight, cameras, buttons, sensors and connectivity — each pass/fail.

• Trust Certificate — a 0–100 Trust Score with a transparent "why this score" breakdown, and a shareable, tamper-evident PDF/image certificate with a unique Report ID and SHA-256 QR.

PRIVACY FIRST
• Runs fully on-device. No account, no ads, no analytics, no tracking.
• Camera and microphone are used only for the interactive tests — nothing is ever recorded, saved or uploaded.
• No location permission. Reports leave your device only if YOU share them.

HONEST ABOUT LIMITS
Some values (true charge-cycle count, factory battery date, IMEI) are locked away by Android for third-party apps. PhoneProof tells you exactly when a value isn't available instead of making one up — because for a trust tool, honesty is the whole point.

Android-first. Perfect for buyers who want confidence before they pay, and sellers who want to prove their phone is genuine.
```

## Category
Tools *(alternative: Productivity)*

## Tags / keywords
used phone, refurbished, battery health, phone checker, device test, authenticity, anti-spoof, trust certificate

## Content rating
**Everyone.** No user-generated content, no ads, no data collection, no sensitive content. (Complete the IARC questionnaire answering "No" to all data-collection / ads / UGC prompts.)

## Data safety form (Play Console → Data safety)
- **Does your app collect or share any user data?** → **No.**
- Data processed (camera/mic) is used ephemerally on-device for functional tests, not collected or transmitted → no declaration required beyond "No data collected."
- Security practices: Data is not transmitted off the device; user can request deletion by uninstalling (no data retained).

## Privacy Policy URL
Host `docs/PRIVACY_POLICY.md` publicly (e.g. GitHub Pages / raw GitHub / a gist) and paste the URL here. Example raw URL:
`https://raw.githubusercontent.com/HarshTank95/3_phoneproof/main/docs/PRIVACY_POLICY.md`
*(A rendered page is preferred over raw — GitHub Pages or a simple hosted HTML.)*

## Release notes (What's new — v1.0.0)
```
First release of PhoneProof.
• Measured battery Capacity Test (real mAh, no root)
• Hardware-attested verified-boot & bootloader checks
• Anti-spoof spec verification and camera/codec truth
• Cross-signal anomaly detection
• Shareable, tamper-evident Trust Certificate
Runs fully on-device. No ads, no accounts, no tracking.
```

## Graphic assets still needed (create in Play Console / any editor)
- **App icon** 512×512 (already have the in-app adaptive icon — export a 512 PNG).
- **Feature graphic** 1024×500 (required).
- **Phone screenshots** — min 2, recommend 4–8 (landing, scan animation, reveal gauge, full report, capacity test, certificate). Capture on the device at 1080×2400.

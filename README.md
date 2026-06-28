# PhoneProof

**A forensic scanner for second-hand phones.** PhoneProof answers the two questions nobody can currently answer when buying a used phone: *“Is this phone genuine?”* and *“Is the seller lying about its age and condition?”*

It reads a phone’s **real** age, **real** battery wear, and **real** specs — data that fakes and lying sellers can’t easily spoof — then produces a beautiful, shareable **Trust Certificate**.

> Android-first. Flutter UI + native Kotlin. Built to be honest: it never presents an unavailable value as if it were measured.

---

## Why it’s different

The store is full of phone *testers* (“does the speaker work / are there dead pixels”) that trust whatever the phone reports. PhoneProof is a **fraud / truth detector**:

1. **Real age from tamper-proof hardware** — battery cycle count, state of health, and manufacturing date live in the fuel-gauge chip’s protected memory and resist software spoofing. We surface *claimed vs real*.
2. **Anti-spoof spec verification** — we *measure* storage, RAM, resolution, sensors, and CPU instead of trusting the “About Phone” screen.
3. **Certified-genuine check** — Play Integrity’s hardware-backed device verdict (optional backend).
4. **A shareable Trust Certificate** — buyers verify, sellers prove.

## Features

- **Battery Truth** — state of health, charge cycles, real mAh, manufacturing/first-use date (where exposed), legacy health, live temperature/voltage/charge level/charging state, technology — each clearly labelled when a device doesn’t expose it.
- **Spec Truth / anti-spoof** — storage write-verify (sampled, never fills the disk) + speed benchmark, measured display resolution/refresh, full sensor inventory, CPU/SoC info + benchmark, RAM + virtual-RAM (zRAM) detection, build/emulator/root heuristics.
- **Authenticity** — on-device emulator + root heuristics, and a Play Integrity “certified genuine” badge (degrades to *Not checked* when no backend is configured).
- **Functional quick-tests** — touch grid, dead-pixel, speaker/earpiece/mic, vibration, flashlight, cameras, buttons, live sensors, connectivity — each PASS / FAIL / SKIPPED.
- **Trust Score (0–100)** with a transparent *“why this score”* breakdown, a **Claimed-vs-Real** reveal, and a polished **Trust Certificate** (PDF + image) with a unique Report ID and a SHA-256 QR for tamper-evidence.

## Honesty matrix

| Capability | Access level |
|---|---|
| Cycle count*, legacy health, temp/voltage/level, RAM total, storage size, sensor list, display metrics, CPU info, thermal status, functional tests, storage write/speed tests, emulator/root heuristics | Free, no special permission |
| SoH %*, manufacturing/first-use date, real mAh (`charge_full`) | Privileged (Shizuku / root / “Box-Ready” Android 15+) |
| “Certified genuine device” verdict | Play Integrity + a free serverless backend |
| IMEI read | **Not possible** for third-party apps on Android 10+ — manual `*#06#` only |

\* Some OEMs gate cycle count / SoH behind the privileged `BATTERY_STATS` permission and return nothing to normal apps. PhoneProof detects this and shows the value as unavailable with an explanation — it never fabricates a number.

## Tech

- **Flutter** (Material 3, Dart 3+) for UI, orchestration, scoring, and the certificate.
- **Kotlin platform channel** (`phoneproof/native`) for BatteryManager properties, thermal status, precise display metrics, full sensor enumeration, `/proc` mem/cpu, per-core frequencies, storage write-verify + benchmark, and emulator/root heuristics.
- Dark, glassmorphism UI with a signature scan-line animation, a count-up Trust Score gauge, and reduced-motion support.

## Getting started

```bash
flutter pub get
flutter run            # debug, on a connected Android device
flutter build apk --release
```

Requires Flutter (stable) and an Android device/emulator (minSdk 24, target 35).

### Optional: enable the “Certified genuine” badge
Configure a free serverless verifier and your Google Cloud project number in
`lib/features/authenticity/play_integrity.dart`. Until then the badge shows *Not checked*.

## Status

Compiles cleanly (`flutter analyze`), builds release APKs, and is verified end-to-end on a physical Android device.

## Out of scope

iOS (Apple doesn’t expose this data), accounts/cloud history, ads, resale-value estimates, and IMEI auto-reading (impossible on modern Android).

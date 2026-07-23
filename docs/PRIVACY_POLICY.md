# PhoneProof — Privacy Policy

**Last updated:** 23 July 2026

PhoneProof is an on-device forensic scanner for second-hand phones. This policy explains, plainly, what the app does and does not do with your data.

## The short version
**PhoneProof does not collect, transmit, sell, or share any personal data.** Everything the app reads is processed **on your device** and stays there unless *you* choose to share a report.

There are **no accounts, no ads, no analytics, and no tracking SDKs.**

## What the app reads (and why)
To assess a phone, PhoneProof reads hardware and system information **locally**, including:

- Battery data (level, temperature, voltage, charge counter, health flags)
- Device specifications (display, sensors, RAM, CPU/GPU, storage, media codecs)
- Authenticity signals (verified-boot / bootloader state via Android key attestation, SELinux state, emulator/root heuristics, kernel version, uptime)
- Radio capability (Wi-Fi / Bluetooth generation)
- Results of interactive hardware tests you run (touch, screen, camera, speaker/mic, vibration, flashlight, sensors)

This information is used **only** to generate your on-screen report and Trust Certificate. It is **not uploaded anywhere.**

## Permissions
- **Camera** — used only during the interactive camera test. No photo or video is saved or transmitted.
- **Microphone** — used only during the interactive speaker/mic test. No audio is recorded, saved, or transmitted.
- **Nearby devices / Bluetooth, Wi-Fi state** — used only to read radio *capabilities* (e.g. "Wi-Fi 6", "Bluetooth 5"). PhoneProof does **not** scan for, connect to, or track nearby devices, and does **not** request location.
- **Vibration** — used only for the haptics test and UI feedback.
- **Internet** — reserved for an **optional** Google Play Integrity check, which is **off by default** and sends no personal data. If never enabled, the app makes no network calls.

PhoneProof does **not** request location, contacts, phone identifiers (IMEI/serial), storage of your files, or any background access.

## Data storage and sharing
- Reports and the Trust Certificate are generated in memory. A certificate is only written to a file (PDF/image) **when you tap Share**, and it is sent through your device's own share sheet to the app you pick. PhoneProof has no server and receives no copy.
- Nothing is stored in the cloud. Uninstalling the app removes everything.

## Children
PhoneProof is a utility tool and is not directed at children. It collects no data from anyone.

## Changes to this policy
If this policy changes, the updated version will be posted at the same URL and the "Last updated" date will change.

## Contact
Questions about this policy: **tankharsh9510@gmail.com**

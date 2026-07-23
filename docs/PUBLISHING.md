# PhoneProof — Publishing Guide

## ⚠️ Back up the signing key FIRST
The release build is signed with an **upload keystore**. If you lose it, you can **never update the app** on Play again.

**Files to back up somewhere safe & private (NOT in git):**
- `android/upload-keystore.jks`
- `android/key.properties` (contains the passwords)

Both are git-ignored. Store copies in a password manager / private cloud.

**Upload key fingerprints (for your records):**
- Alias: `upload`
- SHA-1: `B2:56:B3:AA:9F:DA:4A:0D:F4:A5:23:29:65:68:D7:E3:DA:77:AE:27`
- SHA-256: `2F:6E:46:D2:7C:2E:FC:C0:B2:70:B6:FC:3B:AB:65:33:FE:60:41:3F:92:64:25:AE:16:2F:0C:50:48:6D:4A:18`
- Valid until: 2053

> Recommended: enable **Play App Signing** (default for new apps). Google then holds the app-signing key and your keystore above is only the *upload* key — safer, and re-issuable if lost (via support) once Play App Signing is on.

## Build the release App Bundle
```powershell
flutter clean
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

The bundle is signed automatically because `android/key.properties` is present. (On a machine without it, the build falls back to the debug key so it still compiles.)

## App facts
- **Package / applicationId:** `com.phoneproof.phoneproof`
- **Version:** 1.0.0 (versionCode 1) — set in `pubspec.yaml` (`version: 1.0.0+1`)
- **minSdk 24 · targetSdk 35 · compileSdk 36**

## Play Console checklist
1. Create app → name **PhoneProof: Used Phone Check**, Free, App (not game).
2. **App content:**
   - Privacy policy URL (host `docs/PRIVACY_POLICY.md` — see STORE_LISTING.md).
   - Data safety → **No data collected / shared**.
   - Ads → **No ads**.
   - Content rating → complete IARC → **Everyone**.
   - Target audience → 18+ / general (not designed for children).
   - Permissions: no sensitive/restricted permissions are used, so no declaration form is required (location, SMS, call-log, IMEI are all NOT used).
3. **Store listing:** paste name / short / full description + release notes from STORE_LISTING.md. Upload icon (512), feature graphic (1024×500), and 4–8 screenshots.
4. **Production → Create release → upload `app-release.aab`** → paste release notes → roll out (start with a Closed/Internal test track first if you want a soft launch).

## Updating later
Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2` — the `+N` build number must increase every upload), then rebuild the AAB with the same keystore.

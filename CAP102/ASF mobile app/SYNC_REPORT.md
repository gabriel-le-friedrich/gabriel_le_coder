# Live vs. Local Sync Report — ASF Mobile App

Date: 2026-07-12 · Live reference: https://asf-app-2990c.web.app

## Key finding: the live app is not a separate design — it's an older deployment of this same project

I fetched the live app and compared its rendered content line-by-line against
local `index.html`. Structurally and visually they're the same
application — same sections, same copy, same flows (Dashboard, Daily
Activities, Feeding Guide, Health Monitor, Weight & ADG, Expense & ROI,
Contacts, Calendar, Settings, Pig Growth, and the full auth flow). That's
expected: the live site is Firebase Hosting serving a build of this exact
codebase from an earlier point in time, not an independently designed
reference.

That means there's no visual/animation/interaction gap to reverse-engineer —
the CSS, transitions, and JS behavior are already identical because it's the
same source. **The one real difference I found is that live is behind, not
different:** the live auth Welcome screen still reads `PASU · Magalang,
Pampanga · 2026`, the exact typo you had me fix locally last session (→
`PSAU`). Local already has that fix, along with the Health Monitor changes
from the same session (removed "Sleeping More Than Usual," updated the eye
condition labels). I did not revert any of those — copying live's stale
`PASU` back into local would have undone work you explicitly asked for.

**Recommendation:** once you can run `firebase deploy` from your machine
(see Manual Steps below), deploy local → live to bring the live site current.
Going the other direction would move your branding and Health Monitor fixes
backward.

## Issues found this session

| # | File | Issue | Severity |
|---|---|---|---|
| 1 | `android/app/build.gradle` | Release keystore `storePassword`/`keyPassword` (`ASFSwine2024!`) were hardcoded in plaintext directly in a tracked build file, and `android/.gitignore`'s `*.jks`/`*.keystore` exclusion lines were commented out — meaning both the password *and* the actual keystore file (`asf-release.jks`, confirmed present at `android/app/asf-release.jks`) were one `git add .` away from being permanently committed. | Real security issue — fixed |
| 2 | Live deployment | Live site is running an older build (still shows `PASU`, likely predates the Health Monitor label changes too, since those are also part of the same session's fixes). | Not a bug, but flagged so you don't mistake it for a local regression |

Everything else audited this session — Firebase config, Firestore/Storage
rules, the Android manifest permissions and Gradle plugin setup, translation
key integrity, build output — was already correct from the last two audit
passes and required no further changes. I re-verified all of it rather than
assuming it still held:

- `index.html`: 0 occurrences of `PASU`, 503/503 EN↔FIL translation key
  parity, 0 duplicate keys, 0 stray null bytes.
- Clean install + build in an isolated environment: `npm install` → 183
  packages, `npm run build` → 30 modules transformed, 0 errors, 0 warnings.
- `AndroidManifest.xml`: `INTERNET`, `CAMERA`, `READ_MEDIA_IMAGES`,
  `READ_EXTERNAL_STORAGE` (API ≤32) all present and correctly scoped for the
  pig-photo capture/upload flow.
- `android/build.gradle` + `android/app/build.gradle`: single, correct
  `plugins{}` block for Google Services (no duplicate/malformed classpath),
  `google-services.json` present and consistent with `capacitor.config.json`.
- Firebase Auth/Firestore/Storage initialization in `src/auth-main.js`: real
  calls throughout, zero prototype/mock auth code anywhere in the codebase.

## Changes made this session

1. **Created `android/keystore.properties`** holding the real signing
   credentials (moved out of `build.gradle`).
2. **Edited `android/app/build.gradle`** to load signing config from that
   properties file at build time, with a safe fallback (release builds
   fall back to unsigned rather than failing if the file's ever missing) —
   the credentials themselves no longer appear in the build script.
3. **Edited `android/.gitignore`** to actually exclude `*.jks`, `*.keystore`,
   and `keystore.properties` (previously present but commented out).
4. Re-ran the full verification suite (translation parity, null-byte check,
   clean install + build) to confirm nothing regressed from the other
   session's edits to `AndroidManifest.xml`, `build.gradle`, and
   `AUDIT_REPORT.md`.

No UI, animation, or design changes were made — none were needed, since
local and live share the same source and the only functional gap was the
stale deployment, not a code difference.

## Deployment Status

| Target | Status |
|---|---|
| **Web** | Build is clean and ready. Not yet redeployed to Hosting — live still serves the pre-branding-fix version. One command from your machine (`firebase deploy`) brings it current. |
| **Android** | Code, Gradle config, manifest permissions, and signing setup are all correct and now properly secured. Still needs: SHA-1/SHA-256 fingerprints added in the Firebase Console, and an actual Android Studio build to produce the signed APK/AAB — both need tools this sandbox doesn't have (see below). |
| **iOS** | Project is scaffolded (`ios/App`) with both Capacitor plugins registered. Needs `GoogleService-Info.plist` from the Firebase Console and a Mac with Xcode to build. |

## Manual Steps Required (and why)

| Step | Why it can't be automated here |
|---|---|
| `firebase login` + `firebase deploy` (Hosting, and rules if not already deployed) | This sandbox's network allowlist blocks every Google/Firebase API domain outright (confirmed by direct test: `firebase.googleapis.com`, `accounts.google.com` → `403 blocked-by-allowlist`). Not a login issue — the network path itself is closed. Must run from your machine. |
| `cd android && ./gradlew signingReport` for SHA-1/SHA-256, then add them in Firebase Console → Project Settings → your Android app | Requires downloading the Gradle distribution and Android SDK; `services.gradle.org` and `dl.google.com` are both blocked the same way. |
| Register an iOS app in Firebase Console (bundle ID `ph.edu.psau.asf`) and download `GoogleService-Info.plist` into `ios/App/App/` | Firebase only generates this file after Console registration — nothing to compute locally. |
| Actual Android APK/AAB build (Android Studio or `./gradlew assembleRelease`/`bundleRelease`) | Needs the Android SDK, blocked as above. Code side is ready. |
| Actual iOS build | Needs a Mac + Xcode — an Apple platform restriction, not something any sandbox can work around. |

## Verification: the app builds and runs

```
npm install   →  183 packages, 0 errors
npm run build →  30 modules transformed, 0 errors, 0 warnings
npm run dev   →  HTTP 200
```

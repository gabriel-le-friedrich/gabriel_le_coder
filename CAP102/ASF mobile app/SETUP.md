# ASF — Firebase + Native App Setup Guide

This turns the ASF prototype into a real, installable Android/iOS app backed
by Firebase Authentication (Phone + Email/Password) and Cloud Firestore.

**Project status: your real Firebase project (`asf-app-2990c`) is already
created and its config is already pasted into `src/firebase-config.js`.**
Everything below reflects what's done vs. what's left for that specific
project — not a generic "create a project from scratch" guide anymore.

**What's already done for you (code):** every Firebase Auth call, error
handling, Firestore reads/writes for `users`/`phoneIndex`, AND a
write-through sync layer that mirrors the app's existing local data (pigs,
health logs, feeding logs, expenses, growth/weight logs) into
`pigs`/`healthLogs`/`feedingLogs`/`expenses`/`growthLogs` under
`users/{uid}/...` automatically in the background, plus Firebase Storage
upload for the farmer's profile photo and pig weekly growth photos.
Security rules for Firestore (`firestore.rules`) and Storage
(`storage.rules`) are written and cover every collection.

**What I could not do from here, and why:** this sandbox's network
allowlist blocks every Google/Firebase API domain outright (confirmed —
`firebase.googleapis.com`, `firestore.googleapis.com`,
`accounts.google.com`, `firebasestorage.googleapis.com` all return
`403 blocked-by-allowlist`). That means I can't run `firebase login`,
`firebase deploy`, or anything else that talks to your actual project from
this environment — not even with a CI token, since the network path itself
is closed, not just the login step. This is a constraint of *my* sandbox
only; the app itself (running on your phone, or in your own browser) has
normal internet access and works fine. The one remaining step — deploying
`firestore.rules` / `storage.rules` — needs to run on your machine. It's
three copy-pasteable commands, see §4.

---

## 0. One-time file rename

The working file was edited in place as `index.html.html` (a quirk of how it
kept getting re-saved). Vite/Capacitor expect the entry file to be named
exactly `index.html`. Before step 3, rename it:

```
index.html.html  →  index.html
```

---

## 1. Prerequisites

- Node.js 18+ and npm (already required to run anything here)
- Your Google account that owns the `asf-app-2990c` Firebase project
- For Android: [Android Studio](https://developer.android.com/studio) (bundles the Android SDK + a working Gradle)
- For iOS: a Mac with [Xcode](https://apps.apple.com/app/xcode/id497799835) (there is no way to build an iOS app without a Mac — Apple doesn't allow it)
- The [Firebase CLI](https://firebase.google.com/docs/cli): `npm install -g firebase-tools`

---

## 2. Firebase Console setup for `asf-app-2990c`

The project and its web config already exist — this is just enabling the
pieces of it your account has to click through (Console-only, no CLI/API
equivalent I could run for you).

Go to <https://console.firebase.google.com/project/asf-app-2990c>.

### Enable sign-in providers

**Authentication → Sign-in method:**
- Enable **Phone**.
- Enable **Email/Password**.

### Add test phone numbers (do this before real-device testing)

Still in Authentication → Sign-in method → Phone → **Phone numbers for
testing**: add a few, e.g. `+63 917 000 0001` with a fixed code like
`123456`. Signing in with a test number never sends a real SMS and never
counts against your quota — use these for all development.

### Enable Firestore

**Build → Firestore Database → Create database** (start in production
mode — the rules in this project already lock it down properly).

### Enable Storage

**Build → Storage → Get started** (also start in production mode — this
project's `storage.rules` already restricts every file to its owning uid).
Used for the farmer's profile photo and pig weekly growth photos.

---

## 3. Install dependencies

```
npm install
```

If you see a version-resolution error for any single package, run
`npm view <package-name> versions` and bump that one line in `package.json`
— Capacitor/Firebase ship new versions often.

---

## 4. Deploy security rules

One-time CLI login, then deploy Firestore's rules/indexes AND Storage's
rules together (there's an `npm run deploy:rules` shortcut for the last
line once you've done the first two):

```
firebase login
firebase use --add          # pick asf-app-2990c
npm run deploy:rules        # = firebase deploy --only firestore:rules,firestore:indexes,storage
```

The rules (`firestore.rules`) restrict every document to its owning user's
uid — see the comments in that file for the exact data model
(`users/{uid}`, `users/{uid}/pigs/{pigId}`, `.../healthLogs/{id}`, etc., plus
a `phoneIndex/{e164Number}` collection used only to check "is this phone
number already registered" during sign-up without exposing other users'
data).

---

## 5. Test in a regular browser first (fastest feedback loop)

```
npm run build
npm run dev
```

Open the printed `localhost` URL. Phone Authentication's underlying native
plugin falls back to the Firebase Web SDK's reCAPTCHA flow when running in a
plain browser (not inside a native shell) — this is enough to sanity-check
Email/Password registration, login, and Firestore reads/writes before
touching Android Studio at all. **Add `localhost` to Authentication →
Settings → Authorized domains** if phone sign-in doesn't trigger the SMS
here.

---

## 6. Android

```
npm run add:android
```

This creates an `android/` folder (a real Android Studio project).

1. **Register the Android app in Firebase:** Project settings → Add app →
   Android. Application ID: `ph.edu.psau.asf` (matches `capacitor.config.json`
   — change both together if you rename it).
2. Download the generated **`google-services.json`** and place it at
   `android/app/google-services.json`.
3. **SHA-1 / SHA-256 fingerprints — required for Phone Auth to work on
   Android.** Without this, phone verification silently falls back to a
   reCAPTCHA web view instead of the smooth native flow. Get your debug
   fingerprint:
   ```
   cd android && ./gradlew signingReport
   ```
   Copy the `SHA1` and `SHA256` values under the `debug` variant into
   Firebase → Project settings → your Android app → **Add fingerprint**.
   Repeat with your **release** keystore's fingerprint before publishing.
4. Open in Android Studio:
   ```
   npm run open:android
   ```
5. Let Android Studio finish its Gradle sync (first run downloads the SDK
   platform + build tools — this needs unrestricted internet access to
   `dl.google.com` and `services.gradle.org`).
6. Run on an emulator or a plugged-in device via the ▶ button, or
   **Build → Generate Signed Bundle/APK** for a real release build.

> **Note on what I could and couldn't do for you:** I scaffolded and
> verified the Android project structure from a Linux sandbox
> (`npx cap add android` completed cleanly and correctly registered both
> Capacitor plugins), but actually compiling it requires downloading the
> Gradle distribution and Android SDK — both blocked by this sandbox's
> network allowlist (`services.gradle.org` and `dl.google.com` aren't
> reachable from here). That part has to happen in Android Studio, on your
> machine, with normal internet access.

---

## 7. iOS

```
npm run add:ios
```

1. **Register the iOS app in Firebase:** Project settings → Add app → iOS.
   Bundle ID: `ph.edu.psau.asf`.
2. Download **`GoogleService-Info.plist`** and drag it into the `App`
   target in Xcode (open via `npm run open:ios`), making sure "Copy items
   if needed" is checked.
3. **APNs — required for Phone Auth on iOS.** Firebase Phone Auth on iOS
   uses a silent push notification to verify the app isn't a bot, instead of
   a visible reCAPTCHA. In the Apple Developer portal, create an APNs
   authentication key (or certificate) and upload it under Firebase →
   Project settings → Cloud Messaging → your iOS app. Also enable the **Push
   Notifications** and **Background Modes → Remote notifications**
   capabilities in Xcode's Signing & Capabilities tab.
4. Set your Team/signing certificate in Xcode, then Build & Run on a
   simulator or device.

> iOS builds can only happen on a Mac — there is no workaround for this,
> it's an Apple platform restriction, not a tooling limitation.

---

## 8. What each part of the code does

| File | Purpose |
|---|---|
| `index.html` | The whole app UI (unchanged from the prototype) plus the classic `<script>` with a small "bridge" (`window.DB`, `window.ck`, `window.setCurrentUid`) that `src/auth-main.js` uses to hydrate the rest of the app once a user is signed in. |
| `src/firebase-config.js` | Your real `asf-app-2990c` project config. |
| `src/auth-main.js` | Every real Firebase Auth + Firestore call: registration, phone OTP send/verify, email/password login, "Continue with Mobile Number" login, forgot-password email, logout, session persistence, Firebase-error-code → user-facing-message mapping, **plus** the write-through sync layer that mirrors `window.DB.set()` writes into `users/{uid}/{pigs,healthLogs,feedingLogs,expenses,growthLogs}` and uploads profile/pig photos to Storage. |
| `firestore.rules` | Per-user data isolation for every Firestore collection — see the header comment inside for the full data model. |
| `storage.rules` | Per-user data isolation for uploaded photos (`users/{uid}/photos/...`). |
| `capacitor.config.json` | App ID, name, and the `FirebaseAuthentication` plugin config. |

---

## 9. Manual testing checklist

Run through this on a real device (or emulator with Google Play services)
using your Firebase test phone numbers first, then a real number:

- [ ] **Register** with a new email + a test phone number → receive the
      code → verify → lands on Dashboard → check Firestore Console:
      `users/{uid}` document exists with all fields, and
      `phoneIndex/{+63...}` exists too.
- [ ] **Register again with the same phone number** → should be rejected
      with "already registered" and redirected to Log In, *without*
      creating a second Firebase Auth user (check the Authentication tab's
      user count).
- [ ] **Log in** with the email/password from the first test → lands on
      Dashboard, Firestore profile restored (farmer name, etc. match what
      you registered).
- [ ] **Log out** (Settings → Log Out) → returns to Welcome screen.
- [ ] **Continue with Mobile Number** on the Login screen using the same
      registered number → OTP → signs into the *same* account (same uid,
      same data) rather than creating a new one.
- [ ] **Wrong OTP**: enter 6 random digits → clear "incorrect code" message,
      stays on the Verify screen.
- [ ] **Expired OTP**: wait past Firebase's code expiry window before
      confirming → "code expired" message, Resend re-sends.
- [ ] **Forgot Password**: enter the registered email → check inbox for a
      real Firebase password-reset email → link works.
- [ ] **Restart the app** after logging in (force-quit and reopen, or
      reload the browser tab) → goes straight to Dashboard, no login
      prompt.
- [ ] **Too many attempts**: trigger several OTP sends quickly → Firebase's
      `auth/too-many-requests` surfaces as a friendly rate-limit message.
- [ ] **Airplane mode**: attempt any auth action offline → friendly network
      error message, not a raw crash/blank screen.
- [ ] **Data sync**: add a pig, an expense, a health log entry, and a feed
      log entry in the app → check Firestore Console under
      `users/{uid}/pigs`, `expenses`, `healthLogs`, `feedingLogs` → each
      shows a document with your data (written a few seconds after the
      local save, not instantly — it's a background mirror).
- [ ] **Photo upload**: set a profile photo and a pig weekly photo → check
      Storage Console under `users/{uid}/photos/` → the files appear there,
      and the corresponding Firestore document's photo field holds a
      `https://firebasestorage.googleapis.com/...` URL, not a huge base64
      string.
- [ ] **Critical health alert**: log a health observation that resolves to
      🔴 Critical → check Firestore under `users/{uid}/notifications` → a
      new document appears.
- [ ] **New device / reinstall**: log into the same account from a second
      device or a fresh browser profile → the pigs/health/expense data you
      created above shows up, not the original demo seed.

---

## 10. If something doesn't match

`@capacitor-firebase/authentication`'s exact method names (particularly
`linkWithEmailAndPassword`, used right after phone verification during
Registration to attach a password to the phone-verified account — see the
comment above that call in `src/auth-main.js`) can shift between major
versions. If registration errors out specifically at that step, check
`node_modules/@capacitor-firebase/authentication/dist/esm/definitions.d.ts`
(or the package's README on npm) for the current method name/signature
against whatever version `npm install` actually resolved, and adjust that
one call.

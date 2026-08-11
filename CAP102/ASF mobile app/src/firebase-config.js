/* ══════════════════════════════════════════════════════════════════════
   FIREBASE CONFIG — already populated with this app's real Firebase
   project (asf-app-2990c, matching android/app/google-services.json).
   isFirebaseConfigured() below only ever flags this as unconfigured if a
   value still literally starts with "REPLACE_WITH_" — kept as a guard for
   anyone forking this project with their own Firebase project, not
   because these values are placeholders today.

   Where to get these values (for a fresh/forked project):
     1. https://console.firebase.google.com → Create a project (or use an
        existing one).
     2. Project settings (⚙️ icon) → General → "Your apps" → Add app → Web
        (</>) — even though this ends up in a native app via Capacitor, the
        Firebase JS SDK still uses a "Web app" config object.
     3. Copy the firebaseConfig object Firebase shows you and paste the
        values in below.
     4. In Authentication → Sign-in method, enable:
          - Phone
          - Email/Password
     5. In Authentication → Sign-in method → Phone → "Phone numbers for
        testing" — add a few test numbers + fixed codes so you (and app
        reviewers) can test without burning real SMS quota.

   Full walkthrough: see SETUP.md in the project root.
   ══════════════════════════════════════════════════════════════════════ */

export const firebaseConfig = {
  apiKey: "AIzaSyAGmI2yoguQ6QOgaMkb3ssUNrtDmCtAd8Y",
  authDomain: "asf-app-2990c.firebaseapp.com",
  projectId: "asf-app-2990c",
  storageBucket: "asf-app-2990c.firebasestorage.app",
  messagingSenderId: "661869403000",
  appId: "1:661869403000:web:abff7f1d5cf889746e068d"
};

export function isFirebaseConfigured() {
  return !Object.values(firebaseConfig).some(
    v => typeof v === 'string' && v.startsWith('REPLACE_WITH_')
  );
}

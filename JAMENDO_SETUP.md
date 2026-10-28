# Jamendo setup (one time, 2 minutes)

Jamendo is the source of full, legal Creative Commons tracks. It needs a free
Client ID. Get it once and the app never asks for it again.

## 1. Get the Client ID

1. Open https://devportal.jamendo.com and sign up (username, email, password,
   organisation name, country).
2. Log in, go to **My Apps** and click **Create an Application**.
3. Give it any name (e.g. `TuneHive`), fill the short description, save.
4. Copy the **Client ID** — a short string like `709fa152`.
   Do **not** copy the Client Secret; the read API only needs the Client ID.

## 2. Put it into the build (pick one)

**A. GitHub secret (recommended — no code change)**

Repository → Settings → Secrets and variables → Actions → New repository
secret → name `JAMENDO_CLIENT_ID`, value = your Client ID. Every APK built
after that already has it inside.

**B. Hardcode it in the code**

Open `lib/config.dart` and paste it:

```dart
const String kJamendoClientId = '709fa152';
```

**C. Type it in the app**

Profile → Jamendo API key → paste → Save. Works instantly, but every user
would have to do it, so use A or B for a release.

## 3. Check it

Open the app with internet: Home should show **Trending Today** and
**New & Rising** with real tracks. Profile → Jamendo API key should read
"Build me set hai".

## Notes

- The read-only plan is enough for TuneHive and is free.
- Jamendo allows 500,000 API hits; contact api@jamendo.com if you expect more.
- Tracks are Creative Commons: the artist keeps the rights, so credit stays
  visible (artist name is shown everywhere in the app).

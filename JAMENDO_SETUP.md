# Jamendo setup (optional)

**The app works without Jamendo.** Out of the box the online section uses
Audius (full tracks, no account), Deezer and Apple Music (official 30 second
previews, no account) and the Internet Archive (Creative Commons).

Jamendo is only worth adding if you want full-length Creative Commons tracks.
It needs a free Client ID, and the Jamendo portal sometimes refuses logins —
so treat it as a bonus, not a requirement.

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

## If the Jamendo portal will not let you in

Skip it. Everything below still works with no key at all:

| Source | Account needed | What you get |
| --- | --- | --- |
| Audius | none | full tracks, trending, search |
| Deezer | none | 30s official previews, latest Indian songs |
| Apple Music (iTunes Search) | none | 30s official previews, India store |
| Internet Archive | none | full Creative Commons tracks |
| Jamendo | free Client ID | full Creative Commons tracks |

## Notes

- The read-only plan is enough for TuneHive and is free.
- Jamendo allows 500,000 API hits; contact api@jamendo.com if you expect more.
- Tracks are Creative Commons: the artist keeps the rights, so credit stays
  visible (artist name is shown everywhere in the app).

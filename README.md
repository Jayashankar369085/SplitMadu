# SplitMadu 🇮🇳

**Eshtu aaytu? — split it, settle it, done.**

SplitMadu is a Flutter + Firebase expense-sharing app (Splitwise-style) with
Bengaluru-inspired branding. Built with Material 3, clean architecture and a
derived (never-stored) balance engine.

## Tech stack

- Flutter 3.44 / Dart 3.12
- Firebase Authentication (Email + Password)
- Cloud Firestore (no Realtime Database)
- provider for state management
- Material 3 with a custom indigo/coral/lavender theme

## Project structure

```
lib/
├── core/
│   ├── constants/app_constants.dart   # collections, categories, limits
│   ├── theme/app_theme.dart           # Material 3 theme, palette
│   └── utils/                         # error mapper, money utils, formatters
├── models/                            # user, friendship, expense, settlement
├── repositories/                      # auth, user, friendship, expense, settlement
├── services/
│   ├── balance_service.dart           # pure-Dart balance engine + smart settlement
│   └── user_cache.dart                # shared UID → profile cache
├── providers/                         # AuthProvider, FriendsProvider, ExpensesProvider
├── screens/
│   ├── splash/  auth/  home/  friends/  expenses/  settlements/  profile/
├── widgets/                           # balance card, tiles, buttons, avatars…
├── firebase_options.dart              # Dart-first Firebase config (splitmadu-app)
└── main.dart
```

## Firestore data model

```
users/{uid}          name, email, photoUrl, createdAt, nameSearch
friendships/{id}     user1, user2 (canonical order user1 < user2), status, createdAt
                     doc id = "{uidA}_{uidB}" → duplicate-proof
expenses/{id}        title, amount, category, paidBy, createdBy,
                     participants {uid: share}, participantIds [uid], createdAt
settlements/{id}     from, to, amount, createdBy, createdAt
```

- Balances are **never stored** — they are derived on-device from
  `expenses + settlements → BalanceService → balances`.
- `participantIds` is an array mirror of the participants map keys, enabling
  `arrayContains` queries with a composite index (`firestore.indexes.json`).

## Security rules

Production rules live in `firestore.rules` and are deployed to the project.
Summary: everything requires auth; profiles are readable for user search but
writable only by their owner; expenses/settlements are participant-scoped;
expenses are immutable history (settlements adjust balances); friendship docs
are immutable and validated for canonical pair order.

## One-time manual step (required)

Email/Password sign-in could not be enabled via CLI on this project (the
Identity Toolkit config was never materialized server-side and the API
alternative requires billing). Enable it once:

1. Open https://console.firebase.google.com/project/splitmadu-app/authentication
2. Click **Get started** (if prompted).
3. **Sign-in method → Email/Password → Enable → Save.**

No other console setup is required — Firestore, rules, and indexes are already
deployed.

## Run

```bash
flutter pub get

# Chrome (fastest way to try it)
flutter run -d chrome

# Android
flutter run -d android        # or: flutter build apk --release
```

Note: anonymous profiles won't see each other's data unless they add each
other as friends — register two accounts to test the full flow (add friend,
shared expense, settle up).

## Tests

```bash
flutter test          # 24 tests: balance engine, money math, models, error mapping
flutter analyze       # clean
```

## Housekeeping

- A stray duplicate Firebase project `splitmadu-ecc1c` exists in the account
  (from an earlier provisioning timeout). It is unused and can be deleted in
  the console: https://console.firebase.google.com/project/splitmadu-ecc1c/settings/general
- C: drive is nearly full (98%). Gradle/Flutter caches live on C: by default;
  consider `GRADLE_USER_HOME` on D: or clearing old caches before release builds.

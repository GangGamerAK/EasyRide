## EasyRide – Carpooling App (Flutter)

### What it is
EasyRide is a carpooling app built with Flutter. It matches passengers and drivers based on how closely their routes overlap.

### Core features
- Route matching using OSRM (Open Source Routing Machine) as an alternative to Google Maps
- Role-based flows for passenger and driver
- Real-time chat and basic profile management

### Tech stack
- Flutter (Dart)
- Maps: flutter_map + OpenStreetMap tiles
- Routing: OSRM HTTP API (via `RouteService`)
- Backend: Firebase (Firestore, optional Storage)
- Image hosting: ImgBB (optional)

### Getting started
1) Install Flutter and clone the repo.
2) Provide secrets at runtime via `--dart-define` (no keys in repo):
```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=... \
  --dart-define=IMGBB_API_KEY=...
```
Or create a local `.env` and use: `--dart-define-from-file=.env` (the file is gitignored).

3) If you need platform folders (android/ios/etc), regenerate them:
```bash
flutter create .
```

### Where the matching happens
- See `lib/services/route_service.dart` for OSRM requests and match logic.
- Firebase CRUD and higher-level flows live in `lib/services/` and the `views/` folders.

### Project structure (high level)
- `lib/` app code (views, widgets, services, models)
- `pubspec.yaml` dependencies
- Platform folders are intentionally excluded from the repo; generate with `flutter create .` when needed.

### Notes
- Secrets are provided at runtime; do not commit keys.
- OSRM can be your own server or a hosted endpoint.

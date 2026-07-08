# P4U Customer Flutter App

Native Flutter Customer app for Planext4u. It uses the Planext4u gateway API at `https://api.planext4u.com` by default.

## Run

```sh
flutter pub get
flutter run
```

To point at a different API host:

```sh
flutter run --dart-define=P4U_API_BASE_URL=https://api.planext4u.com
```

The app no longer needs `SUPABASE_URL` or `SUPABASE_ANON_KEY` dart-defines.

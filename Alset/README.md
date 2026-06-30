# Alset iOS App Setup

## Quick start (Xcode)

1. Open **`Alset.xcodeproj`** at the repo root (double-click or `open Alset.xcodeproj`).
2. Copy [`Config/Secrets.xcconfig.example`](Config/Secrets.xcconfig.example) → `Config/Secrets.xcconfig` if you have not already, then fill in `TESLA_CLIENT_SECRET` and `SUPABASE_ANON_KEY`.
3. Select your **Team** under Signing & Capabilities for the Alset target.
4. Press **Cmd+R** to build and run on a simulator or device.

The project uses bundle ID `com.mildminihi.alset`, iOS 17.0+, Swift 6.0, and `Alset/Config/Secrets.xcconfig` for Debug/Release.

To regenerate the Xcode project after adding Swift files, run:

```bash
python3 scripts/generate_xcodeproj.py
```

## URL scheme (Tesla OAuth callback)

The included [`Info.plist`](Info.plist) registers:

- **URL Scheme:** `alset`
- **Redirect URI:** `alset://auth/callback`

## Supabase prerequisites

1. Run [`../supabase/migrations/20260630120000_create_tesla_auth.sql`](../supabase/migrations/20260630120000_create_tesla_auth.sql)
2. Create a Supabase Auth user (email/password) in Dashboard → Authentication
3. Sign in via the app before connecting Tesla (RLS requires `authenticated` role)

## Tesla Developer Portal

- **Origin:** `https://eqgxfdbaxptmokniggar.supabase.co`
- **Redirect URI:** `alset://auth/callback`
- **Grant type:** Authorization Code + PKCE

## App flow

1. **Sign In** → Supabase email/password
2. **Connect with Tesla** → OAuth PKCE → tokens saved to `tesla_auth`
3. **Dashboard** → `fetchVehicleData()` for battery, climate, and lock state

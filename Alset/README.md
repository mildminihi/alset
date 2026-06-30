# Alset iOS App Setup

## 1. Create Xcode project

1. File → New → Project → iOS App
2. Product Name: **Alset**
3. Interface: **SwiftUI**
4. Add all files from this `Alset/` folder to the target

## 2. URL scheme (Tesla OAuth callback)

The included [`Info.plist`](Info.plist) registers:

- **URL Scheme:** `alset`
- **Redirect URI:** `alset://auth/callback`

In Xcode, set **Info.plist File** to `Alset/Info.plist` or merge `CFBundleURLTypes` into your target Info.

## 3. Secrets (xcconfig)

1. Copy [`Config/Secrets.xcconfig.example`](Config/Secrets.xcconfig.example) → `Config/Secrets.xcconfig`
2. Fill in `TESLA_CLIENT_SECRET` and `SUPABASE_ANON_KEY`
3. Project → Info → Configurations → set Debug/Release to `Secrets.xcconfig`

## 4. Supabase prerequisites

1. Run [`../supabase/migrations/20260630120000_create_tesla_auth.sql`](../supabase/migrations/20260630120000_create_tesla_auth.sql)
2. Create a Supabase Auth user (email/password) in Dashboard → Authentication
3. Sign in via the app before connecting Tesla (RLS requires `authenticated` role)

## 5. Tesla Developer Portal

- **Origin:** `https://eqgxfdbaxptmokniggar.supabase.co`
- **Redirect URI:** `alset://auth/callback`
- **Grant type:** Authorization Code + PKCE

## 6. App flow

1. **Sign In** → Supabase email/password
2. **Connect with Tesla** → OAuth PKCE → tokens saved to `tesla_auth`
3. **Dashboard** → `fetchVehicleData()` for battery, climate, and lock state

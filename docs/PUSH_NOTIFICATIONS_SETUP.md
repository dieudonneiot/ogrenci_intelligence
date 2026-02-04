# Push Notifications (FCM) setup

This repo uses **Firebase Cloud Messaging (FCM)** + **Supabase Edge Functions** to send push notifications to mobile devices.

Note: Push is currently implemented for **Android/iOS only** (web push is intentionally disabled for now).

## 1) Run Supabase SQL

Run `docs/sql/25_push_notifications.sql` in your Supabase SQL editor (after the core schema + helpers).

It creates:
- `public.push_tokens` (stores device tokens)
- RPC: `upsert_my_push_token(...)` (client registers token)
- RPC: `company_create_focus_check(...)` + `start_sent_focus_check(...)` (focus-check push flow)

## 2) Firebase project

Create a Firebase project and enable Cloud Messaging.

### Android

- Download `google-services.json` and place it at:
  - `android/app/google-services.json`
- Ensure your `applicationId` matches what Firebase expects:
  - `android/app/build.gradle.kts` -> `applicationId = "com.ogrenciintelligence.ogrenci_intelligence"`

### iOS

- Download `GoogleService-Info.plist` and place it at:
  - `ios/Runner/GoogleService-Info.plist`
- In Xcode:
  - Enable **Push Notifications** capability
  - Enable **Background Modes** -> Remote notifications

## 3) Deploy Edge Function

This repo adds a function at `supabase/functions/push/index.ts`.

Deploy it to your Supabase project using the Supabase CLI:
- `supabase functions deploy push`

## 4) Set Supabase Function secrets

In Supabase dashboard -> **Project Settings -> Functions -> Secrets**, add:
- `SERVICE_ROLE_KEY` = **service role key** (server-only)
- `FIREBASE_SERVICE_ACCOUNT_JSON` = the full JSON content of a Firebase service account
  - Create one in Google Cloud -> IAM -> Service Accounts -> Create Key (JSON)
  - Paste the JSON as a single string value (keep it secret)

Notes:
- Many Supabase projects already inject `SUPABASE_URL` and `SUPABASE_ANON_KEY` into Edge Functions automatically, so you usually do **not** need to add them as secrets.
- Some Supabase UIs block adding secrets that start with `SUPABASE_`. This repo’s function supports `SERVICE_ROLE_KEY` (recommended) and also accepts `BASE_SERVICE_ROLE_KEY` / `SUPABASE_SERVICE_ROLE_KEY` if you prefer.

## 5) How it works in the app

- On mobile, the app initializes Firebase and registers the device token via `upsert_my_push_token(...)`.
- Company can send a Focus Check from `CompanyApplicationsScreen` (accepted internship application):
  - Creates the focus check row (`company_create_focus_check`)
  - Calls Edge Function `push` to deliver the notification via FCM
- Tapping the notification opens `/focus-check?id=<focus_check_id>` and the countdown starts.

## 6) Quick test (end-to-end)

1) Install the SQL + deploy the function + set secrets (steps 1-4)
2) Run the mobile app and sign in as a **student** on a real device
3) Run the mobile app and sign in as a **company** that has an **accepted internship application**
4) Open Company -> Applications and click **Send Focus Check**
5) On the student device, tap the push notification -> it opens Focus Check and auto-starts

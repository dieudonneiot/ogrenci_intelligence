# Chatbot setup (Supabase Edge Function + Flutter)

This project’s Chatbot is implemented as a Supabase Edge Function: `supabase/functions/chatbot/index.ts`, and is called from Flutter via:
- Non-streaming: `SupabaseClient.functions.invoke('chatbot', ...)`
- Streaming (SSE): direct HTTP to `POST /functions/v1/chatbot`

## 1) Run the required SQL (Supabase)

In a new Supabase project, run the SQL scripts in `docs/sql/README_NEW_PROJECT.md` (in order).

For Chat specifically, make sure these are applied:
- `docs/sql/08_rls_chat.sql`
- `docs/sql/15_chatbot_ai.sql` (recommended)

## 2) Configure Flutter env (`.env`)

Flutter reads `.env` via `lib/src/core/config/env.dart`.

Required:
- `SUPABASE_URL` → `https://<project-ref>.supabase.co`
- `SUPABASE_ANON_KEY` → **anon public key** (JWT, usually starts with `eyJ...`)

Notes about Supabase “keys” (common confusion):
- **anon public key**: JWT-like, starts with `eyJ...` → used in client apps (`apikey` header).
- **service_role key**: JWT-like, starts with `eyJ...` → server-only (never ship to clients).
- **publishable key**: starts with `sb_publishable_...` → *not* the same as the anon JWT key.

This Flutter app expects the **anon JWT key** in `SUPABASE_ANON_KEY`.

## 3) Configure Edge Function secrets (Supabase)

The Edge Function needs these secrets set in your Supabase project (Dashboard → Edge Functions → Secrets, or via CLI):

Required:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` → anon public key (JWT)
- `SUPABASE_SERVICE_ROLE_KEY` → service role key (JWT)

AI provider (required unless you only use FAQ mode):
- `OPENAI_API_KEY` (or `AI_API_KEY`)

Optional tuning:
- `AI_MODEL` (default: `gpt-4o-mini`)
- `AI_BASE_URL` (default: `https://api.openai.com/v1`)
- `AI_TIMEOUT_MS` (default: `20000`)

### Why keys matter (the “Reference keys” mistake)

If the Edge Function is configured with the wrong Supabase key (for example, a publishable key or a key from another project), user validation can fail and the function will respond `401 Unauthorized`.

This function is defensive and will try multiple keys (env anon key → request `apikey` header → service role key), but **you should still set the secrets correctly** to avoid surprises.

## 4) Deploy the Edge Function

From the repo root:

```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase functions deploy chatbot
```

Then set/update secrets:

```bash
supabase secrets set SUPABASE_URL=... SUPABASE_ANON_KEY=... SUPABASE_SERVICE_ROLE_KEY=... OPENAI_API_KEY=...
```

## 5) Verify with a direct request

If you can get a valid user access token (JWT) from your app session, you can test:

### Getting `ACCESS_TOKEN`

Supabase does **not** show you a user's `access_token` in the Dashboard. It is minted when the user signs in (and it expires/rotates), so you must obtain it via an auth sign-in flow.

Options:
- From Flutter (recommended): after login, read `Supabase.instance.client.auth.currentSession?.accessToken` (or `supabase.auth.currentSession?.accessToken`).
- From the Auth REST API: create a user in Dashboard → Authentication → Users, set a password, then:

```bash
curl -sX POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"you@example.com\",\"password\":\"your-password\"}"
```

Use the `access_token` field from the response as `$ACCESS_TOKEN` in the request below.

```bash
curl -i -X POST "$SUPABASE_URL/functions/v1/chatbot" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"message\":\"Merhaba\",\"locale\":\"tr\",\"stream\":false}"
```

Expected:
- `200` with `{ "reply": "...", "session_id": "...", ... }`

If you get `401`, the response body will include a `details` message to help pinpoint whether:
- the `Authorization` header is missing/malformed, or
- the access token can’t be validated (wrong project URL/key, expired token, etc.).

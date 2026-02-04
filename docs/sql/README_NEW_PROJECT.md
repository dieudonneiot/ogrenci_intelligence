# New Supabase project setup (run order)

This repo contains SQL scripts under `docs/sql/` to bootstrap a fresh Supabase project to the minimum schema required by the Flutter app.

## 1) Configure env

Update `.env` / `.env.example`:
- `SUPABASE_URL` (or `BASE_URL`)
- `SUPABASE_ANON_KEY` (or `BASE_ANON_KEY`)

## 2) Run SQL in Supabase SQL editor (in this order)

1. `docs/sql/00_schema_core.sql` (creates core tables)
2. `docs/sql/00_helpers.sql` (helper functions used by RLS/RPC)
3. RLS policies:
   - `docs/sql/01_rls_users.sql`
   - `docs/sql/02_rls_courses.sql`
   - `docs/sql/03_rls_jobs_internships.sql`
   - `docs/sql/04_rls_favorites.sql`
   - `docs/sql/05_rls_points.sql`
   - `docs/sql/06_rls_company.sql`
   - `docs/sql/07_rls_admin.sql`
   - `docs/sql/08_rls_chat.sql`
   - `docs/sql/09_rls_other.sql`
4. Views:
   - `docs/sql/13_views.sql`
5. RPCs:
   - `docs/sql/10_rpc_points.sql`
   - `docs/sql/11_rpc_delete_user.sql`
   - `docs/sql/12_rpc_checks.sql`
   - `docs/sql/14_rpc_reports.sql`
   - `docs/sql/company_signup_rpc.sql`
   - `docs/sql/15_chatbot_ai.sql` (optional, but recommended if you use Chat)
6. OI + Case Analysis + Focus Check + Evidence:
   - `docs/sql/16_oi_case_focus_evidence.sql`
   - `docs/sql/22_oi_score_history.sql` (OI trend / month delta)
   - `docs/sql/23_excuse_requests.sql` (freeze-term requests + company review)
   - `docs/sql/24_talent_mining.sql` (Talent Mining RPC for companies)
   - `docs/sql/25_push_notifications.sql` (FCM tokens + focus-check push trigger)
7. Nano-learning mini-quiz (optional, for Development/Reels):
   - `docs/sql/19_nano_learning_quiz.sql`
8. Storage bucket + policies (run last):
   - `docs/sql/17_storage_evidence.sql`
   - `docs/sql/20_storage_profile_assets.sql`

## If you already ran older SQL scripts

- If you see errors like: `infinite recursion detected in policy for relation "jobs"` (code `42P17`),
  run `docs/sql/18_fix_rls_recursion.sql` once, then re-run `docs/sql/03_rls_jobs_internships.sql`.
- If the UI complains about missing columns like `companies.logo_url` / `companies.cover_image_url` / `profiles.avatar_url`,
  run `docs/sql/21_migrate_company_and_profiles.sql` once.

## 3) Storage

After `docs/sql/17_storage_evidence.sql`, ensure the bucket `evidence` exists in Supabase Storage.

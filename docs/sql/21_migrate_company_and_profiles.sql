-- Migration helper (run if your project was created with older scripts)
-- Adds columns used by the current Flutter UI for:
-- - company approvals (approved_at / approved_by)
-- - company branding (logo_url / cover_image_url)
-- - student avatars (profiles.avatar_url)

alter table public.profiles
  add column if not exists avatar_url text;

alter table public.companies
  add column if not exists logo_url text,
  add column if not exists employee_count text,
  add column if not exists founded_year integer,
  add column if not exists linkedin text,
  add column if not exists twitter text,
  add column if not exists facebook text,
  add column if not exists instagram text,
  add column if not exists cover_image_url text,
  add column if not exists trade_registry_number text,
  add column if not exists approved_at timestamp with time zone,
  add column if not exists approved_by uuid;


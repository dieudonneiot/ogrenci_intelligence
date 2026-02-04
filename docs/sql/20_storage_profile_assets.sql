-- Supabase Storage buckets + policies for profile images (Pro)
--
-- Buckets:
-- - avatars (public): student profile pictures
-- - company-assets (public): company logos / cover images
--
-- NOTE: Uses folder conventions to enforce upload permissions.

-- --------------------------
-- 1) Buckets
-- --------------------------

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('company-assets', 'company-assets', true)
on conflict (id) do nothing;

-- --------------------------
-- 2) Objects policies
-- --------------------------

-- Students upload to: {userId}/{filename}
drop policy if exists "avatars objects insert own" on storage.objects;
create policy "avatars objects insert own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = auth.uid()::text
);

-- Public read (bucket is public, but keep policy explicit)
drop policy if exists "avatars objects select public" on storage.objects;
create policy "avatars objects select public"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'avatars');

-- Companies upload to: {companyId}/{filename}
drop policy if exists "company-assets objects insert staff" on storage.objects;
create policy "company-assets objects insert staff"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'company-assets'
  and (
    public.is_admin()
    or public.is_company_staff(split_part(name, '/', 1)::uuid)
  )
);

drop policy if exists "company-assets objects select public" on storage.objects;
create policy "company-assets objects select public"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'company-assets');


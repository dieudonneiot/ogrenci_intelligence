-- Supabase Storage bucket + policies for evidence uploads (MVP)
--
-- IMPORTANT:
-- - This touches the `storage` schema. Apply in Supabase SQL editor with a role that can manage buckets/policies.
-- - Bucket: `evidence` (private)

-- 1) Bucket
insert into storage.buckets (id, name, public)
values ('evidence', 'evidence', false)
on conflict (id) do nothing;

-- 2) Objects RLS policies
-- Path convention recommended by the app:
--   {userId}/{timestamp}_{filename}
--
-- Students can upload to their own folder.
-- Companies can read objects referenced by evidence_items for their company.

drop policy if exists "evidence objects insert own" on storage.objects;
create policy "evidence objects insert own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'evidence'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "evidence objects select via evidence_items" on storage.objects;
create policy "evidence objects select via evidence_items"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'evidence'
  and exists (
    select 1
    from public.evidence_items ei
    where ei.file_path = storage.objects.name
      and (
        ei.user_id = auth.uid()
        or public.is_company_member(ei.company_id)
        or public.is_admin()
      )
  )
);

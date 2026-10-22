-- Wrytole additive document-access and teacher-profile migration.
-- Review before running. This does not delete existing rows or replace existing tables.
alter table public.profiles add column if not exists avatar_path text;

-- Public-facing view exposes only educator display fields, not phone or other profile data.
create or replace view public.educator_public_profiles as
select id, full_name, role, avatar_path
from public.profiles
where role in ('teacher','admin');
grant select on public.educator_public_profiles to anon, authenticated;

-- Individual document purchase submissions and admin review.
alter table public.document_purchases enable row level security;
drop policy if exists "Wrytole users submit own pending document purchases" on public.document_purchases;
create policy "Wrytole users submit own pending document purchases"
on public.document_purchases for insert to authenticated
with check (user_id = (select auth.uid()) and status = 'pending' and amount_ugx > 0);
drop policy if exists "Wrytole users read own document purchases" on public.document_purchases;
create policy "Wrytole users read own document purchases"
on public.document_purchases for select to authenticated
using (user_id = (select auth.uid()) or exists (
  select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'
));
drop policy if exists "Wrytole admins review document purchases" on public.document_purchases;
create policy "Wrytole admins review document purchases"
on public.document_purchases for update to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'))
with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));

-- Permit reading only the avatar object explicitly attached to a teacher/admin profile.
drop policy if exists "Wrytole read approved educator avatars" on storage.objects;
create policy "Wrytole read approved educator avatars"
on storage.objects for select to anon, authenticated
using (
  bucket_id = 'education-files'
  and exists (
    select 1 from public.profiles p
    where p.avatar_path = name and p.role in ('teacher','admin')
  )
);

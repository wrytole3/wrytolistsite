-- Wrytolistsite setup for the existing Supabase project. Review, then run in SQL Editor.
-- Never place a service-role or secret key in browser files.
-- Approved teachers' uploads publish immediately, as requested. Teacher roles are admin-approved.

alter table public.subscription_plans add column if not exists audience text not null default 'learner';
alter table public.subscription_plans drop constraint if exists subscription_plans_audience_check;
alter table public.subscription_plans add constraint subscription_plans_audience_check check(audience in ('learner','teacher'));
update public.subscription_plans set audience='learner' where id in ('day','week','month','quarter','year_plus');
insert into public.subscription_plans(id,name,price_ugx,duration_days,download_limit,active,description,audience)
values('teacher_monthly','Teacher Monthly',50000,30,null,true,'Teacher account subscription for 30 days','teacher')
on conflict(id) do update set name=excluded.name,price_ugx=excluded.price_ugx,duration_days=excluded.duration_days,download_limit=excluded.download_limit,active=true,description=excluded.description,audience='teacher';

create table if not exists public.teacher_applications(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 requested_role text not null default 'teacher' check(requested_role in ('teacher','school')),
 school_name text, notes text, status text not null default 'pending' check(status in ('pending','approved','rejected')),
 submitted_at timestamptz not null default now(), reviewed_at timestamptz, reviewed_by uuid references public.profiles(id));
alter table public.teacher_applications enable row level security;
drop policy if exists "Applicants read own teacher requests" on public.teacher_applications;
create policy "Applicants read own teacher requests" on public.teacher_applications for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists "Users submit own teacher requests" on public.teacher_applications;
create policy "Users submit own teacher requests" on public.teacher_applications for insert to authenticated with check(user_id=(select auth.uid()) and status='pending');
drop policy if exists "Admins manage teacher requests" on public.teacher_applications;
create policy "Admins manage teacher requests" on public.teacher_applications for all to authenticated using(exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin')) with check(exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));

-- Private helper schema: create a student profile automatically after signup without allowing users to choose their role.
create schema if not exists wrytole_private;
revoke all on schema wrytole_private from public, anon, authenticated;
create or replace function wrytole_private.create_profile_for_auth_user()
returns trigger language plpgsql security definer set search_path=''
as $$ begin
 insert into public.profiles(id,full_name,phone,school_name,role,country)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),nullif(new.raw_user_meta_data->>'phone',''),nullif(new.raw_user_meta_data->>'school_name',''),'student','Uganda')
 on conflict(id) do nothing;
 return new;
end; $$;
revoke all on function wrytole_private.create_profile_for_auth_user() from public, anon, authenticated;
drop trigger if exists wrytole_auth_user_profile on auth.users;
create trigger wrytole_auth_user_profile after insert on auth.users for each row execute function wrytole_private.create_profile_for_auth_user();

-- Approved resource metadata is public. Owners/admins can also see their own rows.
alter table public.resources enable row level security;
drop policy if exists "Wrytole public read approved resources" on public.resources;
create policy "Wrytole public read approved resources" on public.resources for select to anon,authenticated using(status='approved' or uploader_id=(select auth.uid()) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));
drop policy if exists "Wrytole teachers insert resources" on public.resources;
create policy "Wrytole teachers insert resources" on public.resources for insert to authenticated with check(uploader_id=(select auth.uid()) and status='approved' and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('teacher','admin')));
drop policy if exists "Wrytole teachers update own resources" on public.resources;
create policy "Wrytole teachers update own resources" on public.resources for update to authenticated using(uploader_id=(select auth.uid()) and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('teacher','admin'))) with check(uploader_id=(select auth.uid()) and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('teacher','admin')));
drop policy if exists "Wrytole teachers delete own resources" on public.resources;
create policy "Wrytole teachers delete own resources" on public.resources for delete to authenticated using(uploader_id=(select auth.uid()) and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('teacher','admin')));

alter table public.subscription_plans enable row level security;
drop policy if exists "Wrytole read active plans" on public.subscription_plans;
create policy "Wrytole read active plans" on public.subscription_plans for select to anon,authenticated using(active=true);
drop policy if exists "Wrytole users submit pending payments" on public.payment_submissions;
create policy "Wrytole users submit pending payments" on public.payment_submissions for insert to authenticated with check(user_id=(select auth.uid()) and status='pending');
drop policy if exists "Wrytole users read payment submissions" on public.payment_submissions;
create policy "Wrytole users read payment submissions" on public.payment_submissions for select to authenticated using(user_id=(select auth.uid()) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));
drop policy if exists "Wrytole admins manage payment submissions" on public.payment_submissions;
create policy "Wrytole admins manage payment submissions" on public.payment_submissions for all to authenticated using(exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin')) with check(exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));
drop policy if exists "Wrytole users read subscriptions" on public.subscriptions;
create policy "Wrytole users read subscriptions" on public.subscriptions for select to authenticated using(user_id=(select auth.uid()) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));
drop policy if exists "Wrytole admins manage subscriptions" on public.subscriptions;
create policy "Wrytole admins manage subscriptions" on public.subscriptions for all to authenticated using(exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin')) with check(exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));

-- Private Storage bucket for documents. Object path begins with the uploader's auth UUID.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('education-files','education-files',false,20971520,array['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation','image/png','image/jpeg','image/webp']) on conflict(id) do update set public=false,file_size_limit=20971520;
drop policy if exists "Wrytole teachers upload own files" on storage.objects;
create policy "Wrytole teachers upload own files" on storage.objects for insert to authenticated with check(bucket_id='education-files' and (storage.foldername(name))[1]=(select auth.uid())::text and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('teacher','admin')));
drop policy if exists "Wrytole read own or approved files" on storage.objects;
create policy "Wrytole read own or approved files" on storage.objects for select to anon,authenticated using(bucket_id='education-files' and ((storage.foldername(name))[1]=(select auth.uid())::text or exists(select 1 from public.resources r where r.file_path=name and r.status='approved') or exists(select 1 from public.resources r where r.cover_image_path=name and r.status='approved') or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin')));
drop policy if exists "Wrytole teachers update own files" on storage.objects;
create policy "Wrytole teachers update own files" on storage.objects for update to authenticated using(bucket_id='education-files' and (storage.foldername(name))[1]=(select auth.uid())::text and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('teacher','admin'))) with check(bucket_id='education-files' and (storage.foldername(name))[1]=(select auth.uid())::text and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('teacher','admin')));
drop policy if exists "Wrytole teachers delete own files" on storage.objects;
create policy "Wrytole teachers delete own files" on storage.objects for delete to authenticated using(bucket_id='education-files' and (storage.foldername(name))[1]=(select auth.uid())::text and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('teacher','admin')));

-- IMPORTANT: download-limit enforcement and subscription activation must be implemented by a trusted server/Edge Function.
-- The frontend can display limits, but browser-only checks are not secure against tampering.

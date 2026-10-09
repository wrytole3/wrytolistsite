-- Wrytole admin dashboard migration (additive; does not drop existing tables).
-- Run this in Supabase SQL Editor after backing up your database.
-- First, securely promote the confirmed administrator account, then reload admin.html.
do $$
declare admin_id uuid;
begin
  select id into admin_id from auth.users
  where lower(email) = lower('wrytole3@gmail.com') and email_confirmed_at is not null
  limit 1;
  if admin_id is null then
    raise exception 'No confirmed auth user found for wrytole3@gmail.com. Create and confirm that account first.';
  end if;
  insert into public.profiles (id, role)
  values (admin_id, 'admin')
  on conflict (id) do update set role = 'admin';
end $$;

-- These policies rely on the role stored in profiles. Never grant admin based only
-- on a browser email check. Existing table grants and RLS must already be enabled.
do $$
begin
  if to_regclass('public.teacher_applications') is not null then
    execute 'drop policy if exists "admins manage teacher applications" on public.teacher_applications';
    execute 'create policy "admins manage teacher applications" on public.teacher_applications for all to authenticated using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''admin'')) with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''admin''))';
  end if;
  if to_regclass('public.payment_submissions') is not null then
    execute 'drop policy if exists "admins manage payment submissions" on public.payment_submissions';
    execute 'create policy "admins manage payment submissions" on public.payment_submissions for all to authenticated using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''admin'')) with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''admin''))';
  end if;
  if to_regclass('public.subscriptions') is not null then
    execute 'drop policy if exists "admins manage subscriptions" on public.subscriptions';
    execute 'create policy "admins manage subscriptions" on public.subscriptions for all to authenticated using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''admin'')) with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''admin''))';
  end if;
  if to_regclass('public.resources') is not null then
    execute 'drop policy if exists "admins manage resources" on public.resources';
    execute 'create policy "admins manage resources" on public.resources for all to authenticated using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''admin'')) with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''admin''))';
  end if;
  if to_regclass('public.subscription_plans') is not null then
    execute 'drop policy if exists "admins manage plans" on public.subscription_plans';
    execute 'create policy "admins manage plans" on public.subscription_plans for all to authenticated using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''admin'')) with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''admin''))';
  end if;
end $$;

-- NOTE: This migration assumes table columns match the existing Wrytole schema.
-- Review SQL Editor output carefully. It is additive but creates/replaces named policies.

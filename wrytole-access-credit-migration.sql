-- Wrytole access-credit model migration (additive; preserves existing users, resources and payment records).
-- Legacy subscription plans are retired from sale, but their historical rows and subscriptions are preserved.
update public.subscription_plans set active=false;
-- Run this in Supabase SQL Editor after reviewing. It does not drop legacy tables or rows.

create table if not exists public.wrytole_access_accounts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  account_type text not null check (account_type in ('teacher','school')),
  activated boolean not null default false,
  activated_at timestamptz,
  activation_payment_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.wrytole_download_balances (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  credits_purchased integer not null default 0 check (credits_purchased >= 0),
  credits_used integer not null default 0 check (credits_used >= 0),
  updated_at timestamptz not null default now(),
  check (credits_used <= credits_purchased)
);

create table if not exists public.wrytole_access_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  account_type text not null check (account_type in ('student','teacher','school')),
  payment_type text not null check (payment_type in ('activation','package')),
  package_size integer,
  amount_ugx integer not null check (amount_ugx > 0),
  payment_method text not null default 'Chipper Cash',
  payment_reference text not null,
  notes text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  unique(payment_method, payment_reference),
  check (
    (payment_type='activation' and package_size is null and account_type in ('teacher','school'))
    or
    (payment_type='package' and package_size in (10,20,30,40,50))
  )
);

create table if not exists public.wrytole_download_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  resource_id uuid not null references public.resources(id) on delete cascade,
  downloaded_at timestamptz not null default now()
);

alter table public.wrytole_access_accounts enable row level security;
alter table public.wrytole_download_balances enable row level security;
alter table public.wrytole_access_payments enable row level security;
alter table public.wrytole_download_ledger enable row level security;

drop policy if exists "Wrytole users read own access account" on public.wrytole_access_accounts;
create policy "Wrytole users read own access account" on public.wrytole_access_accounts
for select to authenticated using (user_id = (select auth.uid()) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));

drop policy if exists "Wrytole users read own download balance" on public.wrytole_download_balances;
create policy "Wrytole users read own download balance" on public.wrytole_download_balances
for select to authenticated using (user_id = (select auth.uid()) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));

drop policy if exists "Wrytole users submit own access payment" on public.wrytole_access_payments;
create policy "Wrytole users submit own access payment" on public.wrytole_access_payments
for insert to authenticated with check (
  user_id=(select auth.uid()) and status='pending' and reviewed_at is null and reviewed_by is null
  and account_type = coalesce((select case when p.role in ('teacher','school') then p.role else 'student' end from public.profiles p where p.id=(select auth.uid())), 'student')
  and amount_ugx = case
    when payment_type='activation' and account_type='teacher' then 10000
    when payment_type='activation' and account_type='school' then 20000
    when payment_type='package' and account_type='school' and package_size=10 then 3000
    when payment_type='package' and account_type='school' and package_size=20 then 5000
    when payment_type='package' and account_type='school' and package_size=30 then 7000
    when payment_type='package' and account_type='school' and package_size=40 then 9000
    when payment_type='package' and account_type='school' and package_size=50 then 11000
    when payment_type='package' and account_type in ('student','teacher') and package_size in (10,20,30,40,50) then package_size*100
    else null end
);
drop policy if exists "Wrytole users read own access payments" on public.wrytole_access_payments;
create policy "Wrytole users read own access payments" on public.wrytole_access_payments
for select to authenticated using (user_id=(select auth.uid()) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));

drop policy if exists "Wrytole users read own download ledger" on public.wrytole_download_ledger;
create policy "Wrytole users read own download ledger" on public.wrytole_download_ledger
for select to authenticated using (user_id=(select auth.uid()) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));

-- Exact price validation is repeated inside the trusted approval function.
create or replace function public.wrytole_verify_access_payment(p_payment_id uuid, p_decision text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp
as $$
declare pay public.wrytole_access_payments%rowtype; actual_role text; expected integer;
begin
  if not exists(select 1 from public.profiles where id=auth.uid() and role='admin') then
    raise exception 'Administrator access required';
  end if;
  if p_decision not in ('approved','rejected') then raise exception 'Invalid decision'; end if;
  select * into pay from public.wrytole_access_payments where id=p_payment_id for update;
  if not found then raise exception 'Payment request not found'; end if;
  if pay.status <> 'pending' then raise exception 'This payment has already been reviewed'; end if;
  select role into actual_role from public.profiles where id=pay.user_id;
  if actual_role is null then raise exception 'User profile not found'; end if;
  expected := case
    when pay.payment_type='activation' and pay.account_type='teacher' then 10000
    when pay.payment_type='activation' and pay.account_type='school' then 20000
    when pay.payment_type='package' and pay.account_type='school' then case pay.package_size when 10 then 3000 when 20 then 5000 when 30 then 7000 when 40 then 9000 when 50 then 11000 end
    when pay.payment_type='package' and pay.account_type in ('student','teacher') then pay.package_size*100
    else null end;
  if expected is null or expected <> pay.amount_ugx then raise exception 'Payment amount does not match the current price'; end if;
  if pay.payment_type='activation' and exists(select 1 from public.wrytole_access_accounts a where a.user_id=pay.user_id and a.activated=true) then
    raise exception 'This account has already been activated';
  end if;
  if pay.account_type <> 'student' and actual_role <> pay.account_type and actual_role <> 'admin' then
    raise exception 'Account role does not match this payment request';
  end if;
  update public.wrytole_access_payments set status=p_decision, reviewed_at=now(), reviewed_by=auth.uid() where id=p_payment_id;
  if p_decision='approved' then
    if pay.payment_type='activation' then
      insert into public.wrytole_access_accounts(user_id,account_type,activated,activated_at,activation_payment_id)
      values(pay.user_id,pay.account_type,true,now(),pay.id)
      on conflict(user_id) do update set account_type=excluded.account_type,activated=true,activated_at=coalesce(public.wrytole_access_accounts.activated_at,now()),activation_payment_id=coalesce(public.wrytole_access_accounts.activation_payment_id,pay.id);
    else
      insert into public.wrytole_download_balances(user_id,credits_purchased,credits_used)
      values(pay.user_id,pay.package_size,0)
      on conflict(user_id) do update set credits_purchased=public.wrytole_download_balances.credits_purchased+excluded.credits_purchased,updated_at=now();
    end if;
  end if;
  return jsonb_build_object('success',true,'status',p_decision);
end; $$;
revoke all on function public.wrytole_verify_access_payment(uuid,text) from public, anon;
grant execute on function public.wrytole_verify_access_payment(uuid,text) to authenticated;

-- Called only by the document-access Edge Function using its service-role client.
-- A row lock makes the balance decrement atomic and prevents concurrent over-downloads.
create or replace function public.wrytole_consume_download_credit(p_user_id uuid,p_resource_id uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp
as $$
declare b public.wrytole_download_balances%rowtype; used_count integer;
begin
  insert into public.wrytole_download_balances(user_id) values(p_user_id) on conflict(user_id) do nothing;
  select * into b from public.wrytole_download_balances where user_id=p_user_id for update;
  if b.credits_purchased-b.credits_used <= 0 then
    return jsonb_build_object('success',false,'error','Your download balance is exhausted. Please purchase another package to continue downloading.','remaining',0);
  end if;
  update public.wrytole_download_balances set credits_used=credits_used+1,updated_at=now() where user_id=p_user_id;
  insert into public.wrytole_download_ledger(user_id,resource_id) values(p_user_id,p_resource_id);
  select credits_purchased-credits_used into used_count from public.wrytole_download_balances where user_id=p_user_id;
  return jsonb_build_object('success',true,'remaining',used_count);
end; $$;
revoke all on function public.wrytole_consume_download_credit(uuid,uuid) from public, anon, authenticated;
grant execute on function public.wrytole_consume_download_credit(uuid,uuid) to service_role;

create schema if not exists wrytole_private;
revoke all on schema wrytole_private from public, anon, authenticated;

create table if not exists public.teacher_applications(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 requested_role text not null default 'teacher' check(requested_role in ('teacher','school')),
 school_name text, notes text,
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 submitted_at timestamptz not null default now(), reviewed_at timestamptz,
 reviewed_by uuid references public.profiles(id)
);
alter table public.teacher_applications enable row level security;
drop policy if exists "Applicants read own teacher requests" on public.teacher_applications;
create policy "Applicants read own teacher requests" on public.teacher_applications for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists "Users submit own teacher requests" on public.teacher_applications;
create policy "Users submit own teacher requests" on public.teacher_applications for insert to authenticated with check(user_id=(select auth.uid()) and status='pending');
drop policy if exists "Admins manage teacher requests" on public.teacher_applications;
create policy "Admins manage teacher requests" on public.teacher_applications for all to authenticated using(exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin')) with check(exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));

-- A school signup stays a student until the administrator approves the school application.
-- The auth trigger below records a requested school/teacher role without granting it.
create or replace function wrytole_private.create_profile_for_auth_user()
returns trigger language plpgsql security definer set search_path=''
as $$
declare requested text;
begin
 requested := coalesce(new.raw_user_meta_data->>'account_role','student');
 if requested not in ('student','teacher','school') then requested := 'student'; end if;
 insert into public.profiles(id,full_name,phone,school_name,role,country)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),nullif(new.raw_user_meta_data->>'phone',''),nullif(new.raw_user_meta_data->>'school_name',''),'student','Uganda')
 on conflict(id) do nothing;
 if requested in ('teacher','school') then
   insert into public.teacher_applications(user_id,requested_role,school_name,notes)
   values(new.id,requested,nullif(new.raw_user_meta_data->>'school_name',''),'Application created during signup')
   on conflict do nothing;
 end if;
 return new;
end; $$;


-- Activation gates for teacher/school publishing. Existing files and rows remain untouched.
drop policy if exists "Wrytole teachers insert resources" on public.resources;
create policy "Wrytole teachers insert resources" on public.resources for insert to authenticated
with check (
 uploader_id=(select auth.uid()) and status='approved' and (
   exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin')
   or exists(select 1 from public.profiles p join public.wrytole_access_accounts a on a.user_id=p.id
             where p.id=(select auth.uid()) and p.role in ('teacher','school') and a.activated=true)
 )
);
drop policy if exists "Wrytole teachers update own resources" on public.resources;
create policy "Wrytole teachers update own resources" on public.resources for update to authenticated
using (uploader_id=(select auth.uid()) and (
 exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin')
 or exists(select 1 from public.profiles p join public.wrytole_access_accounts a on a.user_id=p.id where p.id=(select auth.uid()) and p.role in ('teacher','school') and a.activated=true)
))
with check (uploader_id=(select auth.uid()) and (
 exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin')
 or exists(select 1 from public.profiles p join public.wrytole_access_accounts a on a.user_id=p.id where p.id=(select auth.uid()) and p.role in ('teacher','school') and a.activated=true)
));
drop policy if exists "Wrytole teachers upload own files" on storage.objects;
create policy "Wrytole teachers upload own files" on storage.objects for insert to authenticated
with check (bucket_id='education-files' and (storage.foldername(name))[1]=(select auth.uid())::text and (
 exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin')
 or exists(select 1 from public.profiles p join public.wrytole_access_accounts a on a.user_id=p.id where p.id=(select auth.uid()) and p.role in ('teacher','school') and a.activated=true)
));

-- Ensure the auth trigger uses the role-request metadata for future signups.
drop trigger if exists wrytole_auth_user_profile on auth.users;
create trigger wrytole_auth_user_profile after insert on auth.users
for each row execute function wrytole_private.create_profile_for_auth_user();

-- Ornomart Jewellery Quiz: tables, security and admin access.
-- Run this once in the Supabase SQL editor (or apply as a migration).

-- 1. Quiz entries: one row per finished quiz.
create table if not exists public.quiz_submissions (
  id             uuid primary key default gen_random_uuid(),
  created_at     timestamptz not null default now(),
  name           text not null check (char_length(name) between 2 and 100),
  phone          text not null check (phone ~ '^[6-9][0-9]{9}$'),
  email          text check (char_length(email) between 5 and 200 and email like '%@%.%'),  -- only from Google sign-in
  city           text check (char_length(city) between 1 and 100),                             -- no longer asked
  interest       text check (interest is null or char_length(interest) <= 100),
  score          int  not null check (score between 0 and 10),
  total          int  not null default 10 check (total = 10),
  discount       text not null check (discount ~ '^([1-9]|10|15|20)%$'),  -- 1% per correct answer; 15%/20% only on early coupons
  coupon_code    text not null unique check (coupon_code ~ '^GEM(0[1-9]|10|15|20)-[A-Z0-9]{5}$'),
  timed_out      boolean not null default false,
  time_taken_sec int check (time_taken_sec between 0 and 420),
  redeemed_at    timestamptz,
  user_id        uuid default auth.uid() references auth.users(id) on delete set null  -- set when the player signed in with Google
);

-- New entries: discount must equal the score (minimum 1%) and the code prefix must match.
alter table public.quiz_submissions drop constraint if exists quiz_submissions_discount_matches_score;
alter table public.quiz_submissions
  add constraint quiz_submissions_discount_matches_score
  check (discount = greatest(score, 1)::text || '%'
         and substring(coupon_code from 4 for 2)::int = greatest(score, 1)) not valid;

create index if not exists quiz_submissions_created_at_idx on public.quiz_submissions (created_at desc);
create index if not exists quiz_submissions_phone_idx on public.quiz_submissions (phone);
create index if not exists quiz_submissions_user_id_idx on public.quiz_submissions (user_id);

-- 2. Admin list: only these emails can see entries in the dashboard.
create table if not exists public.quiz_admins (
  email text primary key check (email = lower(email))
);

-- 3. Helper: is the signed-in user on the admin list?
create or replace function public.is_quiz_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.quiz_admins
    where email = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

revoke all on function public.is_quiz_admin() from public, anon;
grant execute on function public.is_quiz_admin() to authenticated;

-- 4. Row level security.
alter table public.quiz_submissions enable row level security;
alter table public.quiz_admins enable row level security;  -- no policies: not readable through the API

-- Players (not signed in) can only add a new, unredeemed entry. They can never read entries back.
revoke all on public.quiz_submissions from anon, authenticated;
revoke all on public.quiz_admins from anon, authenticated;
grant insert (name, phone, email, city, interest, score, total, discount, coupon_code, timed_out, time_taken_sec)
  on public.quiz_submissions to anon, authenticated;
grant select on public.quiz_submissions to authenticated;
grant update (redeemed_at) on public.quiz_submissions to authenticated;

drop policy if exists "Players can submit an entry" on public.quiz_submissions;
create policy "Players can submit an entry"
  on public.quiz_submissions for insert
  to anon, authenticated
  with check (redeemed_at is null);

drop policy if exists "Admins can read entries" on public.quiz_submissions;
create policy "Admins can read entries"
  on public.quiz_submissions for select
  to authenticated
  using ((select public.is_quiz_admin()));

drop policy if exists "Admins can mark coupons redeemed" on public.quiz_submissions;
create policy "Admins can mark coupons redeemed"
  on public.quiz_submissions for update
  to authenticated
  using ((select public.is_quiz_admin()))
  with check ((select public.is_quiz_admin()));

-- 5. Players see only their own entries (My Coupons page): by mobile + name together, or by their Google account.
create or replace function public.get_my_quiz_entries(p_phone text default null, p_name text default null)
returns table (
  created_at timestamptz, name text, score int, total int, discount text,
  coupon_code text, timed_out boolean, time_taken_sec int, redeemed_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.created_at, s.name, s.score, s.total, s.discount,
         s.coupon_code, s.timed_out, s.time_taken_sec, s.redeemed_at
  from public.quiz_submissions s
  where (
          p_phone is not null and p_name is not null
          and s.phone = trim(p_phone)
          and lower(regexp_replace(trim(s.name), '\s+', ' ', 'g')) = lower(regexp_replace(trim(p_name), '\s+', ' ', 'g'))
        )
     or (
          p_phone is null and p_name is null and auth.uid() is not null
          and (s.user_id = auth.uid() or s.email = lower(coalesce(auth.jwt() ->> 'email', '')))
        )
  order by s.created_at desc
  limit 100;
$$;

revoke all on function public.get_my_quiz_entries(text, text) from public;
grant execute on function public.get_my_quiz_entries(text, text) to anon, authenticated;

-- 6. Add the admin login email(s). Use the same email you create under Authentication > Users.
-- insert into public.quiz_admins (email) values ('admin@example.com') on conflict do nothing;

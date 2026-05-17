-- =============================================================
-- Migration 001 — Profiles
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- =============================================================

-- =============================================================
-- PROFILES TABLE
-- Extends auth.users with app-specific data.
-- id is a FK to auth.users(id) — cascade delete ensures
-- that removing an auth user also removes their profile.
-- =============================================================
create table public.profiles (
    id              uuid        references auth.users(id) on delete cascade primary key,
    username        text        unique not null,
    display_name    text        not null,
    avatar_url      text,
    avatar_color    text        not null default '#1A1A1A',
    bio             text        not null default '',
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),

    -- username: 3–30 chars, lowercase letters/numbers/dots/underscores only
    constraint profiles_username_length check (char_length(username) between 3 and 30),
    constraint profiles_username_format check (username ~ '^[a-z0-9_.]+$'),
    -- display_name: 1–50 chars
    constraint profiles_display_name_length check (char_length(display_name) between 1 and 50),
    -- bio: max 160 chars (Twitter-style)
    constraint profiles_bio_length check (char_length(bio) <= 160)
);

-- =============================================================
-- ROW LEVEL SECURITY
-- RLS is enabled on every table. The anon role (client key)
-- has no access by default. Policies grant exactly what's needed.
-- The service_role key bypasses RLS — it must never be in the app.
-- =============================================================
alter table public.profiles enable row level security;

-- Authenticated users can read any profile (needed for feed, map, search)
create policy "profiles: read by authenticated users"
    on public.profiles
    for select
    to authenticated
    using (true);

-- Users can only insert their own row (enforced by trigger anyway,
-- but defence-in-depth: belt AND suspenders)
create policy "profiles: insert own row only"
    on public.profiles
    for insert
    to authenticated
    with check (auth.uid() = id);

-- Users can only update their own row
create policy "profiles: update own row only"
    on public.profiles
    for update
    to authenticated
    using    (auth.uid() = id)
    with check (auth.uid() = id);

-- No direct DELETE policy — account deletion goes through
-- auth.admin.deleteUser() server-side, which cascades here.

-- =============================================================
-- AUTO-UPDATE updated_at
-- =============================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger profiles_set_updated_at
    before update on public.profiles
    for each row
    execute function public.set_updated_at();

-- =============================================================
-- AUTO-CREATE PROFILE ON SIGNUP
-- Fires after a new row is inserted into auth.users.
-- SECURITY DEFINER: runs with the privileges of the function
-- owner (postgres), not the calling user — required because
-- the new user doesn't have a profile row yet.
-- set search_path = public: prevents search_path hijacking.
-- =============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    _raw_name  text;
    _username  text;
    _display   text;
    _suffix    text;
begin
    -- Apple Sign-In sends full_name in raw_user_meta_data on first login
    _raw_name := trim(coalesce(new.raw_user_meta_data->>'full_name', ''));
    _display  := case
        when _raw_name <> '' then _raw_name
        else split_part(coalesce(new.email, ''), '@', 1)
    end;
    if _display = '' then
        _display := 'here. user';
    end if;

    -- Build a safe lowercase username from the display name
    _username := lower(
        regexp_replace(
            coalesce(nullif(_raw_name, ''), split_part(coalesce(new.email, ''), '@', 1), 'user'),
            '[^a-z0-9_.]', '.', 'g'   -- replace unsafe chars with dots
        )
    );
    -- Trim leading/trailing dots and collapse runs
    _username := regexp_replace(trim(_username, '.'), '\.{2,}', '.', 'g');
    -- Enforce min length
    if char_length(_username) < 3 then
        _username := _username || substr(md5(new.id::text), 1, 5);
    end if;
    -- Enforce max length
    _username := left(_username, 25);

    -- Guarantee uniqueness: append random suffix if taken
    if exists (select 1 from public.profiles where username = _username) then
        _suffix   := substr(md5(random()::text), 1, 5);
        _username := left(_username, 24) || _suffix;
    end if;

    insert into public.profiles (id, username, display_name)
    values (new.id, _username, _display);

    return new;
end;
$$;

-- Trigger fires once per new auth user (after insert)
create trigger on_auth_user_created
    after insert on auth.users
    for each row
    execute function public.handle_new_user();

-- =============================================================
-- DONE
-- Next migration: 002_posts.sql (location_posts, reactions, comments)
-- =============================================================

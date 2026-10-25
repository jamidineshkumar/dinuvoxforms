-- DinuVoX Forms independent Supabase schema.
-- Run this whole file in Supabase Dashboard -> SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.forms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Untitled form',
  description text not null default '',
  status text not null default 'draft' check (status in ('draft','published','closed')),
  slug text not null unique,
  layout text not null default 'classic' check (layout in ('classic','conversational')),
  fields jsonb not null default '[]'::jsonb,
  design jsonb not null default '{}'::jsonb,
  intro jsonb not null default '{}'::jsonb,
  conditional_logic jsonb not null default '[]'::jsonb,
  settings jsonb not null default '{}'::jsonb,
  views integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.forms(id) on delete cascade,
  form_owner_id uuid not null references auth.users(id) on delete cascade,
  answers jsonb not null default '{}'::jsonb,
  duration_seconds integer not null default 0,
  score jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.saved_themes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  design jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists forms_owner_idx on public.forms(owner_id);
create index if not exists forms_slug_idx on public.forms(slug);
create index if not exists submissions_form_idx on public.submissions(form_id, created_at desc);
create index if not exists submissions_owner_idx on public.submissions(form_owner_id);
create index if not exists themes_owner_idx on public.saved_themes(owner_id);

alter table public.forms enable row level security;
alter table public.submissions enable row level security;
alter table public.saved_themes enable row level security;

-- Owners can manage their forms; anyone can read only published/closed public forms by slug.
drop policy if exists "owners manage forms" on public.forms;
create policy "owners manage forms" on public.forms for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists "public read published forms" on public.forms;
create policy "public read published forms" on public.forms for select to anon, authenticated
  using (status = 'published');

-- Public respondents may submit to a published form. Owner identity is taken from the form row, not the browser.
drop policy if exists "respondents submit published forms" on public.submissions;
create policy "respondents submit published forms" on public.submissions for insert to anon, authenticated
  with check (
    exists (select 1 from public.forms f where f.id = form_id and f.owner_id = form_owner_id and f.status = 'published')
  );
drop policy if exists "owners read submissions" on public.submissions;
create policy "owners read submissions" on public.submissions for select to authenticated
  using (form_owner_id = auth.uid());
drop policy if exists "owners delete submissions" on public.submissions;
create policy "owners delete submissions" on public.submissions for delete to authenticated
  using (form_owner_id = auth.uid());

-- Saved themes are private to each user.
drop policy if exists "owners manage saved themes" on public.saved_themes;
create policy "owners manage saved themes" on public.saved_themes for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create or replace function public.increment_form_views(form_slug text)
returns void language sql security definer set search_path = public
as $$ update public.forms set views = views + 1 where slug = form_slug and status = 'published'; $$;
grant execute on function public.increment_form_views(text) to anon, authenticated;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists forms_touch_updated_at on public.forms;
create trigger forms_touch_updated_at before update on public.forms for each row execute function public.touch_updated_at();

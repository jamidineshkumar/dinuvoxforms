-- Form assignments and invitation completion for DinuVoX Forms.
create table if not exists public.form_assignments (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.forms(id) on delete cascade,
  form_owner_id uuid not null references auth.users(id) on delete cascade,
  recipient_email text not null,
  invite_token uuid not null unique default gen_random_uuid(),
  status text not null default 'invited' check (status in ('invited','completed','revoked')),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create index if not exists form_assignments_owner_idx on public.form_assignments(form_owner_id, created_at desc);
create index if not exists form_assignments_form_idx on public.form_assignments(form_id, status);
alter table public.form_assignments enable row level security;
drop policy if exists "owners read form assignments" on public.form_assignments;
create policy "owners read form assignments" on public.form_assignments
  for select to authenticated using (form_owner_id = auth.uid());
drop policy if exists "owners create form assignments" on public.form_assignments;
create policy "owners create form assignments" on public.form_assignments
  for insert to authenticated with check (
    form_owner_id = auth.uid()
    and exists (select 1 from public.forms f where f.id = form_id and f.owner_id = auth.uid() and f.status = 'published')
  );
create or replace function public.complete_form_invitation(p_invite_token uuid)
returns void language sql security definer set search_path = public
as $$
  update public.form_assignments
  set status = 'completed', completed_at = now()
  where invite_token = p_invite_token and status = 'invited';
$$;
revoke all on function public.complete_form_invitation(uuid) from public;
grant execute on function public.complete_form_invitation(uuid) to anon, authenticated;

-- ADUSTECH Connect production hardening
-- Apply after the existing setup/migrations. Additive and intended to preserve data.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists connections_set_updated_at on public.connections;
create trigger connections_set_updated_at
before update on public.connections
for each row execute function public.set_updated_at();

create or replace function public.sync_profile_visibility()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set is_visible = new.profile_visible,
      updated_at = now()
  where id = new.user_id;
  return new;
end;
$$;

drop trigger if exists sync_profile_visibility on public.user_preferences;
create trigger sync_profile_visibility
after insert or update of profile_visible on public.user_preferences
for each row execute function public.sync_profile_visibility();

update public.profiles p
set is_visible = coalesce(pref.profile_visible, p.is_visible)
from public.user_preferences pref
where pref.user_id = p.id;

create or replace function public.can_view_profile(profile_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    left join public.user_preferences pref on pref.user_id = p.id
    where p.id = profile_user_id
      and (p.id = auth.uid() or coalesce(pref.profile_visible, p.is_visible))
  );
$$;

revoke all on function public.can_view_profile(uuid) from public;
grant execute on function public.can_view_profile(uuid) to anon, authenticated;

drop policy if exists "visible profiles readable" on public.profiles;
drop policy if exists "profiles respect visibility" on public.profiles;
create policy "profiles respect visibility"
on public.profiles
for select
using (public.can_view_profile(id));

create or replace function public.validate_profile_academic_data()
returns trigger
language plpgsql
as $$
begin
  if new.department_id is not null and not exists (
    select 1
    from public.departments d
    where d.id = new.department_id
      and d.faculty_id = new.faculty_id
  ) then
    raise exception 'Department must belong to the selected faculty';
  end if;
  return new;
end;
$$;

drop trigger if exists validate_profile_academic_data on public.profiles;
create trigger validate_profile_academic_data
before insert or update of faculty_id, department_id on public.profiles
for each row execute function public.validate_profile_academic_data();

-- Connection state changes are handled by validated RPCs.
drop policy if exists "create own request" on public.connections;
drop policy if exists "update connection" on public.connections;
drop policy if exists "connection participant updates disabled" on public.connections;
create policy "connection participant updates disabled"
on public.connections
for update
using (false)
with check (false);

create or replace function public.send_connection_request(target_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
begin
  if auth.uid() is null or target_user_id is null or target_user_id = auth.uid() then
    raise exception 'Invalid connection target';
  end if;

  if exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = target_user_id)
       or (b.blocker_id = target_user_id and b.blocked_id = auth.uid())
  ) then
    raise exception 'Connection is unavailable';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = target_user_id
      and public.can_view_profile(p.id)
  ) then
    raise exception 'Profile is unavailable';
  end if;

  if not coalesce((select allow_requests from public.user_preferences where user_id = target_user_id), true) then
    raise exception 'This student is not accepting connection requests';
  end if;

  if exists (
    select 1
    from public.connections c
    where (
      (c.requester_id = auth.uid() and c.recipient_id = target_user_id)
      or (c.requester_id = target_user_id and c.recipient_id = auth.uid())
    )
    and c.status in ('pending', 'accepted')
  ) then
    raise exception 'A connection already exists';
  end if;

  insert into public.connections(requester_id, recipient_id)
  values (auth.uid(), target_user_id)
  returning id into new_id;

  return new_id;
end;
$$;

create or replace function public.respond_to_connection(
  connection_id uuid,
  next_status public.connection_status
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_row public.connections;
begin
  select * into current_row
  from public.connections
  where id = connection_id
  for update;

  if not found or current_row.recipient_id <> auth.uid() or current_row.status <> 'pending' then
    raise exception 'Connection response is not allowed';
  end if;

  if next_status not in ('accepted', 'declined') then
    raise exception 'Invalid connection response';
  end if;

  update public.connections
  set status = next_status
  where id = connection_id;
end;
$$;

create or replace function public.cancel_connection_request(connection_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.connections
  where id = connection_id
    and requester_id = auth.uid()
    and status = 'pending';

  if not found then
    raise exception 'Request cannot be cancelled';
  end if;
end;
$$;

create or replace function public.remove_connection(connection_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.connections
  where id = connection_id
    and (requester_id = auth.uid() or recipient_id = auth.uid())
    and status = 'accepted';

  if not found then
    raise exception 'Connection cannot be removed';
  end if;
end;
$$;

revoke all on function public.send_connection_request(uuid) from public;
revoke all on function public.respond_to_connection(uuid, public.connection_status) from public;
revoke all on function public.cancel_connection_request(uuid) from public;
revoke all on function public.remove_connection(uuid) from public;
grant execute on function public.send_connection_request(uuid) to authenticated;
grant execute on function public.respond_to_connection(uuid, public.connection_status) to authenticated;
grant execute on function public.cancel_connection_request(uuid) to authenticated;
grant execute on function public.remove_connection(uuid) to authenticated;

-- Avatar bucket and ownership policies.
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "avatar public read" on storage.objects;
drop policy if exists "avatar owner upload" on storage.objects;
drop policy if exists "avatar owner update" on storage.objects;
drop policy if exists "avatar owner delete" on storage.objects;
create policy "avatar public read" on storage.objects
for select using (bucket_id = 'avatars');
create policy "avatar owner upload" on storage.objects
for insert to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatar owner update" on storage.objects
for update to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatar owner delete" on storage.objects
for delete to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create index if not exists profiles_faculty_department_idx on public.profiles(faculty_id, department_id, level);
create index if not exists connections_recipient_status_idx on public.connections(recipient_id, status);
create index if not exists connections_requester_status_idx on public.connections(requester_id, status);
create index if not exists messages_conversation_created_idx on public.messages(conversation_id, created_at desc);
create index if not exists notifications_user_unread_idx on public.notifications(user_id, read_at, created_at desc);

-- Realtime subscriptions required by the application.
do $$
begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null;
end $$;

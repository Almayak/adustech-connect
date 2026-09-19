-- ADUSTECH Connect final production controls
-- Run after 0008_production_hardening.sql.
-- Safe additive migration; preserves existing users and data.

create table if not exists public.study_partner_preferences(
  user_id uuid primary key references public.profiles(id) on delete cascade,
  faculty_id uuid references public.faculties(id),
  department_id uuid references public.departments(id),
  level text,
  courses text[] not null default '{}',
  study_style text,
  availability text,
  enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_roles(
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'user' check(role in ('user','moderator','admin')),
  created_at timestamptz not null default now()
);

alter table public.study_partner_preferences enable row level security;
alter table public.user_roles enable row level security;

drop policy if exists "own study preferences" on public.study_partner_preferences;
create policy "own study preferences" on public.study_partner_preferences for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists "no client role reads" on public.user_roles;
create policy "no client role reads" on public.user_roles for select using(false);

create index if not exists study_partner_enabled_idx on public.study_partner_preferences(enabled, faculty_id, department_id, level);

create or replace function public.is_blocked_between(first_user uuid, second_user uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.blocks b where (b.blocker_id=first_user and b.blocked_id=second_user) or (b.blocker_id=second_user and b.blocked_id=first_user));
$$;
revoke all on function public.is_blocked_between(uuid,uuid) from public;
grant execute on function public.is_blocked_between(uuid,uuid) to authenticated;

create or replace function public.block_user(target_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null or target_user_id is null or target_user_id=auth.uid() then raise exception 'Invalid block target'; end if;
  insert into public.blocks(blocker_id,blocked_id) values(auth.uid(),target_user_id) on conflict do nothing;
  delete from public.connections where (requester_id=auth.uid() and recipient_id=target_user_id) or (requester_id=target_user_id and recipient_id=auth.uid());
end;
$$;
create or replace function public.unblock_user(target_user_id uuid)
returns void language sql security definer set search_path=public as $$
  delete from public.blocks where blocker_id=auth.uid() and blocked_id=target_user_id;
$$;
revoke all on function public.block_user(uuid) from public;
revoke all on function public.unblock_user(uuid) from public;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;

-- Enforce privacy and block checks for message inserts.
drop policy if exists "send own messages" on public.messages;
create policy "send allowed messages" on public.messages for insert to authenticated with check (
  sender_id=auth.uid()
  and exists(select 1 from public.conversation_members mine where mine.conversation_id=messages.conversation_id and mine.user_id=auth.uid())
  and not exists(select 1 from public.conversation_members other where other.conversation_id=messages.conversation_id and other.user_id<>auth.uid() and public.is_blocked_between(auth.uid(),other.user_id))
  and not exists(select 1 from public.conversation_members other join public.user_preferences pref on pref.user_id=other.user_id where other.conversation_id=messages.conversation_id and other.user_id<>auth.uid() and coalesce(pref.allow_messages,'connections')='nobody')
);

-- Remove duplicate matches in either user order, then enforce canonical uniqueness.
delete from public.matches m where m.id in(
  select id from(select id,row_number() over(partition by least(user_a_id,user_b_id),greatest(user_a_id,user_b_id) order by created_at,id) rn from public.matches) d where d.rn>1
);
create unique index if not exists matches_canonical_pair_idx on public.matches(least(user_a_id,user_b_id),greatest(user_a_id,user_b_id));

create or replace function public.create_notification(recipient_id uuid, notification_type text, notification_payload jsonb default '{}')
returns void language plpgsql security definer set search_path=public as $$
begin
  if recipient_id is null or recipient_id=auth.uid() then return; end if;
  if not coalesce((select notifications_enabled from public.user_preferences where user_id=recipient_id),true) then return; end if;
  insert into public.notifications(user_id,type,payload) values(recipient_id,notification_type,coalesce(notification_payload,'{}'));
end;
$$;
revoke all on function public.create_notification(uuid,text,jsonb) from public;
grant execute on function public.create_notification(uuid,text,jsonb) to authenticated;

drop trigger if exists study_partner_preferences_set_updated_at on public.study_partner_preferences;
create trigger study_partner_preferences_set_updated_at before update on public.study_partner_preferences for each row execute function public.set_updated_at();

do $$ begin alter publication supabase_realtime add table public.connections; exception when duplicate_object then null; end $$;

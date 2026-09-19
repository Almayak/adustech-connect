-- ADUSTECH Connect one-time Supabase setup
-- Run this file once in a fresh Supabase project.
-- If migrations 0001-0007 were already run, do not run this duplicate setup.

create extension if not exists pgcrypto;

create table public.faculties(id uuid primary key default gen_random_uuid(),name text not null unique,created_at timestamptz not null default now());
create table public.departments(id uuid primary key default gen_random_uuid(),faculty_id uuid not null references public.faculties(id) on delete cascade,name text not null,created_at timestamptz not null default now(),unique(faculty_id,name));
create table public.profiles(id uuid primary key references auth.users(id) on delete cascade,username text not null unique,full_name text not null,faculty_id uuid references public.faculties(id),department_id uuid references public.departments(id),level text,gender text,bio text,avatar_url text,is_visible boolean not null default true,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.interests(id uuid primary key default gen_random_uuid(),name text not null unique);
create table public.user_interests(user_id uuid references public.profiles(id) on delete cascade,interest_id uuid references public.interests(id) on delete cascade,primary key(user_id,interest_id));
create type public.connection_status as enum('pending','accepted','declined','blocked');
create table public.connections(id uuid primary key default gen_random_uuid(),requester_id uuid not null references public.profiles(id) on delete cascade,recipient_id uuid not null references public.profiles(id) on delete cascade,status public.connection_status not null default 'pending',created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(requester_id<>recipient_id),unique(requester_id,recipient_id));
create table public.matches(id uuid primary key default gen_random_uuid(),user_a_id uuid not null references public.profiles(id) on delete cascade,user_b_id uuid not null references public.profiles(id) on delete cascade,created_at timestamptz not null default now(),unique(user_a_id,user_b_id),check(user_a_id<>user_b_id));
create table public.conversations(id uuid primary key default gen_random_uuid(),created_at timestamptz not null default now());
create table public.conversation_members(conversation_id uuid references public.conversations(id) on delete cascade,user_id uuid references public.profiles(id) on delete cascade,joined_at timestamptz not null default now(),primary key(conversation_id,user_id));
create table public.messages(id uuid primary key default gen_random_uuid(),conversation_id uuid not null references public.conversations(id) on delete cascade,sender_id uuid not null references public.profiles(id) on delete cascade,content text not null check(length(trim(content))>0 and length(content)<=5000),created_at timestamptz not null default now());
create table public.communities(id uuid primary key default gen_random_uuid(),creator_id uuid not null references public.profiles(id),name text not null,description text,category text,created_at timestamptz not null default now());
create table public.community_members(community_id uuid references public.communities(id) on delete cascade,user_id uuid references public.profiles(id) on delete cascade,joined_at timestamptz not null default now(),primary key(community_id,user_id));
create table public.notifications(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,type text not null,payload jsonb not null default '{}',read_at timestamptz,created_at timestamptz not null default now());
create table public.blocks(blocker_id uuid references public.profiles(id) on delete cascade,blocked_id uuid references public.profiles(id) on delete cascade,created_at timestamptz not null default now(),primary key(blocker_id,blocked_id),check(blocker_id<>blocked_id));
create table public.reports(id uuid primary key default gen_random_uuid(),reporter_id uuid not null references public.profiles(id),reported_user_id uuid references public.profiles(id),message_id uuid references public.messages(id),reason text not null,details text,created_at timestamptz not null default now());
create table public.user_preferences(user_id uuid primary key references public.profiles(id) on delete cascade,profile_visible boolean not null default true,allow_messages text not null default 'connections',allow_requests boolean not null default true,show_online boolean not null default true,notifications_enabled boolean not null default true);
create table public.chat_preferences(user_id uuid primary key references public.profiles(id) on delete cascade,theme text not null default 'default');

insert into public.faculties(name) values
('Faculty of Agriculture and Agriculture Technology'),('Faculty of Computing and Mathematical Science'),('Faculty of Earth and Environmental Science'),('Faculty of Engineering'),('Faculty of Science'),('Faculty of Science and Technical Education') on conflict(name) do nothing;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id,username,full_name) values(new.id,coalesce(nullif(new.raw_user_meta_data->>'username',''),'user_'||substr(new.id::text,1,8)),coalesce(nullif(new.raw_user_meta_data->>'full_name',''),'New student')); insert into public.user_preferences(user_id) values(new.id); insert into public.chat_preferences(user_id) values(new.id); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security; alter table public.faculties enable row level security; alter table public.departments enable row level security; alter table public.user_interests enable row level security; alter table public.connections enable row level security; alter table public.matches enable row level security; alter table public.conversations enable row level security; alter table public.conversation_members enable row level security; alter table public.messages enable row level security; alter table public.communities enable row level security; alter table public.community_members enable row level security; alter table public.notifications enable row level security; alter table public.blocks enable row level security; alter table public.reports enable row level security; alter table public.user_preferences enable row level security; alter table public.chat_preferences enable row level security;

create policy "faculties readable" on public.faculties for select using(true);
create policy "departments readable" on public.departments for select using(true);
create policy "visible profiles readable" on public.profiles for select using(is_visible=true or id=auth.uid());
create policy "own profile update" on public.profiles for update using(id=auth.uid()) with check(id=auth.uid());
create policy "own interests" on public.user_interests for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "connection participants" on public.connections for select using(requester_id=auth.uid() or recipient_id=auth.uid());
create policy "create own request" on public.connections for insert with check(requester_id=auth.uid());
create policy "update connection" on public.connections for update using(requester_id=auth.uid() or recipient_id=auth.uid());
create policy "match participants" on public.matches for select using(user_a_id=auth.uid() or user_b_id=auth.uid());
create policy "conversation members" on public.conversation_members for select using(user_id=auth.uid());
create policy "member messages read" on public.messages for select using(exists(select 1 from public.conversation_members cm where cm.conversation_id=messages.conversation_id and cm.user_id=auth.uid()));
create policy "send own messages" on public.messages for insert with check(sender_id=auth.uid() and exists(select 1 from public.conversation_members cm where cm.conversation_id=messages.conversation_id and cm.user_id=auth.uid()));
create policy "read member conversations" on public.conversations for select using(exists(select 1 from public.conversation_members cm where cm.conversation_id=conversations.id and cm.user_id=auth.uid()));
create policy "read conversation members" on public.conversation_members for select using(exists(select 1 from public.conversation_members mine where mine.conversation_id=conversation_members.conversation_id and mine.user_id=auth.uid()));
create policy "read own sent messages" on public.messages for select using(sender_id=auth.uid());
create policy "visible communities readable" on public.communities for select using(true);
create policy "authenticated users create communities" on public.communities for insert with check(creator_id=auth.uid());
create policy "creators update communities" on public.communities for update using(creator_id=auth.uid()) with check(creator_id=auth.uid());
create policy "community membership readable" on public.community_members for select using(true);
create policy "users join communities" on public.community_members for insert with check(user_id=auth.uid());
create policy "users leave communities" on public.community_members for delete using(user_id=auth.uid());
create policy "own notifications" on public.notifications for select using(user_id=auth.uid());
create policy "own notification update" on public.notifications for update using(user_id=auth.uid());
create policy "own preferences" on public.user_preferences for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "own chat preferences" on public.chat_preferences for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "own block management" on public.blocks for all using(blocker_id=auth.uid()) with check(blocker_id=auth.uid());
create policy "own reports" on public.reports for insert with check(reporter_id=auth.uid());

create or replace function public.start_private_conversation(other_user_id uuid) returns uuid language plpgsql security definer set search_path=public as $$ declare conversation_id uuid; begin if auth.uid() is null or other_user_id is null or other_user_id=auth.uid() then raise exception 'Invalid conversation participants'; end if; if not exists(select 1 from public.connections c where c.status='accepted' and ((c.requester_id=auth.uid() and c.recipient_id=other_user_id) or (c.requester_id=other_user_id and c.recipient_id=auth.uid()))) then raise exception 'Messaging is available only between accepted connections'; end if; select cm.conversation_id into conversation_id from public.conversation_members cm join public.conversation_members other_cm on other_cm.conversation_id=cm.conversation_id and other_cm.user_id=other_user_id where cm.user_id=auth.uid() limit 1; if conversation_id is null then insert into public.conversations default values returning id into conversation_id; insert into public.conversation_members(conversation_id,user_id) values(conversation_id,auth.uid()),(conversation_id,other_user_id); end if; return conversation_id; end; $$;
revoke all on function public.start_private_conversation(uuid) from public; grant execute on function public.start_private_conversation(uuid) to authenticated;

create or replace function public.create_notification(recipient_id uuid,notification_type text,notification_payload jsonb default '{}') returns void language plpgsql security definer set search_path=public as $$ begin if recipient_id is null or recipient_id=auth.uid() then return; end if; insert into public.notifications(user_id,type,payload) values(recipient_id,notification_type,coalesce(notification_payload,'{}')); end; $$;
revoke all on function public.create_notification(uuid,text,jsonb) from public; grant execute on function public.create_notification(uuid,text,jsonb) to authenticated;
create or replace function public.notify_connection_request() returns trigger language plpgsql security definer set search_path=public as $$ begin if new.status='pending' then perform public.create_notification(new.recipient_id,'connection_request',jsonb_build_object('message','You received a new connection request.','connection_id',new.id)); end if; return new; end; $$;
create trigger on_connection_request after insert on public.connections for each row execute function public.notify_connection_request();
create or replace function public.notify_connection_update() returns trigger language plpgsql security definer set search_path=public as $$ begin if old.status is distinct from new.status and new.status in('accepted','declined') then perform public.create_notification(new.requester_id,'connection_'||new.status,jsonb_build_object('message','Your connection request was '||new.status||'.','connection_id',new.id)); end if; return new; end; $$;
create trigger on_connection_update after update of status on public.connections for each row execute function public.notify_connection_update();
create or replace function public.notify_message() returns trigger language plpgsql security definer set search_path=public as $$ declare recipient uuid; begin select cm.user_id into recipient from public.conversation_members cm where cm.conversation_id=new.conversation_id and cm.user_id<>new.sender_id limit 1; perform public.create_notification(recipient,'new_message',jsonb_build_object('message','You received a new message.','conversation_id',new.conversation_id)); return new; end; $$;
create trigger on_new_message after insert on public.messages for each row execute function public.notify_message();

do $$ begin alter publication supabase_realtime add table public.messages; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.notifications; exception when duplicate_object then null; end $$;

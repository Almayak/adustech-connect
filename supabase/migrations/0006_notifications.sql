-- Activity notifications for requests, accepted connections, messages, and communities.
create or replace function public.create_notification(recipient_id uuid, notification_type text, notification_payload jsonb default '{}')
returns void language plpgsql security definer set search_path=public as $$
begin
  if recipient_id is null or recipient_id = auth.uid() then return; end if;
  insert into public.notifications(user_id,type,payload) values(recipient_id,notification_type,coalesce(notification_payload,'{}'));
end; $$;
revoke all on function public.create_notification(uuid,text,jsonb) from public;
grant execute on function public.create_notification(uuid,text,jsonb) to authenticated;

create or replace function public.notify_connection_request() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status='pending' then perform public.create_notification(new.recipient_id,'connection_request',jsonb_build_object('message','You received a new connection request.','connection_id',new.id)); end if;
  return new;
end; $$;
drop trigger if exists on_connection_request on public.connections;
create trigger on_connection_request after insert on public.connections for each row execute function public.notify_connection_request();

create or replace function public.notify_connection_update() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if old.status is distinct from new.status and new.status in ('accepted','declined') then perform public.create_notification(new.requester_id,'connection_'||new.status,jsonb_build_object('message','Your connection request was '||new.status||'.','connection_id',new.id)); end if;
  return new;
end; $$;
drop trigger if exists on_connection_update on public.connections;
create trigger on_connection_update after update of status on public.connections for each row execute function public.notify_connection_update();

create or replace function public.notify_message() returns trigger language plpgsql security definer set search_path=public as $$
declare recipient uuid;
begin
  select cm.user_id into recipient from public.conversation_members cm where cm.conversation_id=new.conversation_id and cm.user_id<>new.sender_id limit 1;
  perform public.create_notification(recipient,'new_message',jsonb_build_object('message','You received a new message.','conversation_id',new.conversation_id));
  return new;
end; $$;
drop trigger if exists on_new_message on public.messages;
create trigger on_new_message after insert on public.messages for each row execute function public.notify_message();

do $$ begin alter publication supabase_realtime add table public.notifications; exception when duplicate_object then null; end $$;

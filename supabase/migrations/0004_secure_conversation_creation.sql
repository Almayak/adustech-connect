-- Replace broad member-insert policies with a server-side accepted-connection check.
drop policy if exists "create conversation as member" on public.conversations;
drop policy if exists "add accepted connection member" on public.conversation_members;
drop policy if exists "join own conversation" on public.conversation_members;

create or replace function public.start_private_conversation(other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  conversation_id uuid;
begin
  if auth.uid() is null or other_user_id is null or other_user_id = auth.uid() then
    raise exception 'Invalid conversation participants';
  end if;

  if not exists (
    select 1 from public.connections c
    where c.status = 'accepted'
      and ((c.requester_id = auth.uid() and c.recipient_id = other_user_id)
        or (c.requester_id = other_user_id and c.recipient_id = auth.uid()))
  ) then
    raise exception 'Messaging is available only between accepted connections';
  end if;

  select cm.conversation_id into conversation_id
  from public.conversation_members cm
  join public.conversation_members other_cm
    on other_cm.conversation_id = cm.conversation_id
   and other_cm.user_id = other_user_id
  where cm.user_id = auth.uid()
  limit 1;

  if conversation_id is null then
    insert into public.conversations default values returning id into conversation_id;
    insert into public.conversation_members(conversation_id, user_id)
    values (conversation_id, auth.uid()), (conversation_id, other_user_id);
  end if;

  return conversation_id;
end;
$$;

revoke all on function public.start_private_conversation(uuid) from public;
grant execute on function public.start_private_conversation(uuid) to authenticated;

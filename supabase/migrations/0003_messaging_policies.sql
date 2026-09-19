-- Secure messaging foundation for accepted connections.
-- Run after 0001_initial.sql.

create policy "create conversation as member" on public.conversations
  for insert with check (auth.uid() is not null);

create policy "read member conversations" on public.conversations
  for select using (exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = conversations.id and cm.user_id = auth.uid()
  ));

create policy "read conversation members" on public.conversation_members
  for select using (exists (
    select 1 from public.conversation_members mine
    where mine.conversation_id = conversation_members.conversation_id
      and mine.user_id = auth.uid()
  ));

create policy "add accepted connection member" on public.conversation_members
  for insert with check (
    user_id = auth.uid()
    or exists (
      select 1 from public.conversation_members mine
      where mine.conversation_id = conversation_members.conversation_id
        and mine.user_id = auth.uid()
    )
  );

create policy "read own sent messages" on public.messages
  for select using (sender_id = auth.uid());

-- Enable browser subscriptions when the project has not already enabled them.
do $$
begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then
  null;
end $$;

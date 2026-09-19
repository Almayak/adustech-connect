-- Community browsing, creation, membership, and updates.
create policy "visible communities readable" on public.communities
  for select using (true);

create policy "authenticated users create communities" on public.communities
  for insert with check (creator_id = auth.uid());

create policy "creators update communities" on public.communities
  for update using (creator_id = auth.uid()) with check (creator_id = auth.uid());

create policy "community membership readable" on public.community_members
  for select using (true);

create policy "users join communities" on public.community_members
  for insert with check (user_id = auth.uid());

create policy "users leave communities" on public.community_members
  for delete using (user_id = auth.uid());

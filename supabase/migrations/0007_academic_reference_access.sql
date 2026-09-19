-- Make public faculty reference data readable to authenticated clients.
alter table public.faculties enable row level security;
create policy "faculties readable" on public.faculties for select using (true);
alter table public.departments enable row level security;
create policy "departments readable" on public.departments for select using (true);

-- Verified against the official ADUSTECH website on 2026-09-19.
-- Source: https://kustwudil.edu.ng/node/226
-- Academic Programmes page: https://kustwudil.edu.ng/node/114
-- The official page confirms six faculties. It does not expose a readable
-- department list in the retrieved content, so departments are intentionally
-- not seeded until verified.

insert into public.faculties (name) values
  ('Faculty of Agriculture and Agriculture Technology'),
  ('Faculty of Computing and Mathematical Science'),
  ('Faculty of Earth and Environmental Science'),
  ('Faculty of Engineering'),
  ('Faculty of Science'),
  ('Faculty of Science and Technical Education')
on conflict (name) do nothing;

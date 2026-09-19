# ADUSTECH Connect

ADUSTECH Connect is an independent student-focused social, academic, and connection platform for students of Aliko Dangote University of Science and Technology (ADUSTECH), Wudil.

## Current implementation

- React + Vite + TypeScript
- React Router navigation
- Supabase Auth client with persistent sessions
- Protected authenticated routes
- Responsive desktop and mobile navigation
- Initial Supabase schema and Row Level Security policies
- Landing, login, signup, discover, matches, messages, communities, profile, settings, and 404 routes
- No fake users, statistics, credentials, messages, or university endorsements

## Local setup

```bash
npm install
cp .env.example .env.local
npm run dev
```

Set these public frontend variables in `.env.local`:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=your-anon-key
```

Apply `supabase/migrations/0001_initial.sql` in the Supabase SQL Editor. Do not put service-role keys or AI provider secrets in frontend variables.

## Important data note

Faculty and department reference data is intentionally not seeded until current information can be verified from reliable official university sources. No academic data has been invented.

## Platform disclaimer

ADUSTECH Connect is an independent student platform and is not affiliated with or officially endorsed by ADUSTECH unless otherwise stated.

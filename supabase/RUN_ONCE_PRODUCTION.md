# One-time Supabase production setup

If the original all-in-one SQL was already run, execute only:

1. `supabase/migrations/0008_production_hardening.sql`
2. `supabase/migrations/0009_complete_production_controls.sql`

For a fresh Supabase project, execute migrations `0001` through `0009` in filename order.

Configure Supabase Auth:

- Local site URL: `http://localhost:5173`
- Local reset URL: `http://localhost:5173/reset-password`
- Production site URL: your deployed HTTPS domain
- Production reset URL: `https://YOUR_DOMAIN/reset-password`

Required Vercel variables:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Never expose a service-role key in frontend variables. The `avatars` Storage bucket is created by migration `0008`. The official ADUSTECH source confirms six faculties; departments remain unseeded until verified from a reliable official source.

import {createClient} from '@supabase/supabase-js';

const rawUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const publishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

// Accept the project URL even if /rest/v1/ was accidentally pasted into Vercel.
const url = rawUrl?.replace(/\/rest\/v1\/?$/, '').replace(/\/$/, '');
const key = publishableKey || anonKey;

export const supabase = url && key
  ? createClient(url, key, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    })
  : null;

export const isSupabaseConfigured = Boolean(supabase);
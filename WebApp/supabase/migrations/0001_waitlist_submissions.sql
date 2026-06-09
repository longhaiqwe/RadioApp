create table if not exists public.waitlist_submissions (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  source text not null check (source in ('recognition', 'player', 'settings')),
  station_id text,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.waitlist_submissions enable row level security;

create index if not exists waitlist_submissions_created_at_idx
  on public.waitlist_submissions (created_at desc);

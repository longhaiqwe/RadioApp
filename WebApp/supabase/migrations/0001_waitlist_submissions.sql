create table if not exists public.waitlist_submissions (
  id uuid primary key default gen_random_uuid(),
  email text not null unique check (char_length(email) <= 320),
  source text not null check (source in ('recognition', 'player', 'settings')),
  station_id text check (station_id is null or char_length(station_id) <= 128),
  user_agent text check (user_agent is null or char_length(user_agent) <= 512),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- RLS intentionally has no anon/public policies; writes use the server service role.
alter table public.waitlist_submissions enable row level security;

create index if not exists waitlist_submissions_created_at_idx
  on public.waitlist_submissions (created_at desc);

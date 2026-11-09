-- SeñasGo: esquema relacional normalizado para Supabase/PostgreSQL.
-- Cada tabla tiene una PK; las relaciones usan FK con integridad referencial.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Catálogo (datos de referencia)
-- ---------------------------------------------------------------------------
create table if not exists public.lessons (
  id          text primary key,
  title       text not null,
  description text not null default '',
  position    integer not null check (position >= 0)
);

create table if not exists public.signs (
  id          text primary key,
  lesson_id   text not null references public.lessons(id) on delete restrict,
  name        text not null,
  description text not null default '',
  category    text not null,
  position    integer not null check (position >= 0),
  unique (lesson_id, position)
);

create index if not exists signs_lesson_id_idx on public.signs(lesson_id);

-- ---------------------------------------------------------------------------
-- Datos por usuario. user_id referencia auth.users (Supabase Auth).
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  username   text not null default 'Usuario',
  xp         integer not null default 0 check (xp >= 0),
  level      integer not null default 1 check (level >= 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_signs (
  user_id    uuid not null references auth.users(id) on delete cascade,
  sign_id    text not null references public.signs(id) on delete restrict,
  learned_at timestamptz not null default now(),
  primary key (user_id, sign_id)
);

create table if not exists public.attempts (
  id                bigint generated always as identity primary key,
  user_id           uuid not null references auth.users(id) on delete cascade,
  sign_id           text not null references public.signs(id) on delete restrict,
  client_attempt_id uuid not null,
  correct           boolean not null,
  created_at        timestamptz not null default now(),
  unique (user_id, client_attempt_id)
);

create index if not exists attempts_user_created_idx
  on public.attempts(user_id, created_at desc);

create table if not exists public.game_state (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  streak_days integer not null default 0 check (streak_days >= 0),
  streak_date date,
  best_streak integer not null default 0 check (best_streak >= 0),
  freezes     integer not null default 2 check (freezes >= 0),
  updated_at  timestamptz not null default now()
);

create table if not exists public.challenges (
  id        text primary key,
  title     text not null,
  target    integer not null check (target > 0),
  reward_xp integer not null check (reward_xp >= 0)
);

create table if not exists public.user_challenges (
  user_id      uuid not null references auth.users(id) on delete cascade,
  challenge_id text not null references public.challenges(id) on delete restrict,
  progress     integer not null default 0 check (progress >= 0),
  claimed_at   timestamptz,
  updated_at   timestamptz not null default now(),
  primary key (user_id, challenge_id)
);

create table if not exists public.chests (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  rarity       text not null check (rarity in ('common', 'rare', 'epic')),
  reward_type  text not null,
  reward_value integer not null default 0 check (reward_value >= 0),
  source_type  text not null,
  source_id    text not null,
  opened_at    timestamptz not null default now(),
  unique (user_id, source_type, source_id)
);

create index if not exists chests_user_idx on public.chests(user_id);

create table if not exists public.preferences (
  user_id        uuid primary key references auth.users(id) on delete cascade,
  daily_goal     integer not null default 10 check (daily_goal between 5 and 30),
  appearance     text not null default 'system'
                 check (appearance in ('dark', 'light', 'system')),
  reminder_weekday smallint check (reminder_weekday between 1 and 7),
  reminder_hour  smallint not null default 19 check (reminder_hour between 0 and 23),
  reminder_minute smallint not null default 0 check (reminder_minute between 0 and 59),
  updated_at     timestamptz not null default now()
);

create table if not exists public.sync_events (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  device_id       text not null,
  event_type      text not null,
  payload         jsonb not null default '{}'::jsonb,
  idempotency_key text not null,
  created_at      timestamptz not null default now(),
  unique (user_id, idempotency_key)
);

-- ---------------------------------------------------------------------------
-- Row Level Security: cada usuario solo accede a sus filas.
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.user_signs enable row level security;
alter table public.attempts enable row level security;
alter table public.game_state enable row level security;
alter table public.user_challenges enable row level security;
alter table public.chests enable row level security;
alter table public.preferences enable row level security;
alter table public.sync_events enable row level security;
alter table public.lessons enable row level security;
alter table public.signs enable row level security;
alter table public.challenges enable row level security;

create policy "catalog_read_lessons" on public.lessons
  for select using (true);
create policy "catalog_read_signs" on public.signs
  for select using (true);
create policy "catalog_read_challenges" on public.challenges
  for select using (true);

create policy "own_profile" on public.profiles
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "own_signs" on public.user_signs
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "own_attempts" on public.attempts
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "own_game" on public.game_state
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "own_challenges" on public.user_challenges
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "own_chests" on public.chests
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "own_preferences" on public.preferences
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "own_sync_events" on public.sync_events
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- updated_at automático.
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists game_touch on public.game_state;
create trigger game_touch before update on public.game_state
for each row execute function public.touch_updated_at();

drop trigger if exists preferences_touch on public.preferences;
create trigger preferences_touch before update on public.preferences
for each row execute function public.touch_updated_at();

drop trigger if exists user_challenges_touch on public.user_challenges;
create trigger user_challenges_touch before update on public.user_challenges
for each row execute function public.touch_updated_at();

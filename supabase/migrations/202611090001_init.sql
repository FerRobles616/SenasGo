-- SeñasGo: esquema relacional normalizado (3FN) para Supabase/PostgreSQL.
--
-- Reglas del diseño:
--   * Toda tabla tiene PK. Las tablas puente usan PK compuesta.
--   * Toda relación es una FK con su regla ON DELETE explícita.
--   * Nada derivable se guarda: el nivel sale de la XP, la categoría de una
--     seña sale de su lección y el premio de un cofre sale del catálogo.
--   * Catálogo (categorías, lecciones, señas, retos, cofres): solo lectura
--     para la app. Datos del usuario: cada cuenta ve solo sus filas (RLS).
--
-- Ejecutar una sola vez en un proyecto nuevo (SQL Editor), y luego seed.sql.

-- ═══════════════════════════ CATÁLOGO ═══════════════════════════

create table public.categories (
  id    text primary key,                    -- 'greetings', 'numbers', 'basics'
  name  text not null unique
);

create table public.lessons (
  id          text primary key,              -- 'leccion_saludos'
  category_id text not null
              references public.categories(id) on delete restrict,
  title       text not null,
  description text not null default '',
  difficulty  smallint not null default 1 check (difficulty between 1 and 5),
  position    smallint not null unique check (position > 0)
);

create table public.signs (
  id          text primary key,              -- 'saludo_hola'
  lesson_id   text not null
              references public.lessons(id) on delete restrict,
  name        text not null,
  description text not null default '',
  position    smallint not null check (position > 0),
  unique (lesson_id, position)
);

create table public.challenges (
  id        text primary key,                -- 'daily_xp'
  title     text not null,
  period    text not null check (period in ('daily', 'weekly', 'once')),
  target    integer not null check (target > 0),
  reward_xp integer not null check (reward_xp >= 0)
);

-- Cofre que se abre al completar una lección (uno por lección).
create table public.chests (
  lesson_id      text primary key
                 references public.lessons(id) on delete cascade,
  rarity         text not null check (rarity in ('common', 'rare', 'epic')),
  reward_xp      integer not null check (reward_xp >= 0),
  reward_freezes smallint not null default 0 check (reward_freezes >= 0)
);

-- ═══════════════════════════ USUARIO ═══════════════════════════

-- Perfil 1:1 con la cuenta de Supabase Auth. Se crea solo al registrarse.
create table public.profiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  username   text not null check (char_length(username) between 1 and 24),
  xp         integer not null default 0 check (xp >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Preferencias 1:1 con el perfil.
create table public.preferences (
  user_id          uuid primary key
                   references public.profiles(user_id) on delete cascade,
  daily_goal       smallint not null default 10
                   check (daily_goal between 5 and 30),
  appearance       text not null default 'dark'
                   check (appearance in ('dark', 'light', 'system')),
  reminder_weekday smallint check (reminder_weekday between 1 and 7),
  reminder_hour    smallint not null default 19
                   check (reminder_hour between 0 and 23),
  reminder_minute  smallint not null default 0
                   check (reminder_minute between 0 and 59),
  updated_at       timestamptz not null default now()
);

-- Racha 1:1 con el perfil.
create table public.streaks (
  user_id            uuid primary key
                     references public.profiles(user_id) on delete cascade,
  current_days       integer not null default 0 check (current_days >= 0),
  last_practice_date date,
  best_days          integer not null default 0 check (best_days >= 0),
  freezes            smallint not null default 2 check (freezes >= 0),
  updated_at         timestamptz not null default now(),
  check (best_days >= current_days)
);

-- Señas aprendidas (N:M perfil–seña).
create table public.user_signs (
  user_id    uuid not null
             references public.profiles(user_id) on delete cascade,
  sign_id    text not null references public.signs(id) on delete restrict,
  learned_at timestamptz not null default now(),
  primary key (user_id, sign_id)
);

-- Historial de intentos de práctica (1:N perfil–intentos).
create table public.attempts (
  id           bigint generated always as identity primary key,
  user_id      uuid not null
               references public.profiles(user_id) on delete cascade,
  sign_id      text not null references public.signs(id) on delete restrict,
  correct      boolean not null,
  attempted_at timestamptz not null,
  unique (user_id, sign_id, attempted_at)  -- evita duplicar al resincronizar
);

-- Retos reclamados (N:M perfil–reto).
create table public.user_challenges (
  user_id      uuid not null
               references public.profiles(user_id) on delete cascade,
  challenge_id text not null
               references public.challenges(id) on delete restrict,
  claimed_at   timestamptz not null default now(),
  primary key (user_id, challenge_id)
);

-- Cofres abiertos (N:M perfil–cofre).
create table public.user_chests (
  user_id   uuid not null
            references public.profiles(user_id) on delete cascade,
  lesson_id text not null references public.chests(lesson_id) on delete restrict,
  opened_at timestamptz not null default now(),
  primary key (user_id, lesson_id)
);

-- Índices para las FK que no encabezan una PK.
create index lessons_category_idx on public.lessons(category_id);
create index signs_lesson_idx on public.signs(lesson_id);
create index user_signs_sign_idx on public.user_signs(sign_id);
create index attempts_user_time_idx on public.attempts(user_id, attempted_at desc);
create index attempts_sign_idx on public.attempts(sign_id);
create index user_challenges_challenge_idx on public.user_challenges(challenge_id);
create index user_chests_lesson_idx on public.user_chests(lesson_id);

-- ═══════════════════ ALTA AUTOMÁTICA DEL PERFIL ═══════════════════
-- Al registrarse, Supabase crea la fila en auth.users; este trigger crea el
-- perfil, las preferencias y la racha con el nombre que se escribió en la app.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (user_id, username)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'username'), ''),
             'Usuario')
  );
  insert into public.preferences (user_id) values (new.id);
  insert into public.streaks (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ═══════════════════════════ updated_at ═══════════════════════════

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();
create trigger preferences_touch before update on public.preferences
  for each row execute function public.touch_updated_at();
create trigger streaks_touch before update on public.streaks
  for each row execute function public.touch_updated_at();

-- ═══════════════════ SEGURIDAD (Row Level Security) ═══════════════════

alter table public.categories      enable row level security;
alter table public.lessons         enable row level security;
alter table public.signs           enable row level security;
alter table public.challenges      enable row level security;
alter table public.chests          enable row level security;
alter table public.profiles        enable row level security;
alter table public.preferences     enable row level security;
alter table public.streaks         enable row level security;
alter table public.user_signs      enable row level security;
alter table public.attempts        enable row level security;
alter table public.user_challenges enable row level security;
alter table public.user_chests     enable row level security;

-- Catálogo: lo lee cualquier cuenta iniciada; solo el administrador lo
-- modifica (desde el panel, que no pasa por RLS).
create policy categories_read on public.categories
  for select to authenticated using (true);
create policy lessons_read on public.lessons
  for select to authenticated using (true);
create policy signs_read on public.signs
  for select to authenticated using (true);
create policy challenges_read on public.challenges
  for select to authenticated using (true);
create policy chests_read on public.chests
  for select to authenticated using (true);

-- Datos del usuario: cada cuenta solo ve y cambia sus propias filas.
create policy profiles_own on public.profiles
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy preferences_own on public.preferences
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy streaks_own on public.streaks
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy user_signs_own on public.user_signs
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy attempts_own on public.attempts
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy user_challenges_own on public.user_challenges
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy user_chests_own on public.user_chests
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- SeñasGo: completa la normalización.
--
-- Ejecutar en el SQL Editor DESPUÉS de 202611090001 y 202611090002.
--
-- 1) 3FN en cofres: el premio dependía de la rareza y no de la lección
--    (lesson_id → rarity → reward_xp, reward_freezes). El premio pasa a la
--    tabla chest_rarities y chests solo referencia la rareza.
-- 2) Los valores fijos que estaban como texto con CHECK pasan a tablas de
--    catálogo con PK, referenciadas por FK (categoría y estado de reportes,
--    período de retos y modo de apariencia).
--
-- Las PK de los catálogos usan los mismos códigos que ya guarda la app, así
-- que los datos existentes siguen siendo válidos y la app no cambia.

begin;

-- ═══════════════════════ Catálogos nuevos ═══════════════════════

create table public.chest_rarities (
  id             text primary key,            -- 'common', 'rare', 'epic'
  name           text not null unique,
  reward_xp      integer not null check (reward_xp >= 0),
  reward_freezes smallint not null default 0 check (reward_freezes >= 0)
);

create table public.challenge_periods (
  id   text primary key,                      -- 'daily', 'weekly', 'once'
  name text not null unique
);

create table public.appearance_modes (
  id   text primary key,                      -- 'dark', 'light', 'system'
  name text not null unique
);

create table public.support_categories (
  id   text primary key,                      -- 'bug', 'idea', 'content', 'comment'
  name text not null unique
);

create table public.ticket_statuses (
  id   text primary key,                      -- 'open', 'in_progress', 'resolved'
  name text not null unique
);

insert into public.chest_rarities (id, name, reward_xp, reward_freezes) values
  ('common', 'Común', 20, 0),
  ('rare',   'Rara',  30, 0),
  ('epic',   'Épica', 40, 1);

insert into public.challenge_periods (id, name) values
  ('daily', 'Diario'), ('weekly', 'Semanal'), ('once', 'Una sola vez');

insert into public.appearance_modes (id, name) values
  ('dark', 'Oscuro'), ('light', 'Claro'), ('system', 'Según el sistema');

insert into public.support_categories (id, name) values
  ('bug', 'Problema'), ('idea', 'Idea'),
  ('content', 'Contenido'), ('comment', 'Comentario');

insert into public.ticket_statuses (id, name) values
  ('open', 'Abierto'), ('in_progress', 'En curso'), ('resolved', 'Resuelto');

-- ═══════════════════════ Cofres (3FN) ═══════════════════════

alter table public.chests drop constraint if exists chests_rarity_check;
alter table public.chests
  add constraint chests_rarity_fk
  foreign key (rarity) references public.chest_rarities(id) on delete restrict;
alter table public.chests rename column rarity to rarity_id;
alter table public.chests drop column reward_xp;
alter table public.chests drop column reward_freezes;

-- ═══════════════════════ Retos ═══════════════════════

alter table public.challenges drop constraint if exists challenges_period_check;
alter table public.challenges rename column period to period_id;
alter table public.challenges
  add constraint challenges_period_fk
  foreign key (period_id) references public.challenge_periods(id) on delete restrict;

-- ═══════════════════════ Preferencias ═══════════════════════
-- La columna conserva su nombre ("appearance") porque la app la usa.

alter table public.preferences drop constraint if exists preferences_appearance_check;
alter table public.preferences
  add constraint preferences_appearance_fk
  foreign key (appearance) references public.appearance_modes(id) on delete restrict;

-- ═══════════════════════ Reportes ═══════════════════════
-- Se conservan los nombres "category" y "status" porque la app los usa.

alter table public.support_tickets drop constraint if exists support_tickets_category_check;
alter table public.support_tickets drop constraint if exists support_tickets_status_check;
alter table public.support_tickets
  add constraint support_tickets_category_fk
  foreign key (category) references public.support_categories(id) on delete restrict;
alter table public.support_tickets
  add constraint support_tickets_status_fk
  foreign key (status) references public.ticket_statuses(id) on delete restrict;

create index challenges_period_idx on public.challenges(period_id);
create index chests_rarity_idx on public.chests(rarity_id);
create index preferences_appearance_idx on public.preferences(appearance);
create index support_tickets_category_idx on public.support_tickets(category);

-- ═══════════════════════ Seguridad ═══════════════════════
-- Catálogos: solo lectura para la app.

alter table public.chest_rarities     enable row level security;
alter table public.challenge_periods  enable row level security;
alter table public.appearance_modes   enable row level security;
alter table public.support_categories enable row level security;
alter table public.ticket_statuses    enable row level security;

create policy chest_rarities_read on public.chest_rarities
  for select to authenticated using (true);
create policy challenge_periods_read on public.challenge_periods
  for select to authenticated using (true);
create policy appearance_modes_read on public.appearance_modes
  for select to authenticated using (true);
create policy support_categories_read on public.support_categories
  for select to authenticated using (true);
create policy ticket_statuses_read on public.ticket_statuses
  for select to authenticated using (true);

commit;

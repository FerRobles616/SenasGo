-- SeñasGo: reportes de soporte enviados desde la app.
--
-- Ejecutar en el SQL Editor DESPUÉS de 202611090001_init.sql.
--
-- 3FN: el reporte no repite datos de otras tablas. El correo de contacto sale
-- de la cuenta (auth.users) y el nivel/XP del usuario salen de profiles; aquí
-- solo queda lo propio del reporte y del dispositivo donde ocurrió.

create table public.support_tickets (
  id          uuid primary key,             -- generado en el teléfono:
                                            -- reintentar el envío no duplica
  user_id     uuid not null
              references public.profiles(user_id) on delete cascade,
  category    text not null
              check (category in ('bug', 'idea', 'content', 'comment')),
  message     text not null check (char_length(message) between 10 and 2000),
  screen      text not null default '',     -- dónde ocurrió (pantalla/seña)
  app_version text not null default '',
  platform    text not null default '',
  device_tier text not null default '',     -- gama del equipo (rendimiento)
  status      text not null default 'open'
              check (status in ('open', 'in_progress', 'resolved')),
  created_at  timestamptz not null,
  resolved_at timestamptz,
  -- resolved_at existe solo cuando el reporte está resuelto.
  check ((status = 'resolved') = (resolved_at is not null))
);

create index support_tickets_user_idx on public.support_tickets(user_id);
create index support_tickets_status_idx
  on public.support_tickets(status, created_at desc);

alter table public.support_tickets enable row level security;

-- La app solo puede crear reportes propios y leer su estado. El cambio de
-- estado (en curso / resuelto) lo hace Soporte desde el panel.
create policy support_tickets_insert_own on public.support_tickets
  for insert to authenticated
  with check ((select auth.uid()) = user_id and status = 'open');
create policy support_tickets_read_own on public.support_tickets
  for select to authenticated
  using ((select auth.uid()) = user_id);

-- Bandeja para Soporte (Table Editor / SQL Editor del panel): cada reporte con
-- el nombre y el correo de quien lo envió. No es accesible desde la app.
create view public.support_inbox
with (security_invoker = true) as
select t.id,
       t.created_at,
       t.status,
       t.category,
       t.message,
       t.screen,
       p.username,
       u.email,
       t.app_version,
       t.platform,
       t.device_tier,
       t.resolved_at
from public.support_tickets t
join public.profiles p on p.user_id = t.user_id
join auth.users u on u.id = t.user_id;

revoke all on public.support_inbox from anon, authenticated;

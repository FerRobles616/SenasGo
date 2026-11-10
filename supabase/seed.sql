-- Catálogo base de SeñasGo (mismo contenido que la app).
-- Ejecutar AL FINAL, después de las tres migraciones (0001, 0002 y 0003).
-- Se puede volver a ejecutar sin duplicar filas.

insert into public.categories (id, name) values
  ('greetings', 'Saludos'),
  ('numbers',   'Números'),
  ('basics',    'Palabras básicas')
on conflict (id) do update set name = excluded.name;

insert into public.lessons (id, category_id, title, description, difficulty, position) values
  ('leccion_saludos', 'greetings', 'Saludos', 'Aprendé a saludar y despedirte en LSPy.', 1, 1),
  ('leccion_numeros', 'numbers',   'Números', 'Contá del 1 al 3 con las manos.', 1, 2),
  ('leccion_basicas', 'basics',    'Palabras Básicas', 'Frases de uso cotidiano: gracias, sí, no, por favor.', 2, 3)
on conflict (id) do update set
  category_id = excluded.category_id,
  title       = excluded.title,
  description = excluded.description,
  difficulty  = excluded.difficulty,
  position    = excluded.position;

insert into public.signs (id, lesson_id, name, description, position) values
  ('saludo_hola',      'leccion_saludos', 'Hola',      'Mano abierta en alto, a la altura del hombro, con la palma hacia la otra persona.', 1),
  ('saludo_chau',      'leccion_saludos', 'Chau',      'Mano abierta que se mueve lateralmente en despedida.', 2),
  ('saludo_saludos',   'leccion_saludos', 'Saludos',   'Mano plana que sale desde la frente hacia el costado, como un saludo.', 3),
  ('numero_uno',       'leccion_numeros', 'Uno',       'Índice extendido hacia arriba.', 1),
  ('numero_dos',       'leccion_numeros', 'Dos',       'Índice y medio extendidos en V hacia arriba.', 2),
  ('numero_tres',      'leccion_numeros', 'Tres',      'Índice, medio y anular extendidos.', 3),
  ('basico_gracias',   'leccion_basicas', 'Gracias',   'Mano plana desde el mentón hacia adelante.', 1),
  ('basico_si',        'leccion_basicas', 'Sí',        'Puño cerrado que asiente verticalmente.', 2),
  ('basico_no',        'leccion_basicas', 'No',        'Índice y medio que se abren y cierran lateralmente.', 3),
  ('basico_por_favor', 'leccion_basicas', 'Por favor', 'Mano plana sobre el pecho con movimiento circular.', 4)
on conflict (id) do update set
  lesson_id   = excluded.lesson_id,
  name        = excluded.name,
  description = excluded.description,
  position    = excluded.position;

insert into public.challenges (id, title, period_id, target, reward_xp) values
  ('daily_xp',         'Ganá 20 XP hoy',              'daily',  20, 20),
  ('weekly_signs',     'Practicá 3 señas distintas',  'weekly',  3, 20),
  ('weekend_practice', 'Entrená el fin de semana',    'weekly',  2, 20),
  ('streak_3',         'Mantené una racha de 3 días', 'once',    3, 30)
on conflict (id) do update set
  title     = excluded.title,
  period_id = excluded.period_id,
  target    = excluded.target,
  reward_xp = excluded.reward_xp;

-- Cofre de cada lección: solo su rareza. El premio sale de chest_rarities.
insert into public.chests (lesson_id, rarity_id) values
  ('leccion_saludos', 'common'),
  ('leccion_numeros', 'rare'),
  ('leccion_basicas', 'epic')
on conflict (lesson_id) do update set rarity_id = excluded.rarity_id;

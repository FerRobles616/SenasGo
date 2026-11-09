-- Catálogo base de SeñasGo. Se puede volver a ejecutar sin duplicar filas.
insert into public.lessons (id, title, description, position) values
  ('leccion_saludos', 'Saludos', 'Aprendé a saludar y despedirte en LSPy.', 1),
  ('leccion_numeros', 'Números', 'Contá del 1 al 3 con las manos.', 2),
  ('leccion_basicas', 'Palabras Básicas', 'Frases de uso cotidiano: gracias, sí, no, por favor.', 3)
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  position = excluded.position;

insert into public.signs (id, lesson_id, name, description, category, position) values
  ('saludo_hola', 'leccion_saludos', 'Hola', 'Mano abierta en alto, a la altura del hombro, con la palma hacia la otra persona.', 'greetings', 1),
  ('saludo_chau', 'leccion_saludos', 'Chau', 'Mano abierta que se mueve lateralmente en despedida.', 'greetings', 2),
  ('saludo_saludos', 'leccion_saludos', 'Saludos', 'Mano plana que sale desde la frente hacia el costado, como un saludo.', 'greetings', 3),
  ('numero_uno', 'leccion_numeros', 'Uno', 'Índice extendido hacia arriba.', 'numbers', 1),
  ('numero_dos', 'leccion_numeros', 'Dos', 'Índice y medio extendidos en V hacia arriba.', 'numbers', 2),
  ('numero_tres', 'leccion_numeros', 'Tres', 'Índice, medio y anular extendidos.', 'numbers', 3),
  ('basico_gracias', 'leccion_basicas', 'Gracias', 'Mano plana desde el mentón hacia adelante.', 'basics', 1),
  ('basico_si', 'leccion_basicas', 'Sí', 'Puño cerrado que asiente verticalmente.', 'basics', 2),
  ('basico_no', 'leccion_basicas', 'No', 'Índice y medio que se abren y cierran lateralmente.', 'basics', 3),
  ('basico_por_favor', 'leccion_basicas', 'Por favor', 'Mano plana sobre el pecho con movimiento circular.', 'basics', 4)
on conflict (id) do update set
  lesson_id = excluded.lesson_id,
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  position = excluded.position;

insert into public.challenges (id, title, target, reward_xp) values
  ('daily_xp', 'Ganá 20 XP hoy', 20, 20),
  ('weekly_signs', 'Practicá 3 señas distintas', 3, 20),
  ('weekend_practice', 'Entrená el fin de semana', 2, 20),
  ('streak_3', 'Mantené una racha de 3 días', 3, 30)
on conflict (id) do update set
  title = excluded.title,
  target = excluded.target,
  reward_xp = excluded.reward_xp;

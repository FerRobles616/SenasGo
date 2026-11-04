-- =====================================================================
--  SeñasGo · Esquema relacional (SQLite 3)
--  Prototipo móvil para el aprendizaje inicial de LSPy (UNIDA 2026.2)
--
--  Equivalente relacional de la persistencia local de la app (Hive):
--  UserModel, LessonModel, SignModel, ProgressModel, intentos de práctica
--  y la caja de juego (racha / vidas). Los reportes de soporte se guardan
--  solo en Hive como mapas dinámicos. 100 % local y sin cuentas en la nube.
-- =====================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- 1. Catálogos
-- ---------------------------------------------------------------------

CREATE TABLE categoria (
    id      TEXT PRIMARY KEY,                -- greetings, numbers, basics...
    nombre  TEXT NOT NULL UNIQUE
);

-- Los 5 parámetros formativos de una seña.
CREATE TABLE parametro_formativo (
    id      TEXT PRIMARY KEY,                -- manual_config, palm_orientation...
    nombre  TEXT NOT NULL UNIQUE,
    orden   INTEGER NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------
-- 2. Contenido pedagógico (vocabulario acotado)
-- ---------------------------------------------------------------------

CREATE TABLE leccion (
    id           TEXT PRIMARY KEY,
    titulo       TEXT NOT NULL,
    descripcion  TEXT NOT NULL,
    dificultad   INTEGER NOT NULL CHECK (dificultad BETWEEN 1 AND 5),
    orden        INTEGER NOT NULL UNIQUE      -- posición en el camino
);

CREATE TABLE sena (
    id                TEXT PRIMARY KEY,
    nombre            TEXT NOT NULL,
    categoria_id      TEXT NOT NULL REFERENCES categoria(id),
    descripcion       TEXT NOT NULL,
    imagen            TEXT,                   -- ruta del asset de referencia
    animacion         TEXT,                   -- ruta Lottie/JSON (opcional)
    rive_indice       INTEGER UNIQUE,         -- input signIndex del avatar Rive
    etiqueta_modelo   TEXT,                   -- etiqueta del clasificador TFLite
    activa            INTEGER NOT NULL DEFAULT 1 CHECK (activa IN (0, 1)),
    validada_lspy     INTEGER NOT NULL DEFAULT 0 CHECK (validada_lspy IN (0, 1))
);

CREATE TABLE sena_etiqueta (
    sena_id   TEXT NOT NULL REFERENCES sena(id) ON DELETE CASCADE,
    etiqueta  TEXT NOT NULL,
    PRIMARY KEY (sena_id, etiqueta)
);

-- Una lección agrupa varias señas, en un orden (nodos del camino).
CREATE TABLE leccion_sena (
    leccion_id  TEXT NOT NULL REFERENCES leccion(id) ON DELETE CASCADE,
    sena_id     TEXT NOT NULL REFERENCES sena(id),
    orden       INTEGER NOT NULL,
    PRIMARY KEY (leccion_id, sena_id),
    UNIQUE (leccion_id, orden)
);

-- Referencia de evaluación de cada seña (SignReference en la app).
CREATE TABLE referencia_sena (
    sena_id      TEXT PRIMARY KEY REFERENCES sena(id) ON DELETE CASCADE,
    -- 5 caracteres: pulgar, índice, medio, anular, meñique.
    -- E = extendido, D = doblado, - = indistinto
    dedos        TEXT NOT NULL CHECK (length(dedos) = 5 AND dedos NOT GLOB '*[^ED-]*'),
    palma        TEXT CHECK (palma IN ('camara', 'senante', 'costado', 'arriba', 'abajo')),
    movimiento   TEXT NOT NULL CHECK (movimiento IN
                   ('ninguno', 'lateral', 'vertical', 'adelante', 'circular', 'cualquiera')),
    usa_rostro   INTEGER NOT NULL DEFAULT 0 CHECK (usa_rostro IN (0, 1))
);

-- ---------------------------------------------------------------------
-- 3. Usuario local y estado del juego
-- ---------------------------------------------------------------------

CREATE TABLE usuario (
    id                 TEXT PRIMARY KEY,      -- UUID v4 generado en el equipo
    nombre             TEXT NOT NULL DEFAULT 'Usuario',
    nivel              INTEGER NOT NULL DEFAULT 1 CHECK (nivel BETWEEN 1 AND 5),
    xp                 INTEGER NOT NULL DEFAULT 0 CHECK (xp >= 0),
    leccion_actual_id  TEXT REFERENCES leccion(id),
    creado_en          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultimo_ingreso     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Racha y vidas (1 a 1 con el usuario).
CREATE TABLE estado_juego (
    usuario_id    TEXT PRIMARY KEY REFERENCES usuario(id) ON DELETE CASCADE,
    racha_dias    INTEGER NOT NULL DEFAULT 0 CHECK (racha_dias >= 0),
    fecha_racha   TEXT,                       -- último día con seña correcta
    vidas         INTEGER NOT NULL DEFAULT 5 CHECK (vidas BETWEEN 0 AND 5),
    vidas_desde   TEXT                        -- inicio de la recarga (1 cada 20 min)
);

-- ---------------------------------------------------------------------
-- 4. Práctica y progreso
-- ---------------------------------------------------------------------

-- Cada intento evaluado en la pantalla de práctica.
CREATE TABLE intento (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario_id     TEXT NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    sena_id        TEXT NOT NULL REFERENCES sena(id),
    leccion_id     TEXT REFERENCES leccion(id),
    fecha          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modo           TEXT NOT NULL CHECK (modo IN ('edge_ai', 'conceptual')),
    nivel_usuario  INTEGER NOT NULL CHECK (nivel_usuario BETWEEN 1 AND 5),
    correcto       INTEGER NOT NULL CHECK (correcto IN (0, 1)),
    xp_otorgado    INTEGER NOT NULL DEFAULT 0 CHECK (xp_otorgado IN (0, 10)),
    CHECK ((correcto = 1 AND xp_otorgado = 10) OR (correcto = 0 AND xp_otorgado = 0))
);
CREATE INDEX ix_intento_usuario_fecha ON intento (usuario_id, fecha);

-- Resultado cualitativo de cada parámetro en un intento (sin porcentajes).
CREATE TABLE intento_parametro (
    intento_id    INTEGER NOT NULL REFERENCES intento(id) ON DELETE CASCADE,
    parametro_id  TEXT NOT NULL REFERENCES parametro_formativo(id),
    estado        TEXT NOT NULL CHECK (estado IN ('bien', 'a_mejorar', 'no_evaluado')),
    indicacion    TEXT,                       -- p. ej. "Extiende el índice como en la guía."
    PRIMARY KEY (intento_id, parametro_id)
);

-- Señas aprendidas (al menos un intento correcto).
CREATE TABLE sena_aprendida (
    usuario_id    TEXT NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    sena_id       TEXT NOT NULL REFERENCES sena(id),
    aprendida_en  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (usuario_id, sena_id)
);

CREATE TABLE leccion_completada (
    usuario_id      TEXT NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    leccion_id      TEXT NOT NULL REFERENCES leccion(id),
    completada_en   TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (usuario_id, leccion_id)
);

-- ---------------------------------------------------------------------
-- 5. Gamificación: insignias (sin tienda)
-- ---------------------------------------------------------------------

CREATE TABLE insignia (
    id           TEXT PRIMARY KEY,
    nombre       TEXT NOT NULL UNIQUE,
    descripcion  TEXT NOT NULL
);

CREATE TABLE usuario_insignia (
    usuario_id    TEXT NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    insignia_id   TEXT NOT NULL REFERENCES insignia(id),
    obtenida_en   TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (usuario_id, insignia_id)
);

-- ---------------------------------------------------------------------
-- 6. Reglas de negocio (triggers)
-- ---------------------------------------------------------------------

-- Seña correcta: +10 XP, nivel dinámico y seña aprendida.
CREATE TRIGGER trg_intento_correcto
AFTER INSERT ON intento
WHEN NEW.correcto = 1
BEGIN
    UPDATE usuario
       SET xp = xp + NEW.xp_otorgado,
           nivel = CASE
                     WHEN xp + NEW.xp_otorgado < 100  THEN 1
                     WHEN xp + NEW.xp_otorgado < 300  THEN 2
                     WHEN xp + NEW.xp_otorgado < 600  THEN 3
                     WHEN xp + NEW.xp_otorgado < 1000 THEN 4
                     ELSE 5
                   END
     WHERE id = NEW.usuario_id;

    INSERT OR IGNORE INTO sena_aprendida (usuario_id, sena_id)
    VALUES (NEW.usuario_id, NEW.sena_id);

    -- Racha: suma 1 si la última fue ayer; vuelve a 1 si se cortó.
    UPDATE estado_juego
       SET racha_dias = CASE
                          WHEN fecha_racha = date(NEW.fecha)               THEN racha_dias
                          WHEN fecha_racha = date(NEW.fecha, '-1 day')     THEN racha_dias + 1
                          ELSE 1
                        END,
           fecha_racha = date(NEW.fecha)
     WHERE usuario_id = NEW.usuario_id;

    -- Insignia "Primera Práctica" con la primera seña correcta.
    INSERT OR IGNORE INTO usuario_insignia (usuario_id, insignia_id)
    VALUES (NEW.usuario_id, 'primera_practica');
END;

-- Intento incorrecto: resta una vida (nunca baja de cero).
CREATE TRIGGER trg_intento_incorrecto
AFTER INSERT ON intento
WHEN NEW.correcto = 0
BEGIN
    UPDATE estado_juego
       SET vidas_desde = CASE WHEN vidas = 5 THEN NEW.fecha ELSE vidas_desde END,
           vidas = MAX(vidas - 1, 0)
     WHERE usuario_id = NEW.usuario_id;
END;

-- Lección completada cuando se aprendieron todas sus señas.
CREATE TRIGGER trg_leccion_completa
AFTER INSERT ON sena_aprendida
BEGIN
    INSERT OR IGNORE INTO leccion_completada (usuario_id, leccion_id)
    SELECT NEW.usuario_id, ls.leccion_id
      FROM leccion_sena ls
     WHERE ls.sena_id = NEW.sena_id
       AND NOT EXISTS (
             SELECT 1 FROM leccion_sena x
              WHERE x.leccion_id = ls.leccion_id
                AND x.sena_id NOT IN (SELECT sena_id FROM sena_aprendida
                                       WHERE usuario_id = NEW.usuario_id));
END;

-- ---------------------------------------------------------------------
-- 7. Vistas (lo que hoy guarda ProgressModel como totales)
-- ---------------------------------------------------------------------

CREATE VIEW v_progreso_usuario AS
SELECT u.id                                   AS usuario_id,
       u.xp,
       u.nivel,
       g.racha_dias,
       g.vidas,
       COUNT(i.id)                            AS intentos_totales,
       COALESCE(SUM(i.correcto), 0)           AS intentos_correctos,
       (SELECT COUNT(*) FROM sena_aprendida a WHERE a.usuario_id = u.id) AS senas_aprendidas
  FROM usuario u
  LEFT JOIN estado_juego g ON g.usuario_id = u.id
  LEFT JOIN intento i      ON i.usuario_id = u.id
 GROUP BY u.id;

-- Camino de aprendizaje: estado de cada nodo (completada / actual / bloqueada).
CREATE VIEW v_camino AS
WITH ordenadas AS (
    SELECT l.orden AS orden_leccion, ls.orden AS orden_sena,
           l.id AS leccion_id, l.titulo, s.id AS sena_id, s.nombre
      FROM leccion l
      JOIN leccion_sena ls ON ls.leccion_id = l.id
      JOIN sena s          ON s.id = ls.sena_id
)
SELECT u.id AS usuario_id, o.*,
       CASE
         WHEN a.sena_id IS NOT NULL THEN 'completada'
         WHEN NOT EXISTS (
                SELECT 1 FROM ordenadas p
                 WHERE (p.orden_leccion, p.orden_sena) < (o.orden_leccion, o.orden_sena)
                   AND p.sena_id NOT IN (SELECT sena_id FROM sena_aprendida
                                          WHERE usuario_id = u.id))
           THEN 'actual'
         ELSE 'bloqueada'
       END AS estado
  FROM usuario u
 CROSS JOIN ordenadas o
  LEFT JOIN sena_aprendida a ON a.usuario_id = u.id AND a.sena_id = o.sena_id;

-- ---------------------------------------------------------------------
-- 8. Datos iniciales (seed de la app)
-- ---------------------------------------------------------------------

INSERT INTO categoria (id, nombre) VALUES
    ('greetings', 'Saludos'),
    ('numbers',   'Números'),
    ('basics',    'Palabras básicas'),
    ('family',    'Familia'),
    ('emotions',  'Emociones');

INSERT INTO parametro_formativo (id, nombre, orden) VALUES
    ('manual_config',      'Configuración manual',     1),
    ('palm_orientation',   'Orientación de la palma',  2),
    ('articulation_place', 'Lugar de articulación',    3),
    ('movement',           'Movimiento',               4),
    ('facial_expression',  'Expresión facial',         5);

INSERT INTO leccion (id, titulo, descripcion, dificultad, orden) VALUES
    ('leccion_saludos', 'Saludos',          'Aprendé a saludar y despedirte en LSPy.',              1, 1),
    ('leccion_numeros', 'Números',          'Contá del 1 al 3 con las manos.',                      1, 2),
    ('leccion_basicas', 'Palabras Básicas', 'Frases de uso cotidiano: gracias, sí, no, por favor.', 2, 3);

INSERT INTO sena (id, nombre, categoria_id, descripcion, imagen, rive_indice, etiqueta_modelo) VALUES
    ('saludo_hola',      'Hola',      'greetings', 'Saludo con mano abierta que avanza desde la frente.', 'assets/images/saludo_hola.png',      0, 'saludo_hola'),
    ('saludo_chau',      'Chau',      'greetings', 'Mano abierta que se mueve lateralmente en despedida.', 'assets/images/saludo_chau.png',      1, 'saludo_chau'),
    ('numero_uno',       'Uno',       'numbers',   'Índice extendido hacia arriba.',                       'assets/images/numero_uno.png',       2, 'numero_uno'),
    ('numero_dos',       'Dos',       'numbers',   'Índice y medio extendidos en V hacia arriba.',         'assets/images/numero_dos.png',       3, 'numero_dos'),
    ('numero_tres',      'Tres',      'numbers',   'Índice, medio y anular extendidos.',                   'assets/images/numero_tres.png',      4, 'numero_tres'),
    ('basico_gracias',   'Gracias',   'basics',    'Mano plana desde el mentón hacia adelante.',           'assets/images/basico_gracias.png',   5, 'basico_gracias'),
    ('basico_si',        'Sí',        'basics',    'Puño cerrado que asiente verticalmente.',              'assets/images/basico_si.png',        6, 'basico_si'),
    ('basico_no',        'No',        'basics',    'Índice y medio que se abren y cierran lateralmente.',  'assets/images/basico_no.png',        7, 'basico_no'),
    ('basico_por_favor', 'Por favor', 'basics',    'Mano plana sobre el pecho con movimiento circular.',   'assets/images/basico_por_favor.png', 8, 'basico_por_favor');

INSERT INTO sena_etiqueta (sena_id, etiqueta) VALUES
    ('saludo_hola', 'saludo'), ('saludo_hola', 'hola'), ('saludo_hola', 'básico'),
    ('saludo_chau', 'despedida'), ('saludo_chau', 'chau'),
    ('numero_uno', 'número'), ('numero_uno', '1'),
    ('numero_dos', 'número'), ('numero_dos', '2'),
    ('numero_tres', 'número'), ('numero_tres', '3'),
    ('basico_gracias', 'cortesía'), ('basico_gracias', 'gracias'),
    ('basico_si', 'afirmación'), ('basico_si', 'sí'),
    ('basico_no', 'negación'), ('basico_no', 'no'),
    ('basico_por_favor', 'cortesía'), ('basico_por_favor', 'por favor');

INSERT INTO leccion_sena (leccion_id, sena_id, orden) VALUES
    ('leccion_saludos', 'saludo_hola', 1),
    ('leccion_saludos', 'saludo_chau', 2),
    ('leccion_numeros', 'numero_uno', 1),
    ('leccion_numeros', 'numero_dos', 2),
    ('leccion_numeros', 'numero_tres', 3),
    ('leccion_basicas', 'basico_gracias', 1),
    ('leccion_basicas', 'basico_si', 2),
    ('leccion_basicas', 'basico_no', 3),
    ('leccion_basicas', 'basico_por_favor', 4);

-- Referencias ilustrativas: pendientes de validación por una persona
-- conocedora de LSPy (Riesgo R3 de la documentación).
INSERT INTO referencia_sena (sena_id, dedos, palma, movimiento, usa_rostro) VALUES
    ('saludo_hola',      'EEEEE', 'camara',  'cualquiera', 0),
    ('saludo_chau',      'EEEEE', 'camara',  'lateral',    0),
    ('numero_uno',       '-EDDD', NULL,      'ninguno',    0),
    ('numero_dos',       '-EEDD', NULL,      'ninguno',    0),
    ('numero_tres',      '-EEED', NULL,      'ninguno',    0),
    ('basico_gracias',   '-EEEE', 'senante', 'adelante',   1),
    ('basico_si',        '-DDDD', NULL,      'vertical',   1),
    ('basico_no',        '-EEDD', NULL,      'cualquiera', 1),
    ('basico_por_favor', '-EEEE', 'senante', 'circular',   0);

INSERT INTO insignia (id, nombre, descripcion) VALUES
    ('primera_practica', 'Primera Práctica', 'Completaste tu primera seña correctamente.');

-- Usuario local inicial (la app lo crea en el primer inicio).
INSERT INTO usuario (id, nombre) VALUES ('00000000-0000-4000-8000-000000000001', 'Usuario');
INSERT INTO estado_juego (usuario_id) VALUES ('00000000-0000-4000-8000-000000000001');

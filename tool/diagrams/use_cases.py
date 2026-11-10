"""Diagrama de casos de uso de SeñasGo (UML) en SVG.

Uso:
    python -I tool/diagrams/use_cases.py docs/diagramas/casos_de_uso.svg

El diagrama refleja lo que hace la app hoy:
- Usuario invitado y usuario registrado (con cuenta en Supabase).
- Soporte: atiende en el panel de Supabase los reportes enviados desde Ayuda.
- Administrador: gestiona catálogo, cuentas y seguridad desde el panel de
  Supabase y publica nuevas versiones. Ninguno de los dos tiene pantallas
  dentro de la app móvil, por eso viven en sus propios límites de sistema.
"""
import sys
from xml.sax.saxutils import escape

W, H = 2440, 2290
FONT = "Arial, Helvetica, sans-serif"
INK = "#1f2937"
BLUE = "#5B9BD5"
NAVY = "#1F4E79"

out = []
add = out.append


def text(x, y, s, size=15, weight="normal", anchor="middle", color=INK,
         italic=False):
    st = ' font-style="italic"' if italic else ""
    add(f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" '
        f'font-weight="{weight}" text-anchor="{anchor}" fill="{color}"{st}>'
        f'{escape(s)}</text>')


def boundary(x, y, w, h, title, subtitle, fill):
    add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" '
        f'fill="{fill}" stroke="{NAVY}" stroke-width="2.5"/>')
    text(x + w / 2, y + 32, title, 22, "bold", color=NAVY)
    text(x + w / 2, y + 54, subtitle, 14, italic=True, color="#475569")


def group(x, y, w, h, title):
    add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" '
        f'fill="none" stroke="#94a3b8" stroke-width="1.4" '
        f'stroke-dasharray="6 5"/>')
    text(x + 12, y + 21, title, 15, "bold", "start", "#475569")


UC = {}
UC_SVG = []   # óvalos y textos: se repiten al final para quedar sobre las líneas


def usecase(key, x, y, label, w=330, h=56, fill="#ffffff", ext=False):
    UC[key] = (x, y, w, h)
    start = len(out)
    add(f'<ellipse cx="{x}" cy="{y}" rx="{w / 2}" ry="{h / 2}" fill="{fill}" '
        f'stroke="{BLUE if not ext else "#6b7f96"}" stroke-width="2.4"/>')
    lines = label.split("\n")
    y0 = y - (len(lines) - 1) * 10 + 6
    for i, ln in enumerate(lines):
        text(x, y0 + i * 20, ln, 17, "600")
    UC_SVG.extend(out[start:])


ACT = {}


def actor(key, x, y, label, sub=None, color=INK):
    ACT[key] = (x, y)
    add(f'<g stroke="{color}" stroke-width="2.6" fill="none">'
        f'<circle cx="{x}" cy="{y - 46}" r="15" fill="#fff"/>'
        f'<line x1="{x}" y1="{y - 31}" x2="{x}" y2="{y + 12}"/>'
        f'<line x1="{x - 24}" y1="{y - 16}" x2="{x + 24}" y2="{y - 16}"/>'
        f'<line x1="{x}" y1="{y + 12}" x2="{x - 18}" y2="{y + 44}"/>'
        f'<line x1="{x}" y1="{y + 12}" x2="{x + 18}" y2="{y + 44}"/></g>')
    for i, ln in enumerate(label.split("\n")):
        text(x, y + 68 + i * 20, ln, 18, "bold", color=color)
    if sub:
        text(x, y + 66 + len(label.split("\n")) * 18, sub, 12.5,
             italic=True, color="#475569")


def system_actor(key, x, y, label):
    """Actor secundario (sistema o dispositivo): rectángulo «system»."""
    ACT[key] = (x, y)
    add(f'<rect x="{x - 78}" y="{y - 30}" width="156" height="60" rx="6" '
        f'fill="#f8fafc" stroke="{INK}" stroke-width="2"/>')
    text(x, y - 10, "«sistema»", 12, italic=True, color="#475569")
    for i, ln in enumerate(label.split("\n")):
        text(x, y + 10 + i * 17, ln, 15.5, "bold")


def edge_point(key, tx, ty):
    """Punto del borde de la elipse (o del actor) hacia (tx, ty)."""
    if key in UC:
        x, y, w, h = UC[key]
        dx, dy = tx - x, ty - y
        a, b = w / 2, h / 2
        k = 1 / ((dx * dx) / (a * a) + (dy * dy) / (b * b)) ** 0.5 if (
            dx or dy) else 0
        return x + dx * k, y + dy * k
    x, y = ACT[key]
    return x, y - 16


def assoc(a, b):
    ax, ay = ACT[a] if a in ACT else UC[a][:2]
    bx, by = UC[b][:2]
    x1, y1 = edge_point(a, bx, by)
    x2, y2 = edge_point(b, ax, ay)
    add(f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" '
        f'stroke="{INK}" stroke-width="1.9"/>')


def dep(a, b, kind):
    """a --«kind»--> b (línea punteada con flecha abierta)."""
    ax, ay = UC[a][:2]
    bx, by = UC[b][:2]
    x1, y1 = edge_point(a, bx, by)
    x2, y2 = edge_point(b, ax, ay)
    add(f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" '
        f'stroke="#334155" stroke-width="1.8" stroke-dasharray="8 5" '
        f'marker-end="url(#open)"/>')
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    add(f'<rect x="{mx - 40}" y="{my - 12}" width="80" height="21" '
        f'fill="#ffffff" opacity="0.92"/>')
    text(mx, my + 4, f"«{kind}»", 14, "600", color="#1f2937")


def generalization(child, parent):
    cx, cy = ACT[child]
    px, py = ACT[parent]
    add(f'<line x1="{cx}" y1="{cy - 62}" x2="{px}" y2="{py + 118}" '
        f'stroke="{INK}" stroke-width="1.8" marker-end="url(#tri)"/>')


add(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
    f'viewBox="0 0 {W} {H}">')
add('<defs>'
    '<marker id="open" markerWidth="12" markerHeight="12" refX="10" refY="6" '
    'orient="auto"><path d="M0,0 L10,6 L0,12" fill="none" stroke="#475569" '
    'stroke-width="1.6"/></marker>'
    '<marker id="tri" markerWidth="18" markerHeight="18" refX="16" refY="9" '
    'orient="auto"><path d="M0,0 L16,9 L0,18 z" fill="#fff" stroke="#1f2937" '
    'stroke-width="1.6"/></marker></defs>')
add(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')
text(W / 2, 46, "SeñasGo — Diagrama de casos de uso", 30, "bold",
     color=NAVY)
text(W / 2, 76, "Roles: Usuario (con cuenta obligatoria), Soporte y "
     "Administrador · Actores secundarios: Supabase, cámara y calendario",
     16, color="#475569")

# ─────────────────────────── límites de sistema ───────────────────────────
SX, SY, SW, SH = 300, 110, 1180, 1635
boundary(SX, SY, SW, SH, "App móvil SeñasGo (Android)",
         "Requiere cuenta; con la sesión iniciada funciona sin conexión",
         "#f4f9fe")
CX1, CX2 = 560, 1170          # columna base / columna incluida-extendida

ROW = 74
rows = {}
y = 240
order = [
    ("registrar", "Registrarse\n(crear cuenta)"),
    ("login", "Iniciar sesión"),
    ("logout", "Cerrar sesión"),
    ("bienvenida", "Completar bienvenida\ny elegir meta diaria"),
    ("camino", "Ver camino y guía\nde las lecciones"),
    ("profesor", "Ver demostración del\nprofesor 3D por pasos"),
    ("biblioteca", "Consultar biblioteca\nde señas"),
    ("practicar", "Practicar seña\ncon la cámara"),
    ("repaso", "Hacer repaso rápido\n(sin cámara)"),
    ("retos", "Reclamar retos\ny cofres"),
    ("progreso", "Ver progreso, racha\ny liga"),
    ("perfil", "Gestionar perfil, meta\ny apariencia"),
    ("compartir", "Compartir progreso\ne invitación"),
    ("ayuda", "Consultar ayuda, FAQ\ny acceso rápido"),
    ("reporte", "Enviar reporte\nde soporte"),
]
EXTRA = {"logout": 44, "profesor": 30, "biblioteca": 100, "practicar": 160,
         "repaso": 30, "progreso": 30}
for key, _ in order:
    rows[key] = y
    y += ROW + EXTRA.get(key, 0)


# grupos punteados detrás de los casos de uso
def span(a, b, title, top=62, bottom=44):
    group(SX + 24, rows[a] - top, SW - 48, rows[b] - rows[a] + top + bottom,
          title)


span("registrar", "logout", "Acceso (obligatorio)")
span("bienvenida", "biblioteca", "Aprendizaje")
span("practicar", "repaso", "Práctica", top=118, bottom=40)
span("retos", "progreso", "Gamificación y progreso")
span("perfil", "reporte", "Perfil y ayuda")

for key, label in order:
    usecase(key, CX1, rows[key], label)

# casos incluidos / extendidos (columna derecha)
ext = [
    ("sync", (rows["registrar"] + rows["login"]) / 2,
     "Sincronizar progreso\nen la nube"),
    ("recompensa", rows["bienvenida"], "Recibir recompensa\nde bienvenida"),
    ("vista", rows["profesor"] - 6, "Cambiar vista\nTorso / Manos"),
    ("repetir", rows["profesor"] + 62, "Repetir un paso\nde la seña"),
    ("reintentar", rows["practicar"] - 80, "Reintentar\ncaptura"),
    ("encuadre", rows["practicar"] - 16, "Preparar encuadre\ne iluminación"),
    ("detectar", rows["practicar"] + 48, "Detectar la mano"),
    ("evaluar", rows["practicar"] + 112, "Evaluar parámetros\nde la seña"),
    ("feedback", rows["practicar"] + 176, "Recibir\nretroalimentación"),
    ("xp", rows["practicar"] + 240, "Ganar XP"),
    ("protector", rows["progreso"], "Usar protector\nde racha"),
    ("recordatorio", rows["perfil"], "Programar recordatorio\nde práctica"),
    ("recuperar", rows["logout"], "Recuperar contraseña\n(código por correo)"),
    ("pendiente", rows["reporte"], "Enviar al volver\nla conexión"),
]
for key, y_, label in ext:
    usecase(key, CX2, y_, label, w=300, h=54, fill="#fbfdff", ext=True)

dep("registrar", "sync", "include")
dep("login", "sync", "include")
dep("bienvenida", "recompensa", "include")
dep("vista", "profesor", "extend")
dep("repetir", "profesor", "extend")
dep("practicar", "encuadre", "include")
dep("practicar", "detectar", "include")
dep("practicar", "evaluar", "include")
dep("practicar", "feedback", "include")
dep("reintentar", "practicar", "extend")
dep("xp", "feedback", "extend")
dep("protector", "progreso", "extend")
dep("recordatorio", "perfil", "extend")
dep("recuperar", "login", "extend")
dep("pendiente", "reporte", "extend")

# Precondición común (nota UML con la esquina doblada).
NX, NY = SX + 640, rows["compartir"] - 2
add(f'<path d="M{NX},{NY} h330 l14,14 v44 h-344 z" fill="#fffbe6" '
    f'stroke="#b45309" stroke-width="1.4"/>')
text(NX + 172, NY + 24, "Precondición de todos los casos (salvo", 13,
     color="#7c2d12")
text(NX + 172, NY + 44, "Registrarse e Iniciar sesión): sesión iniciada", 13,
     color="#7c2d12")

# ─────────────────────────── actor usuario ───────────────────────────
actor("usuario", 135, 900, "Usuario", "(con cuenta)")
for key, _ in order:
    assoc("usuario", key)

# ─────────────────────────── actores secundarios ───────────────────────────
system_actor("supabase", 1590, UC["sync"][1], "Supabase\n(Auth y BD)")
system_actor("camara", 1590, UC["detectar"][1] - 30, "Cámara del\nteléfono")
system_actor("calendario", 1590, UC["recordatorio"][1],
             "Calendario\ndel teléfono")
assoc("supabase", "sync")
assoc("camara", "detectar")
assoc("camara", "encuadre")
assoc("calendario", "recordatorio")

# ─────────────────────────── soporte ───────────────────────────
BX, BW = 1720, 470
boundary(BX, 110, BW, 580, "Bandeja de soporte",
         "Fuera de la app: panel de Supabase (support_inbox)", "#fbf7ef")
SUPX = BX + BW / 2
sup = [
    ("s_recibir", 222, "Revisar reportes\nen la bandeja"),
    ("s_resp", 302, "Responder al usuario\npor correo"),
    ("s_diag", 382, "Diagnosticar\nel problema"),
    ("s_escalar", 462, "Escalar incidencia\nal administrador"),
    ("s_estado", 542, "Marcar en curso\no resuelto"),
    ("s_faq", 622, "Proponer cambios en\nla ayuda (FAQ)"),
]
for key, y_, label in sup:
    usecase(key, SUPX, y_, label, w=330, h=56)
dep("s_resp", "s_diag", "include")
dep("s_escalar", "s_diag", "extend")
actor("soporte", 2330, 430, "Soporte")
for key, _, _ in sup:
    if key != "s_diag":
        assoc("soporte", key)

# ─────────────────────────── administrador ───────────────────────────
boundary(BX, 730, BW, 1015, "Panel de administración",
         "Fuera de la app: Supabase y repositorio", "#f3f6fb")
adm = [
    ("a_catalogo", 845, "Gestionar lecciones\ny señas (catálogo)"),
    ("a_retos", 932, "Gestionar retos"),
    ("a_validar", 1019, "Registrar validación\nde señas (experto LSPy)"),
    ("a_cuentas", 1106, "Gestionar cuentas\nde usuario"),
    ("a_seguridad", 1193, "Configurar autenticación\ny seguridad (RLS)"),
    ("a_metricas", 1280, "Consultar métricas\nde uso"),
    ("a_incid", 1367, "Atender incidencias\nescaladas"),
    ("a_version", 1454, "Publicar nueva versión\n(APK, profesor 3D)"),
    ("a_respaldo", 1541, "Respaldar la\nbase de datos"),
    ("a_faq", 1628, "Actualizar la ayuda\n(FAQ) de la app"),
]
for key, y_, label in adm:
    usecase(key, SUPX, y_, label, w=340, h=56)
actor("admin", 2330, 1230, "Administrador")
for key, _, _ in adm:
    assoc("admin", key)

out.extend(UC_SVG)

# ─────────────────────────── especificación de roles ───────────────────────
TY = 1790
text(60, TY, "Especificación de roles", 22, "bold", "start", NAVY)
cols = [(60, 250, "Rol"), (310, 180, "Tipo"), (490, 980, "Descripción y "
        "permisos"), (1470, 910, "Dónde interviene")]
rows_t = [
    ("Usuario", "Principal (humano)",
     "Debe registrarse o iniciar sesión para usar la app. Después aprende "
     "con lecciones y el profesor 3D, practica, repasa, gana retos y "
     "cofres, gestiona su perfil y pide ayuda. Su progreso se sincroniza "
     "con su cuenta; solo puede leer y modificar sus propios datos (RLS).",
     "App móvil + Supabase"),
    ("Soporte", "Principal (humano)",
     "Revisa en la bandeja (support_inbox) los reportes que llegan desde la "
     "app, con el nombre y correo de quien escribió; diagnostica, responde "
     "por correo, marca el estado (en curso / resuelto) y escala al "
     "administrador. El usuario ve el estado en su historial.",
     "Panel de Supabase (fuera de la app)"),
    ("Administrador", "Principal (humano)",
     "Gestiona el catálogo (lecciones, señas, retos), las cuentas, la "
     "seguridad y los respaldos; registra la validación de las señas y "
     "publica nuevas versiones.", "Panel de Supabase y repositorio "
     "(fuera de la app)"),
    ("Cámara / Calendario", "Secundario (dispositivo)",
     "Servicios del teléfono que la app usa con permiso del usuario. La "
     "cámara se procesa en el teléfono; no se guardan ni envían imágenes.",
     "App móvil"),
    ("Supabase", "Secundario (sistema)",
     "Autenticación (registro, sesión, código para recuperar la "
     "contraseña) y base de datos PostgreSQL para el progreso y los "
     "reportes. Sin Supabase no se puede crear cuenta ni entrar.",
     "Nube"),
]


def wrap(s, width_px, size):
    per = max(10, int(width_px / (size * 0.52)))
    words, lines, cur = s.split(), [], ""
    for w_ in words:
        if len(cur) + len(w_) + 1 > per:
            lines.append(cur)
            cur = w_
        else:
            cur = (cur + " " + w_).strip()
    lines.append(cur)
    return lines


ty = TY + 20
add(f'<rect x="60" y="{ty}" width="2320" height="40" fill="{BLUE}"/>')
for x, w, h in cols:
    text(x + w / 2, ty + 26, h, 16, "bold", color="#ffffff")
ty += 40
for r in rows_t:
    cells = [wrap(v, cols[i][1] - 24, 16) for i, v in enumerate(r)]
    rh = max(len(c) for c in cells) * 21 + 20
    add(f'<rect x="60" y="{ty}" width="2320" height="{rh}" fill="#ffffff" '
        f'stroke="#1f2937" stroke-width="1"/>')
    for i, (x, w, _) in enumerate(cols):
        if i:
            add(f'<line x1="{x}" y1="{ty}" x2="{x}" y2="{ty + rh}" '
                f'stroke="#1f2937" stroke-width="1"/>')
        for j, ln in enumerate(cells[i]):
            text(x + 12, ty + 24 + j * 21, ln, 16,
                 "bold" if i == 0 else "normal", "start")
    ty += rh

text(60, ty + 34, "Notación UML: línea continua = asociación; «include» = "
     "siempre ocurre; «extend» = ocurre solo en ciertos casos; nota = "
     "precondición común.",
     13.5, anchor="start", color="#475569", italic=True)
add("</svg>")

open(sys.argv[1], "w", encoding="utf-8").write("\n".join(out))
print("ok", sys.argv[1], "alto usado", ty + 50)

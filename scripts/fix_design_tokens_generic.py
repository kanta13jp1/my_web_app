"""Generic DESIGN.md token fixer — pass filename as argument."""
import re, sys

filename = sys.argv[1]
with open(filename, 'r', encoding='utf-8') as f:
    content = f.read()

# ─── withAlpha → withValues ───────────────────────────────────────────────────
content = re.sub(
    r'\.withAlpha\((\d+)\)',
    lambda m: f'.withValues(alpha: {round(int(m.group(1))/255, 2)})',
    content
)

# ─── Subscript shade patterns (Colors.red[300] etc.) ─────────────────────────
subscript_shade = {
    # red
    ('red', '100'): '0xFFFEE2E2', ('red', '200'): '0xFFFCA5A5',
    ('red', '300'): '0xFFF87171', ('red', '400'): '0xFFF87171',
    ('red', '700'): '0xFFB91C1C', ('red', '800'): '0xFF991B1B',
    # green
    ('green', '100'): '0xFFDCFCE7', ('green', '200'): '0xFFA7F3D0',
    ('green', '300'): '0xFF6EE7B7', ('green', '400'): '0xFF34D399',
    ('green', '700'): '0xFF047857', ('green', '800'): '0xFF065F46',
    # amber
    ('amber', '100'): '0xFFFEF3C7', ('amber', '200'): '0xFFFDE68A',
    ('amber', '700'): '0xFFB45309', ('amber', '800'): '0xFF92400E',
    # blue
    ('blue', '100'): '0xFFDBEAFE', ('blue', '300'): '0xFF93C5FD',
    ('blue', '700'): '0xFF1D4ED8',
    # grey
    ('grey', '50'):  '0xFFF8FAFC', ('grey', '100'): '0xFFF1F5F9',
    ('grey', '200'): '0xFFE2E8F0', ('grey', '300'): '0xFFCBD5E1',
    ('grey', '400'): '0xFF94A3B8', ('grey', '500'): '0xFF64748B',
    ('grey', '600'): '0xFF475569', ('grey', '700'): '0xFF334155',
    ('grey', '800'): '0xFF1E293B', ('grey', '900'): '0xFF0F172A',
}
def replace_subscript(m):
    color = m.group(1).lower()
    shade = m.group(2)
    key = (color, shade)
    hex_val = subscript_shade.get(key, '0xFF64748B')
    return f'const Color({hex_val})'
content = re.sub(
    r'Colors\.(\w+)\[(\d+)\]',
    replace_subscript,
    content
)

# ─── Multi-part shade/Accent/variant patterns MOST SPECIFIC FIRST ─────────────
replacements_exact = [
    # deepPurple
    ('Colors.deepPurple.shade300', 'const Color(0xFF7C3AED)'),
    ('Colors.deepPurple.shade700', 'const Color(0xFF5B21B6)'),
    ('Colors.deepPurple',          'const Color(0xFF7C3AED)'),
    # purple
    ('Colors.purple.shade300',  'const Color(0xFFA78BFA)'),
    ('Colors.purple.shade700',  'const Color(0xFF6D28D9)'),
    # indigo
    ('Colors.indigo.shade900',  'const Color(0xFF1E1B4B)'),
    ('Colors.indigo.shade700',  'const Color(0xFF4338CA)'),
    ('Colors.indigo.shade400',  'const Color(0xFF818CF8)'),
    ('Colors.indigo.shade200',  'const Color(0xFFA5B4FC)'),
    ('Colors.indigo.shade50',   'const Color(0xFFEEF2FF)'),
    # orange
    ('Colors.orange.shade200',  'const Color(0xFFFDBA74)'),
    ('Colors.orange.shade50',   'const Color(0xFFFFF7ED)'),
    # red
    ('Colors.red.shade700',     'const Color(0xFFB91C1C)'),
    ('Colors.red.shade300',     'const Color(0xFFF87171)'),
    ('Colors.red.shade200',     'const Color(0xFFFCA5A5)'),
    # green
    ('Colors.green.shade600',   'const Color(0xFF059669)'),
    ('Colors.green.shade700',   'const Color(0xFF0F766E)'),
    ('Colors.green.shade50',    'const Color(0xFFF0FDFA)'),
    # blue
    ('Colors.blue.shade100',    'const Color(0xFFDBEAFE)'),
    ('Colors.blue.shade700',    'const Color(0xFF1D4ED8)'),
    # amber
    ('Colors.amber.shade800',   'const Color(0xFF92400E)'),
    ('Colors.amber.shade100',   'const Color(0xFFFEF3C7)'),
    # Accents / Grey variants
    ('Colors.blueGrey',         'const Color(0xFF475569)'),
    ('Colors.blueAccent',       'const Color(0xFF6366F1)'),
    ('Colors.redAccent',        'const Color(0xFFB91C1C)'),
    ('Colors.deepOrange',       'const Color(0xFFFF6B35)'),
    ('Colors.cyan',             'const Color(0xFF0D9488)'),
    ('Colors.pink',             'const Color(0xFFEC4899)'),
    ('Colors.black26',          'const Color(0x42000000)'),
    ('Colors.black54',          'const Color(0x8A000000)'),
]
for old, new in replacements_exact:
    content = content.replace(old, new)

# ─── Base colors with lookahead to avoid partial matches ──────────────────────
base_colors = [
    (r'Colors\.indigo(?![A-Za-z])',      'const Color(0xFF6366F1)'),
    (r'Colors\.purple(?![A-Za-z])',      'const Color(0xFF6366F1)'),
    (r'Colors\.orange(?![A-Za-z])',      'const Color(0xFFFF6B35)'),
    (r'Colors\.green(?![A-Za-z])',       'const Color(0xFF0D9488)'),
    (r'Colors\.red(?![A-Za-z])',         'const Color(0xFFB91C1C)'),
    (r'Colors\.blue(?![A-Za-z])',        'const Color(0xFF6366F1)'),
    (r'Colors\.teal(?![A-Za-z])',        'const Color(0xFF0D9488)'),
]
for pattern, replacement in base_colors:
    content = re.sub(pattern, replacement, content)

# ─── Fix const artifacts on chained calls ────────────────────────────────────
content = re.sub(r'\bconst (Color\(0x[0-9A-Fa-f]{8}\))\.with', r'\1.with', content)
content = re.sub(r'\bconst const\b', 'const', content)

with open(filename, 'w', encoding='utf-8') as f:
    f.write(content)
print(f'Done: {filename}')

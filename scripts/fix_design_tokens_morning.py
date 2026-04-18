"""Fix DESIGN.md token violations in morning_briefing_page.dart"""
import re

with open('lib/pages/morning_briefing_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# ─── Step 1: withAlpha → withValues (before any color replacement) ───────────
content = re.sub(
    r'\.withAlpha\((\d+)\)',
    lambda m: f'.withValues(alpha: {round(int(m.group(1))/255, 2)})',
    content
)

# ─── Step 2: shade + Accent combos MOST SPECIFIC FIRST ───────────────────────
replacements = [
    # indigo shades
    ('Colors.indigo.shade900', 'const Color(0xFF1E1B4B)'),
    ('Colors.indigo.shade700', 'const Color(0xFF4338CA)'),
    ('Colors.indigo.shade400', 'const Color(0xFF818CF8)'),
    ('Colors.indigo.shade200', 'const Color(0xFFA5B4FC)'),
    ('Colors.indigo.shade50',  'const Color(0xFFEEF2FF)'),
    # orange shades
    ('Colors.orange.shade200', 'const Color(0xFFFDBA74)'),
    ('Colors.orange.shade50',  'const Color(0xFFFFF7ED)'),
    # red shades
    ('Colors.red.shade700',    'const Color(0xFFB91C1C)'),
    ('Colors.red.shade300',    'const Color(0xFFF87171)'),
    ('Colors.red.shade200',    'const Color(0xFFFCA5A5)'),
    # green shades
    ('Colors.green.shade700',  'const Color(0xFF0F766E)'),
    ('Colors.green.shade50',   'const Color(0xFFF0FDFA)'),
    # amber shades
    ('Colors.amber.shade900',  'const Color(0xFF78350F)'),
    ('Colors.amber.shade100',  'const Color(0xFFFEF3C7)'),
    # purple shades
    ('Colors.purple.shade300', 'const Color(0xFFA78BFA)'),
    # blueGrey / blueAccent / redAccent (before base colors)
    ('Colors.blueGrey',        'const Color(0xFF475569)'),
    ('Colors.blueAccent',      'const Color(0xFF6366F1)'),
    ('Colors.redAccent',       'const Color(0xFFB91C1C)'),
    ('Colors.deepOrange',      'const Color(0xFFFF6B35)'),
    ('Colors.cyan',            'const Color(0xFF0D9488)'),
    ('Colors.pink',            'const Color(0xFFEC4899)'),
]
for old, new in replacements:
    content = content.replace(old, new)

# ─── Step 3: Base colors with word boundary (avoid partial matches) ───────────
# Use regex: Colors\.<name>(?![A-Za-z]) to not match Colors.orangeAccent etc.
base_colors = [
    (r'Colors\.indigo(?![A-Za-z])',   'const Color(0xFF6366F1)'),
    (r'Colors\.purple(?![A-Za-z])',   'const Color(0xFF6366F1)'),
    (r'Colors\.orange(?![A-Za-z])',   'const Color(0xFFFF6B35)'),
    (r'Colors\.green(?![A-Za-z])',    'const Color(0xFF0D9488)'),
    (r'Colors\.red(?![A-Za-z])',      'const Color(0xFFB91C1C)'),
    (r'Colors\.blue(?![A-Za-z])',     'const Color(0xFF6366F1)'),
    (r'Colors\.teal(?![A-Za-z])',     'const Color(0xFF0D9488)'),
]
for pattern, replacement in base_colors:
    content = re.sub(pattern, replacement, content)

# ─── Step 4: Colors.grey[N] → HEX ────────────────────────────────────────────
grey_map = {
    '50':  '0xFFF8FAFC', '100': '0xFFF1F5F9', '200': '0xFFE2E8F0',
    '300': '0xFFCBD5E1', '400': '0xFF94A3B8', '500': '0xFF64748B',
    '600': '0xFF475569', '700': '0xFF334155', '800': '0xFF1E293B',
    '900': '0xFF0F172A',
}
def replace_grey(m):
    shade = m.group(1)
    return f'const Color({grey_map.get(shade, "0xFF64748B")})'
content = re.sub(r'Colors\.grey\[(\d+)\]', replace_grey, content)

# ─── Step 5: Fix artifacts ────────────────────────────────────────────────────
# Remove extra const on chained calls like `const Color(0x...).withValues`
content = re.sub(r'\bconst (Color\(0x[0-9A-Fa-f]{8}\))\.with', r'\1.with', content)
# Remove double const
content = re.sub(r'\bconst const\b', 'const', content)

with open('lib/pages/morning_briefing_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Done.')

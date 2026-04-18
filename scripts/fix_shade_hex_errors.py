"""
Fix undefined_getter (.shadeN) and undefined_operator ([N]) errors.
Color(0xHEX).shadeN and Color(0xHEX)[N] are invalid — plain Color has no shade property.
Replace with the correct pre-computed hex value.
"""
import re, glob, sys

# MaterialColor shade mappings (Material Design spec values)
SHADE_MAP = {
    '0xFF009688': {  # teal
        50: '0xFFE0F2F1', 100: '0xFFB2DFDB', 200: '0xFF80CBC4',
        300: '0xFF4DB6AC', 400: '0xFF26A69A', 500: '0xFF009688',
        600: '0xFF00897B', 700: '0xFF00796B', 800: '0xFF00695C', 900: '0xFF004D40',
    },
    '0xFFFFC107': {  # amber
        50: '0xFFFFF8E1', 100: '0xFFFFECB3', 200: '0xFFFFE082',
        300: '0xFFFFD54F', 400: '0xFFFFCA28', 500: '0xFFFFC107',
        600: '0xFFFFB300', 700: '0xFFFFA000', 800: '0xFFFF8F00', 900: '0xFFFF6F00',
    },
    '0xFF9CA3AF': {  # grey token → Material grey shades
        50: '0xFFFAFAFA', 100: '0xFFF5F5F5', 200: '0xFFEEEEEE',
        300: '0xFFE0E0E0', 400: '0xFFBDBDBD', 500: '0xFF9E9E9E',
        600: '0xFF757575', 700: '0xFF616161', 800: '0xFF424242', 900: '0xFF212121',
    },
}

def fix_content(content):
    changed = False
    for base_hex, shades in SHADE_MAP.items():
        for shade_num, shade_hex in shades.items():
            def make_repl(shx):
                def repl(m):
                    prefix = 'const ' if m.group(1) else ''
                    return f'{prefix}Color({shx})'
                return repl
            repl_fn = make_repl(shade_hex)
            # Color(BASE)[N]
            p1 = rf'(const )?Color\({re.escape(base_hex)}\)\[{shade_num}\]'
            new = re.sub(p1, repl_fn, content)
            if new != content:
                changed = True
                content = new
            # Color(BASE).shadeN
            p2 = rf'(const )?Color\({re.escape(base_hex)}\)\.shade{shade_num}\b'
            new = re.sub(p2, repl_fn, content)
            if new != content:
                changed = True
                content = new
    return content, changed

dart_files = sorted(glob.glob('lib/**/*.dart', recursive=True))
total = 0
for fpath in dart_files:
    try:
        orig = open(fpath, encoding='utf-8').read()
        fixed, changed = fix_content(orig)
        if changed:
            open(fpath, 'w', encoding='utf-8').write(fixed)
            total += 1
            print(f'Fixed: {fpath}')
    except Exception as e:
        print(f'ERROR {fpath}: {e}', file=sys.stderr)
print(f'\nTotal files modified: {total}')

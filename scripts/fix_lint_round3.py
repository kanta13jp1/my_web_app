"""
Fix unnecessary_const in ai_company_builder, election_strategy, landing_page, abstinence_guard.
Based on CI run 24609466689 + proactive scan for broader patterns.
"""

def fix_uc(filepath, uc_lines):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    count = 0
    for lineno in uc_lines:
        idx = lineno - 1
        old = lines[idx]
        new = old.replace('const Color(', 'Color(', 1)
        if new != old:
            lines[idx] = new
            count += 1
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print(f'{filepath}: {count} unnecessary_const fixed')

# ai_company_builder_page.dart — lines from CI + likely extras
fix_uc('lib/pages/ai_company_builder_page.dart',
    [176, 184, 214, 271, 282, 461, 762])

# election_strategy_page.dart
fix_uc('lib/pages/election_strategy_page.dart',
    [165, 552, 690, 711, 867, 926])

# landing_page.dart
fix_uc('lib/pages/landing_page.dart',
    [1589, 2611, 2626, 2632])

"""
Fix unnecessary_const and require_trailing_commas in 3 files.
Based on CI error output from run 24609329892.
"""
import re

def fix_file(filepath, uc_lines, tc_lines):
    """
    uc_lines: list of 1-indexed line numbers with unnecessary_const (remove 'const Color(')
    tc_lines: list of (1-indexed line, 1-indexed col) with require_trailing_commas
              col points to the ')' that needs a comma before it
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Build set of lines that have BOTH fixes (tc column needs adjustment)
    uc_set = set(uc_lines)

    uc_count = 0
    for lineno in uc_lines:
        idx = lineno - 1
        old = lines[idx]
        new = old.replace('const Color(', 'Color(', 1)
        if new != old:
            lines[idx] = new
            uc_count += 1

    tc_count = 0
    for (lineno, col) in tc_lines:
        idx = lineno - 1
        line = lines[idx]
        # Adjust column if unnecessary_const was also fixed on same line
        # removing 'const ' (6 chars) shifts column by -6
        adj_col = col - 6 if lineno in uc_set else col
        pos = adj_col - 1  # 0-indexed
        if pos < len(line) and line[pos] == ')':
            lines[idx] = line[:pos] + ',' + line[pos:]
            tc_count += 1
        else:
            # Fallback: find pattern ),  and insert comma before last ) before ,
            # Replace the LAST occurrence of '), ' or '),' or '))\n' pattern
            new_line = re.sub(r'\),(\s*)$', r',),\1', line, count=1)
            if new_line != line:
                lines[idx] = new_line
                tc_count += 1
            else:
                print(f'  WARNING: trailing_comma fix failed at {filepath}:{lineno}:{col} (adj:{adj_col}) char="{line[pos] if pos < len(line) else "OUT_OF_RANGE"}"')

    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print(f'{filepath}: {uc_count} unnecessary_const, {tc_count} trailing_comma fixed')


# --- election_victory_page.dart ---
# Errors: 1818, 2827, 3839 — all unnecessary_const only
fix_file(
    'lib/pages/election_victory_page.dart',
    uc_lines=[1818, 2827, 3839],
    tc_lines=[]
)

# --- mindless_task_page.dart ---
# 3402: unnecessary_const
# 3584:77, 3631:77: require_trailing_commas
fix_file(
    'lib/pages/mindless_task_page.dart',
    uc_lines=[3402],
    tc_lines=[(3584, 77), (3631, 77)]
)

# --- morning_briefing_page.dart ---
# unnecessary_const lines (1-indexed):
MB_UC = [1335, 2196, 2323, 2379, 2393, 2456, 2790, 2868, 2899,
         2971, 2978, 3197, 3242, 3322, 3900, 4292, 4306, 4312,
         4613, 5006, 5017, 5021, 5082, 5115, 5129, 5175, 5179, 5185]
# require_trailing_commas: (line, col) from CI errors
# Lines 4292, 5017, 5021, 5082, 5175 also have unnecessary_const → col adjusts by -6
MB_TC = [
    (3492, 57),   # no UC on this line
    (4292, 79),   # UC also on 4292 → adj col = 73
    (5017, 59),   # UC also on 5017 → adj col = 53
    (5021, 65),   # UC also on 5021 → adj col = 59
    (5037, 59),   # no UC on 5037
    (5082, 69),   # UC also on 5082 → adj col = 63
    (5175, 59),   # UC also on 5175 → adj col = 53
]
fix_file(
    'lib/pages/morning_briefing_page.dart',
    uc_lines=MB_UC,
    tc_lines=MB_TC
)

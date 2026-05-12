#!/usr/bin/env python3
"""Generate SQL seed from design_compliance_data.dart and ui_improvement_rollout_data.dart"""
import re
import sys

COMPLIANCE_PATH = "lib/data/design_compliance_data.dart"
ROLLOUT_PATH = "lib/data/ui_improvement_rollout_data.dart"

def parse_compliance(content: str) -> list[dict]:
    records = []
    # Split by "PageComplianceRecord(" then parse each block
    parts = re.split(r'\bPageComplianceRecord\s*\(', content)
    for part in parts[1:]:  # skip preamble
        # Find the matching closing )
        depth = 1
        idx = 0
        for i, ch in enumerate(part):
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
                if depth == 0:
                    idx = i
                    break
        block = part[:idx]

        def extract(key, text):
            m = re.search(rf"{key}:\s*'([^']*)'", text)
            return m.group(1) if m else None

        def extract_enum(key, text):
            m = re.search(rf"{key}:\s*DesignCategory\.(\w+)", text)
            return m.group(1) if m else None

        def extract_list_bool(text):
            m = re.search(r'compliance:\s*\[([^\]]+)\]', text)
            if not m:
                return None
            items = [t.strip() for t in m.group(1).split(',') if t.strip()]
            return [t.lower() == 'true' for t in items]

        def extract_list_str(key, text):
            m = re.search(rf"{key}:\s*\[([^\]]*)\]", text)
            if not m:
                return None
            raw = m.group(1).strip()
            if not raw:
                return []
            items = [t.strip().strip("'") for t in raw.split(',') if t.strip()]
            return items

        route = extract('route', block)
        name = extract('name', block)
        cat = extract_enum('category', block)
        if not route or not name or not cat:
            continue

        compliance = extract_list_bool(block)
        audit_date = extract('auditDate', block)
        notes = extract('notes', block)
        mcp_tools = extract_list_str('mcpToolUsed', block)

        records.append({
            'route': route,
            'name': name,
            'category': cat,
            'compliance': compliance,
            'audit_date': audit_date,
            'notes': notes,
            'mcp_tool_used': mcp_tools,
        })
    return records


def parse_rollout_overrides(content: str) -> list[dict]:
    records = []
    # Find the const map
    map_match = re.search(r'kUiImprovementRolloutOverrides\s*=\s*<[^>]+>\s*\{(.+?)^\};',
                           content, re.DOTALL | re.MULTILINE)
    if not map_match:
        return records
    map_body = map_match.group(1)

    # Split by string key entries
    entry_pattern = re.compile(r"'([^']+)':\s*UiImprovementRollout\s*\(", re.DOTALL)
    positions = [(m.group(1), m.end()) for m in entry_pattern.finditer(map_body)]

    for i, (route, start) in enumerate(positions):
        end = positions[i+1][1] - len("UiImprovementRollout(") - 10 if i+1 < len(positions) else len(map_body)
        block = map_body[start:end]

        def ex_stage(key, text):
            m = re.search(rf"{key}:\s*Ui\w+\.(\w+)", text)
            if not m:
                return None
            v = m.group(1)
            # convert camelCase to snake_case
            if v == 'inProgress':
                return 'in_progress'
            return v  # applied / planned

        def ex_str(key, text):
            m = re.search(rf"{key}:\s*'([^']*(?:''[^']*)*)'", text)
            if not m:
                return ''
            return m.group(1)

        stage = ex_stage('stage', block)
        figma_mcp = ex_stage('figmaMcp', block)
        ai_designer = ex_stage('aiDesignerMcp', block)
        design_skills = ex_stage('designSkills', block)
        design_md = ex_stage('designMd', block)
        headline = ex_str('headline', block)
        next_step = ex_str('nextStep', block)
        updated_at = ex_str('updatedAt', block)

        if stage:
            records.append({
                'route': route,
                'stage': stage,
                'figma_mcp': figma_mcp,
                'ai_designer': ai_designer,
                'design_skills': design_skills,
                'design_md': design_md,
                'headline': headline,
                'next_step': next_step,
                'updated_at': updated_at or None,
            })
    return records


def esc(s):
    if s is None:
        return 'NULL'
    return "'" + str(s).replace("'", "''") + "'"


def bool_arr(lst):
    if lst is None:
        return 'NULL'
    return 'ARRAY[' + ','.join('true' if b else 'false' for b in lst) + ']::boolean[]'


def str_arr(lst):
    if lst is None:
        return 'NULL'
    if not lst:
        return "ARRAY[]::text[]"
    return 'ARRAY[' + ','.join("'" + t.replace("'", "''") + "'" for t in lst) + ']::text[]'


with open(COMPLIANCE_PATH, encoding='utf-8') as f:
    compliance_content = f.read()

with open(ROLLOUT_PATH, encoding='utf-8') as f:
    rollout_content = f.read()

compliance_records = parse_compliance(compliance_content)
rollout_records = parse_rollout_overrides(rollout_content)

print(f"-- Parsed {len(compliance_records)} compliance records, {len(rollout_records)} rollout records")

# Output SQL
print()
print("-- === design_screens seed ===")
print("INSERT INTO design_screens (route, name, category, compliance, audit_date, notes, mcp_tool_used)")
print("VALUES")
rows = []
for r in compliance_records:
    row = (
        f"  ({esc(r['route'])}, {esc(r['name'])}, {esc(r['category'])}, "
        f"{bool_arr(r['compliance'])}, "
        f"{esc(r['audit_date'])}, "
        f"{esc(r['notes'])}, "
        f"{str_arr(r['mcp_tool_used'])})"
    )
    rows.append(row)
print(",\n".join(rows))
print("ON CONFLICT (route) DO NOTHING;")
print()
print("-- === design_rollout seed ===")
print("INSERT INTO design_rollout (route, stage, figma_mcp, ai_designer, design_skills, design_md, headline, next_step)")
print("VALUES")
rrows = []
for r in rollout_records:
    row = (
        f"  ({esc(r['route'])}, {esc(r['stage'])}, {esc(r['figma_mcp'])}, "
        f"{esc(r['ai_designer'])}, {esc(r['design_skills'])}, {esc(r['design_md'])}, "
        f"{esc(r['headline'])}, {esc(r['next_step'])})"
    )
    rrows.append(row)
print(",\n".join(rrows))
print("ON CONFLICT (route) DO NOTHING;")

import sys
sys.stdout.reconfigure(encoding='utf-8')

# ─── gemini_university_v2_page.dart ───────────────────────────────────────────
F1 = "lib/pages/gemini_university_v2_page.dart"
c = open(F1, encoding="utf-8").read()

# 1. Remove unused theme_service import
c = c.replace(
    "import '../services/gamification_service.dart';\nimport '../services/theme_service.dart';\nimport 'ai_university_ranking_page.dart';",
    "import '../services/gamification_service.dart';\nimport 'ai_university_ranking_page.dart';"
)

# 2. Remove unused themeService + isDark variables
c = c.replace(
    "    final themeService = Provider.of<ThemeService>(context);\n    final isDark = themeService.isDarkMode;\n    final tc = _tabController;",
    "    final tc = _tabController;"
)
c = c.replace(
    "    final themeService = Provider.of<ThemeService>(context);\n    final tc = _tabController;",
    "    final tc = _tabController;"
)

# 3. Share card height 1.3 → 1.4
c = c.replace("              height: 1.3,", "              height: 1.4,", 1)

# 4. AppBar backgroundColor
c = c.replace(
    "        backgroundColor: const Color(0xFF1A0A2E),",
    "        backgroundColor: const Color(0xFF1A1A1A),"
)

# 5. TabBar indicatorColor
c = c.replace(
    "          indicatorColor: Colors.white,",
    "          indicatorColor: const Color(0xFF3D5AFE),"
)

# 6. isDark dead code in _buildProviderTab call site
c = c.replace(
    "                  .map((id) => _buildProviderTab(id, isDark))",
    "                  .map((id) => _buildProviderTab(id))"
)

# 7. _buildProviderTab signature
c = c.replace(
    "  Widget _buildProviderTab(String providerId, bool isDark) {",
    "  Widget _buildProviderTab(String providerId) {"
)

# 8. surface dead code
c = c.replace(
    "    final surface = isDark ? const Color(0xFF1E1E1E) : const Color(0xFF1E1E1E);",
    "    const surface = Color(0xFF1E1E1E);"
)

# 9. Markdown body height
c = c.replace(
    "    p: const TextStyle(color: Colors.white, height: 1.6),",
    "    p: const TextStyle(color: Colors.white, height: 1.7),"
)

# 10. h1/h2 height + letterSpacing
c = c.replace(
    "    h1: const TextStyle(\n      color: Colors.white,\n      fontSize: 20,\n      fontWeight: FontWeight.bold,\n    ),\n    h2: const TextStyle(\n      color: Color(0xFFE0E0E0),\n      fontSize: 17,\n      fontWeight: FontWeight.bold,\n    ),",
    "    h1: const TextStyle(\n      color: Colors.white,\n      fontSize: 20,\n      fontWeight: FontWeight.bold,\n      height: 1.4,\n      letterSpacing: 0.72,\n    ),\n    h2: const TextStyle(\n      color: Color(0xFFE0E0E0),\n      fontSize: 17,\n      fontWeight: FontWeight.bold,\n      height: 1.4,\n      letterSpacing: 0.68,\n    ),"
)

# 11. _buildContentCard — remove isDark param
c = c.replace(
    "  Widget _buildContentCard(\n    Map<String, dynamic> row,\n    bool isDark,\n    Color surface,\n  ) {",
    "  Widget _buildContentCard(\n    Map<String, dynamic> row,\n    Color surface,\n  ) {"
)
c = c.replace(
    "          ...rows.map((row) => _buildContentCard(row, isDark, surface))",
    "          ...rows.map((row) => _buildContentCard(row, surface))"
)

# 12. Quiz question height
c = c.replace(
    "              style: const TextStyle(fontWeight: FontWeight.w500),",
    "              style: const TextStyle(fontWeight: FontWeight.w500, height: 1.7, fontSize: 14),"
)

open(F1, "w", encoding="utf-8").write(c)
print("gemini_university_v2_page.dart: OK")

# ─── ai_university_home_card.dart ─────────────────────────────────────────────
F2 = "lib/widgets/ai_university_home_card.dart"
c2 = open(F2, encoding="utf-8").read()

c2 = c2.replace("      elevation: 4,", "      elevation: 0,")
c2 = c2.replace("      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),",
                 "      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),")
c2 = c2.replace("                          backgroundColor: Colors.white24,",
                 "                          backgroundColor: Colors.white.withValues(alpha: 0.24),")

open(F2, "w", encoding="utf-8").write(c2)
print("ai_university_home_card.dart: OK")

# ─── .markdownlint.json ───────────────────────────────────────────────────────
import json
config = {
    "MD013": False,
    "MD024": {"siblings_only": True},
    "MD029": False,
    "MD032": False,
    "MD036": False,
    "MD007": False,
    "MD034": False,
    "MD060": {"style": "compact"}
}
open(".markdownlint.json", "w", encoding="utf-8").write(json.dumps(config, indent=2) + "\n")
print(".markdownlint.json: OK")

# ─── .markdownlintignore ──────────────────────────────────────────────────────
ignore = open(".markdownlintignore", encoding="utf-8").read()
if "GROWTH_STRATEGY_ROADMAP" not in ignore:
    ignore += "\n# Append-only session log (historical entries not editable)\ndocs/GROWTH_STRATEGY_ROADMAP.md\n\n# Cross-instance coordination files (internal, not user-facing docs)\ndocs/cross-instance-prs/\n"
    open(".markdownlintignore", "w", encoding="utf-8").write(ignore)
    print(".markdownlintignore: updated")
else:
    print(".markdownlintignore: already has ROADMAP entry")

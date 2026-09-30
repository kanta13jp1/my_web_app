"""Regression contract for the six unapplied September course migrations."""
from pathlib import Path
from uuid import uuid4

CASES = {
    "20260903004500_update_aider_model_selection_course_evidence.sql": [("aider", "models")],
    "20260903014500_update_aider_overview_and_tutorial_course_evidence.sql": [("aider", "overview"), ("aider", "api")],
    "20260903015500_update_ai21_overview_and_models_course_evidence.sql": [("ai21", "overview"), ("ai21", "models")],
    "20260903020500_update_ai21_api_and_aleph_alpha_overview_course_evidence.sql": [("ai21", "api"), ("aleph_alpha", "overview")],
    "20260903021500_update_agno_agent_patterns_and_pricing_evidence.sql": [("agno", "models")],
    "20260903025500_update_agno_api_quickstart_course_evidence.sql": [("agno", "api")],
}


def check_course_migration_repair(conn, root: Path):
    with conn.cursor() as cur:
        cur.execute("SAVEPOINT course_migration_repair")
        try:
            targets = [pair for pairs in CASES.values() for pair in pairs]
            for provider, category in targets:
                cur.execute(
                    "INSERT INTO public.ai_university_content "
                    "(id,provider,category,title,content,published_at) "
                    "VALUES (%s,%s,%s,'contract course','original','2026-04-01')",
                    (uuid4(), provider, category),
                )
            cur.execute(
                "INSERT INTO public.ai_university_content "
                "(id,provider,category,title,content,published_at) "
                "VALUES (%s,'aider','news','Aider overview','preserve news','2026-04-01')",
                (uuid4(),),
            )
            sources = [(root / 'supabase' / 'migrations' / name).read_text(encoding='utf-8') for name in CASES]
            for source in sources:
                cur.execute(source)
            cur.execute("SELECT provider,category,content,published_at FROM public.ai_university_content WHERE provider IN ('aider','ai21','aleph_alpha','agno') ORDER BY provider,category")
            first = cur.fetchall()
            selected = {(p,c): (text,day) for p,c,text,day in first}
            for pair in targets:
                text, day = selected[pair]
                assert text != 'original' and len(text) > 100, pair
                assert str(day) == '2026-09-02', pair
            assert selected['aider','news'][0] == 'preserve news'
            for source in sources:
                cur.execute(source)
            cur.execute("SELECT provider,category,content,published_at FROM public.ai_university_content WHERE provider IN ('aider','ai21','aleph_alpha','agno') ORDER BY provider,category")
            assert cur.fetchall() == first, 'Reapplying must be idempotent'
            cur.execute("UPDATE public.ai_university_content SET content='newer revision',published_at='2026-09-21' WHERE provider='aider' AND category='models'")
            for source in sources:
                cur.execute(source)
            cur.execute("SELECT content FROM public.ai_university_content WHERE provider='aider' AND category='models'")
            assert cur.fetchone()[0] == 'newer revision', 'Do not overwrite newer content'
        finally:
            cur.execute("ROLLBACK TO SAVEPOINT course_migration_repair")
            cur.execute("RELEASE SAVEPOINT course_migration_repair")
    print('Course migration repair: 9 targets, unrelated news, repeat and newer-content guards passed')

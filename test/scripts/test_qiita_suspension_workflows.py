from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"


def workflow(name: str) -> str:
    return (WORKFLOWS / name).read_text(encoding="utf-8")


def test_scheduled_qiita_credentials_are_not_injected() -> None:
    engagement = workflow("blog-engagement.yml")
    verification = workflow("blog-verify.yml")

    secret_binding = "QIITA_ACCESS_TOKEN: ${{ secrets.QIITA_ACCESS_TOKEN }}"
    assert secret_binding not in engagement
    assert secret_binding not in verification


def test_scheduled_drafts_no_longer_target_qiita() -> None:
    news_draft = workflow("blog-news-signal-draft.yml")
    draft_register = workflow("blog-draft-register.yml")

    assert '"target_platforms": ["note", "devto"]' in news_draft
    assert '"target_platforms": ["note", "qiita", "devto"]' not in news_draft
    assert '"target_platforms": ["devto"]' in draft_register
    assert '"target_platforms": ["qiita", "devto"]' not in draft_register


def test_scheduled_publish_is_devto_only_and_ready_queue_fails_closed() -> None:
    publish = workflow("blog-publish.yml")

    assert 'PLATFORMS="qiita,devto"' not in publish
    assert publish.count('PLATFORMS="devto"') >= 2
    assert '"platforms": ["devto"]' in publish


def test_publish_status_only_advances_after_a_platform_returns_a_url() -> None:
    publish = workflow("blog-publish.yml")

    assert 'if [ -z "$QIITA_URL" ] && [ -z "$DEVTO_URL" ]; then' in publish
    assert "No platform publish succeeded; leaving the draft unpublished" in publish
    success_gate = (
        "(steps.publish.outputs.qiita_url != '' || "
        "steps.publish.outputs.devto_url != '')"
    )
    assert publish.count(success_gate) == 2
    assert 'STATUS="failure"' in publish

"""Prototype policy only; callers must fetch and authenticate every API object.

Not a CI gate: there is no GitHub API adapter or trusted workflow yet.
"""
from dataclasses import dataclass
import re

REQUIRED_AREAS = frozenset({'security', 'rollback', 'data migration', 'prod smoke', 'observability'})
RISKY_PATH = re.compile(
    r'(^supabase/(migrations|functions)/|^lib/(auth|billing|payments|subscription|firebase|supabase)/'
    r'|^\.github/workflows/.*\.ya?ml$|^\.github/actions/'
    r'|^scripts/[^/]*(review|gate|risk|security|policy)[^/]*\.py$'
    r'|^lib/services/supabase[^/]*\.dart$'
    r'|^firebase\.json$|^firestore\.|^storage\.|(^|/)\.env'
    r'|secret|credential|service[_-]?role|rls|payroll)', re.I)
RISKY_TEXT = re.compile(r'\b(secret|credential|token|auth|payment|billing|stripe|subscription|production|deploy|migration|rls|service[_ -]?role)\b', re.I)
RISKY_LABELS = frozenset({'security', 'supabase', 'edge-function', 'workflow-failure', 'priority:critical', 'deploy', 'production'})


@dataclass(frozen=True)
class Binding:
    repository: str
    pr: int
    base: str
    head: str


def is_high_risk(paths, title, body, labels):
    if not isinstance(paths, list) or not paths or not all(isinstance(x, str) and x for x in paths):
        raise ValueError('incomplete changed-file list')
    if not isinstance(title, str) or not isinstance(body, str) or not isinstance(labels, list):
        raise ValueError('incomplete PR data')
    return (any(RISKY_PATH.search(path.replace('\\', '/')) for path in paths)
            or bool(RISKY_TEXT.search(title + '\n' + body))
            or bool(RISKY_LABELS.intersection(x.lower() for x in labels)))


def evaluate(binding, paths, title, body, labels, evidence):
    """Return (pass, reason). `evidence` requires trusted provenance upstream.

    A passing body or an unsigned exception is never review evidence.
    """
    if (not isinstance(binding, Binding) or not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', binding.repository)
            or type(binding.pr) is not int or binding.pr <= 0
            or not re.fullmatch(r'[0-9a-f]{40}', binding.head) or not re.fullmatch(r'[0-9a-f]{40}', binding.base)):
        return False, 'invalid or missing immutable PR binding'
    try:
        high_risk = is_high_risk(paths, title, body, labels)
    except (TypeError, ValueError, AttributeError):
        return False, 'risk classification input unavailable'
    if not high_risk:
        return True, 'no high-risk trigger'
    if not isinstance(evidence, dict):
        return False, 'high-risk review evidence absent'
    expected = {'repository': binding.repository, 'pr': binding.pr, 'base': binding.base, 'head': binding.head}
    if any(evidence.get(k) != v for k, v in expected.items()):
        return False, 'evidence binding mismatch'
    if evidence.get('verdict') != 'approve' or type(evidence.get('unresolved')) is not int or evidence['unresolved'] != 0:
        return False, 'review not approved or findings unresolved'
    areas = evidence.get('areas')
    if not isinstance(areas, dict) or not REQUIRED_AREAS.issubset(areas):
        return False, 'required review perspectives missing'
    if any(not isinstance(areas[area], str) or len(areas[area].strip()) < 30 for area in REQUIRED_AREAS):
        return False, 'review perspective lacks substantive evidence'
    return True, 'bound high-risk review accepted by policy'

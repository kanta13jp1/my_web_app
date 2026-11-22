#!/usr/bin/env python3
"""Deterministic weekly PDCA funnel auditor for user acquisition growth.

Evaluates the end-to-end acquisition chain:
  X Impressions -> X Clicks -> LP Views -> AI Trial Starts -> Trial Successes
  -> Save CTA Clicks -> Signup Submits -> Verified Signups

Reads either a JSON snapshot (`--from-json`) or Supabase read-only REST
endpoints (`--from-supabase` using SUPABASE_SERVICE_ROLE_KEY from env, never
echoing secrets) and outputs a prioritized bottleneck diagnosis plus the single
recommended hypothesis for the next 1-week PDCA sprint.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
import os
from pathlib import Path
import sys
from typing import Any, Sequence
import urllib.request


DEFAULT_SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"


@dataclass(frozen=True)
class GrowthSnapshot:
    window_label: str
    captured_at: str
    total_users: int
    users_last_30d: int
    days_since_latest_signup: int | None
    days_since_latest_trial: int | None
    x_posts_tracked: int
    x_media_posts: int
    x_impressions: int
    x_url_clicks: int
    x_profile_clicks: int
    lp_views: int
    trial_starts: int
    trial_successes: int
    save_ctas: int
    signup_submits: int
    signup_completes: int

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> "GrowthSnapshot":
        def _int(key: str, default: int = 0) -> int:
            val = raw.get(key, default)
            return int(val) if val is not None else default

        def _opt_int(key: str) -> int | None:
            val = raw.get(key)
            return None if val is None else int(val)

        return cls(
            window_label=str(raw.get("window_label", "unknown")),
            captured_at=str(raw.get("captured_at", "")),
            total_users=_int("total_users"),
            users_last_30d=_int("users_last_30d"),
            days_since_latest_signup=_opt_int("days_since_latest_signup"),
            days_since_latest_trial=_opt_int("days_since_latest_trial"),
            x_posts_tracked=_int("x_posts_tracked"),
            x_media_posts=_int("x_media_posts"),
            x_impressions=_int("x_impressions"),
            x_url_clicks=_int("x_url_clicks"),
            x_profile_clicks=_int("x_profile_clicks"),
            lp_views=_int("lp_views"),
            trial_starts=_int("trial_starts"),
            trial_successes=_int("trial_successes"),
            save_ctas=_int("save_ctas"),
            signup_submits=_int("signup_submits"),
            signup_completes=_int("signup_completes"),
        )


@dataclass(frozen=True)
class PdcaReport:
    window_label: str
    captured_at: str
    primary_bottleneck: str
    secondary_bottleneck: str | None
    severity: str
    single_variable_hypothesis: str
    success_threshold: str
    pivot_threshold: str
    rates: dict[str, float]
    next_actions: list[str]
    snapshot: dict[str, Any]


def _safe_rate(num: int, den: int) -> float:
    if den <= 0:
        return 0.0
    return round((num / den) * 100.0, 2)


def diagnose_pdca(snapshot: GrowthSnapshot) -> PdcaReport:
    x_total_clicks = snapshot.x_url_clicks + snapshot.x_profile_clicks
    rates = {
        "x_click_rate_pct": _safe_rate(x_total_clicks, snapshot.x_impressions),
        "x_url_ctr_pct": _safe_rate(snapshot.x_url_clicks, snapshot.x_impressions),
        "x_media_ratio_pct": _safe_rate(snapshot.x_media_posts, snapshot.x_posts_tracked),
        "lp_to_trial_pct": _safe_rate(snapshot.trial_starts, snapshot.lp_views),
        "trial_success_pct": _safe_rate(snapshot.trial_successes, snapshot.trial_starts),
        "trial_to_save_pct": _safe_rate(snapshot.save_ctas, snapshot.trial_starts),
        "save_to_submit_pct": _safe_rate(snapshot.signup_submits, snapshot.save_ctas),
        "submit_to_complete_pct": _safe_rate(
            snapshot.signup_completes, snapshot.signup_submits
        ),
        "lp_to_signup_pct": _safe_rate(snapshot.signup_completes, snapshot.lp_views),
    }

    findings: list[tuple[str, str, str, str, str, list[str]]] = []

    trial_stalled = (
        snapshot.days_since_latest_trial is not None
        and snapshot.days_since_latest_trial >= 7
    ) or (snapshot.lp_views >= 20 and snapshot.trial_starts == 0)
    trial_failing = (
        snapshot.trial_starts > 0
        and snapshot.trial_successes < snapshot.trial_starts
        and rates["trial_success_pct"] < 80.0
    )
    if trial_stalled or trial_failing:
        findings.append(
            (
                "trial_provider_outage",
                "P0",
                "OpenAI 429 による AI 体験停止を Gemini フォールバックで復旧し、登録前1件体験の完走率を 95%+ に戻す",
                "landing.trial の実 AI 成功率 >= 95% かつ 7 日以内に実訪問者の Trial 完了 >= 10 件",
                "Gemini フォールバック後も HTTP 503 が 5% 超続く場合はプロンプト長・モデルタイムアウトを再調整",
                [
                    "growth-hub の landing.trial に GEMINI_API_KEY フォールバックを配備し、本番合成チェックで HTTP 200 を確認する",
                    "LP 流入時の最初の白→濃紺フラッシュと OGP カードを統一し、直帰率を下げる",
                ],
            )
        )

    if snapshot.trial_starts >= 10 and rates["trial_to_save_pct"] < 5.0:
        findings.append(
            (
                "trial_to_save_drop",
                "P0",
                "LP ヒーロー右パネルの「5つの短い質問」フリクションを撤廃し、1クリック即時AI提案＋結果カード直下のワンタップ保存導線へ単一変更する",
                "trial_to_save_pct >= 15.0% (現状 {:.2f}%) かつ save_ctas >= 5 件/週".format(
                    rates["trial_to_save_pct"]
                ),
                "100 trials 到達時に save_ctas < 3 件なら「提案を保存」以外のフック（例: PDF/Xシェア/明日の予定追加）へ切替",
                [
                    "Phase 2 LP UI 改修 PR を作成し、5 問ゲート廃止と「AIと一 / 緒に絞る」行折返し修正を実施する",
                    "白いサンプルカードをダークガラスに統一し、視認性と CTA コントラストを引き上げる",
                ],
            )
        )

    if snapshot.signup_submits >= 3 and snapshot.signup_completes == 0:
        findings.append(
            (
                "signup_completion_drop",
                "P1",
                "Google ワンタップ登録を主導線にしつつ、Magic Link 送信後の案内を明確化して登録完了率を引き上げる",
                "submit_to_complete_pct >= 40.0% かつ新規確定登録 >= 2 人/週",
                "Google OAuth 失敗が再発する場合はコールバック診断ログを点検し、パスワードレス以外の代替導線を検証",
                [
                    "landing_conversion_experiment で Magic Link / Google OAuth の離脱エラー内訳を確認する",
                    "登録直後オンボーディング画面で、試した1件の提案が自動引き継ぎされている状態を即表示する",
                ],
            )
        )

    if snapshot.x_impressions >= 500 and (
        rates["x_click_rate_pct"] < 1.0 or rates["x_media_ratio_pct"] < 30.0
    ):
        findings.append(
            (
                "x_click_starvation",
                "P1",
                "テキスト中心＋開発用語の X 投稿から、新 16:9 ビジュアルカード＋ユーザー価値フック＋統一 OGP カードへ切り替える",
                "X URL/プロフィールクリック率 >= 1.5% (または週 20 LP views 以上)",
                "2 週間テストでクリック率 < 0.5% の場合、投稿トピックを高反応帯（資産・固定費・AI活用実例）へピボット",
                [
                    "X プロフィール Bio と固定ポストを「価値提示 + 登録不要体験リンク」へ更新する（オーナー承認後）",
                    "高インプレッション領域（政策・生活実務データ）からの自然な導線を 16:9 カード付きで運用する",
                ],
            )
        )

    if snapshot.lp_views < 100:
        findings.append(
            (
                "top_of_funnel_volume",
                "P1",
                "X の高反応トピック投稿＋SEO比較/AI大学ページからの内部送客を増やし、週次 LP 流入母数を 150 views 以上へ引き上げる",
                "週次 LP views >= 150 かつ非匿名新規登録 >= 3 人/週",
                "2 週間で LP views < 50 に留まる場合、配布チャネルを比較記事・Zenn/GitHub・コミュニティへ分散",
                [
                    "SEO prerender 済みの比較・AI 大学・哲学ルートから無料体験への導線を強化する",
                    "週 3 回、ユーザー価値中心の Before/After 画像カード投稿を承認フローで回す",
                ],
            )
        )

    if not findings:
        findings.append(
            (
                "healthy_iteration",
                "P2",
                "全ファネル段階が基準を満たしているため、招待プログラムと体験結果シェアカードによるバイラル係数の引き上げを実験する",
                "週次新規登録 +20% かつ Day-7 アクティブ率 >= 30%",
                "招待流入シェアが 5% 未満ならシェア時のインセンティブ設計を見直す",
                [
                    "上位獲得アセット（OGP・フック別クリック率）の勝ちパターンを翌週テンプレートへ固定する",
                ],
            )
        )

    primary = findings[0]
    secondary = findings[1][0] if len(findings) > 1 else None
    return PdcaReport(
        window_label=snapshot.window_label,
        captured_at=snapshot.captured_at,
        primary_bottleneck=primary[0],
        secondary_bottleneck=secondary,
        severity=primary[1],
        single_variable_hypothesis=primary[2],
        success_threshold=primary[3],
        pivot_threshold=primary[4],
        rates=rates,
        next_actions=primary[5],
        snapshot=asdict(snapshot),
    )


def format_markdown_report(report: PdcaReport) -> str:
    snap = report.snapshot
    x_clicks = snap["x_url_clicks"] + snap["x_profile_clicks"]
    lines = [
        f"# ユーザー増加 PDCA 監査レポート ({report.window_label})",
        "",
        f"- **計測日時**: {report.captured_at or 'N/A'}",
        f"- **累計ユーザー / 直近30日新規**: {snap['total_users']}人 / {snap['users_last_30d']}人",
        f"- **最優先ボトルネック**: `{report.primary_bottleneck}` ({report.severity})"
        + (f" / 次点: `{report.secondary_bottleneck}`" if report.secondary_bottleneck else ""),
        "",
        "## ファネル実測サマリー",
        "",
        "| 段階 | 実測値 | 転換率・指標 |",
        "| --- | ---: | ---: |",
        f"| X インプレッション (計測 {snap['x_posts_tracked']} 投稿 / 画像率 {report.rates['x_media_ratio_pct']}%) | {snap['x_impressions']:,} | - |",
        f"| X クリック (URL {snap['x_url_clicks']} + Profile {snap['x_profile_clicks']}) | {x_clicks:,} | {report.rates['x_click_rate_pct']}% |",
        f"| LP 表示 (views) | {snap['lp_views']:,} | - |",
        f"| 登録前 AI 体験開始 (trials) | {snap['trial_starts']:,} | {report.rates['lp_to_trial_pct']}% |",
        f"| AI 体験成功 (success) | {snap['trial_successes']:,} | {report.rates['trial_success_pct']}% |",
        f"| 保存 CTA クリック (save_cta) | {snap['save_ctas']:,} | {report.rates['trial_to_save_pct']}% |",
        f"| 登録送信 (signup_submit) | {snap['signup_submits']:,} | {report.rates['save_to_submit_pct']}% |",
        f"| 確定登録完了 (signup_complete) | {snap['signup_completes']:,} | {report.rates['lp_to_signup_pct']}% |",
        "",
        "## 今週の単一変数 PDCA 仮説",
        "",
        f"- **動かす単一変数**: {report.single_variable_hypothesis}",
        f"- **Scale 判定基準 (成功)**: {report.success_threshold}",
        f"- **Iterate / Pivot 判定基準**: {report.pivot_threshold}",
        "",
        "## 次の推奨アクション",
        "",
    ]
    for action in report.next_actions:
        lines.append(f"- {action}")
    return "\n".join(lines) + "\n"


def _fetch_supabase_json(supabase_url: str, key: str, path: str) -> Any:
    url = f"{supabase_url.rstrip('/')}/rest/v1/{path}"
    req = urllib.request.Request(
        url,
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_snapshot_from_supabase(supabase_url: str, key: str) -> GrowthSnapshot:
    arms = _fetch_supabase_json(
        supabase_url,
        key,
        "landing_experiment_arm_stats?select=unique_views,unique_trials,"
        "unique_save_ctas,unique_signup_submits,non_anonymous_signup_completes",
    )
    # Deduplicate overlapping 20-arm counts using max per stage across hypotheses
    # or sum divided by 10 when arms partition traffic evenly; report conservative max.
    lp_views = sum(int(r.get("unique_views") or 0) for r in arms) // 10 if arms else 0
    trial_starts = max((int(r.get("unique_trials") or 0) for r in arms), default=0)
    save_ctas = max((int(r.get("unique_save_ctas") or 0) for r in arms), default=0)
    signup_submits = max((int(r.get("unique_signup_submits") or 0) for r in arms), default=0)
    signup_completes = sum(
        int(r.get("non_anonymous_signup_completes") or 0) for r in arms
    )
    return GrowthSnapshot(
        window_label="supabase-live-aggregate",
        captured_at="",
        total_users=0,
        users_last_30d=0,
        days_since_latest_signup=None,
        days_since_latest_trial=None,
        x_posts_tracked=0,
        x_media_posts=0,
        x_impressions=0,
        x_url_clicks=0,
        x_profile_clicks=0,
        lp_views=lp_views,
        trial_starts=trial_starts,
        trial_successes=trial_starts,
        save_ctas=save_ctas,
        signup_submits=signup_submits,
        signup_completes=signup_completes,
    )


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--from-json", type=Path, help="Input GrowthSnapshot JSON path.")
    parser.add_argument(
        "--from-supabase",
        action="store_true",
        help="Read aggregate funnel stats from Supabase REST using SUPABASE_SERVICE_ROLE_KEY.",
    )
    parser.add_argument("--supabase-url", default=os.getenv("SUPABASE_URL", DEFAULT_SUPABASE_URL))
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    parser.add_argument("--output", type=Path, help="Optional file path for generated output.")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = parse_args(argv)
    if args.from_json:
        raw = json.loads(args.from_json.read_text(encoding="utf-8"))
        snapshot = GrowthSnapshot.from_dict(raw)
    elif args.from_supabase:
        key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        if not key:
            print("SUPABASE_SERVICE_ROLE_KEY is required for --from-supabase", file=sys.stderr)
            return 2
        snapshot = fetch_snapshot_from_supabase(args.supabase_url, key)
    else:
        print("Specify --from-json <path> or --from-supabase", file=sys.stderr)
        return 2

    report = diagnose_pdca(snapshot)
    rendered = (
        json.dumps(asdict(report), ensure_ascii=False, indent=2) + "\n"
        if args.format == "json"
        else format_markdown_report(report)
    )
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

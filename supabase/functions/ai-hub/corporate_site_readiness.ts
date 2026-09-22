export type CorporateSiteCheckStatus =
  | "present"
  | "missing"
  | "manual_review";

export type CorporateSiteProfile = {
  companyName: string;
  representativeName: string;
  registeredAddress: string;
  businessPlanSummary: string;
  virtualOffice: boolean;
};

export type CorporateSiteReadinessCheck = {
  id: string;
  label: string;
  status: CorporateSiteCheckStatus;
  required: boolean;
  evidence: string | null;
  guidance: string;
};

export type CorporateSiteReadinessResult = {
  readyForDocumentReview: boolean;
  score: number;
  checks: CorporateSiteReadinessCheck[];
  missingRequiredItems: string[];
  manualReviewItems: string[];
  disclaimer: string;
};

export type CorporateSiteGenerationInput = CorporateSiteProfile & {
  contact: string;
  wbsMilestones: string[];
};

const DISCLAIMER =
  "この結果は公開ページの記載有無を確認する補助情報で、法人口座の審査通過を保証しません。銀行の総合判断により、契約書・請求書などの追加資料や第三者が作成した事業証明を求められる場合があります。";

function bounded(value: unknown, label: string, max: number): string {
  const text = typeof value === "string" ? value.trim() : "";
  if (!text) throw new Error(`${label} is required`);
  if (text.length > max) {
    throw new Error(`${label} must be ${max} characters or fewer`);
  }
  return text;
}

export function validateCorporateSiteProfile(
  rawProfile: CorporateSiteProfile,
): CorporateSiteProfile {
  return {
    companyName: bounded(rawProfile.companyName, "company name", 200),
    representativeName: bounded(
      rawProfile.representativeName,
      "representative name",
      120,
    ),
    registeredAddress: bounded(
      rawProfile.registeredAddress,
      "registered address",
      300,
    ),
    businessPlanSummary: bounded(
      rawProfile.businessPlanSummary,
      "business plan summary",
      4000,
    ),
    virtualOffice: rawProfile.virtualOffice === true,
  };
}

function normalizeForMatch(value: string): string {
  return value.normalize("NFKC").toLocaleLowerCase("ja-JP")
    .replace(/(\d+)丁目/g, "$1")
    .replace(/(\d+)番(?:地)?/g, "$1")
    .replace(/(\d+)号/g, "$1")
    .replace(
      /[\s\u3000.,，。・:：;；/／\\()（）［］\[\]「」『』【】'"“”‘’\-_―ー–—〒]/g,
      "",
    );
}

function evidenceLine(
  markdown: string,
  matcher: (line: string) => boolean,
): string | null {
  for (const rawLine of markdown.split(/\r?\n/)) {
    const line = rawLine.replace(/^#{1,6}\s+|^[-*>]\s+/g, "").trim();
    if (line && matcher(line)) return line.slice(0, 240);
  }
  return null;
}

function exactFieldCheck(
  markdown: string,
  id: string,
  label: string,
  expected: string,
  contextPattern: RegExp | null,
  guidance: string,
): CorporateSiteReadinessCheck {
  const target = normalizeForMatch(expected);
  const evidence = evidenceLine(markdown, (line) => {
    if (!normalizeForMatch(line).includes(target)) return false;
    return contextPattern === null || contextPattern.test(line);
  });
  return {
    id,
    label,
    status: evidence ? "present" : "missing",
    required: true,
    evidence,
    guidance,
  };
}

function businessKeywords(summary: string): string[] {
  const stopWords = new Set([
    "こと",
    "ため",
    "および",
    "または",
    "サービス",
    "事業",
    "提供",
  ]);
  return summary.normalize("NFKC")
    .split(/[\s\u3000、。,.，・:：;；/／()（）［］\[\]「」『』【】]+/)
    .flatMap((value) =>
      value.split(
        /(?:向け|として|について|サービス|事業|提供|販売|します|する|から|まで|の|を|で|に|へ|と|が|は)/,
      )
    )
    .map((value) => normalizeForMatch(value))
    .filter((value) =>
      value.length >= 2 && value.length <= 30 && !stopWords.has(value)
    )
    .slice(0, 12);
}

function businessDetailsCheck(
  markdown: string,
  summary: string,
): CorporateSiteReadinessCheck {
  const keywords = businessKeywords(summary);
  const concretePattern =
    /(料金|価格|費用|円|商品|サービス|提供|販売|購入|申込|利用|契約|納品|顧客|対象|業務|実績)/i;
  const evidence = evidenceLine(markdown, (line) => {
    if (!concretePattern.test(line)) return false;
    if (keywords.length === 0) return true;
    const normalized = normalizeForMatch(line);
    return keywords.some((keyword) => normalized.includes(keyword));
  });
  return {
    id: "business_details",
    label: "具体的な事業内容",
    status: evidence ? "present" : "missing",
    required: true,
    evidence,
    guidance:
      "商品・サービス、対象顧客、提供方法、料金などを具体的に掲載してください。",
  };
}

export function reviewCorporateSiteDocument(
  markdown: string,
  rawProfile: CorporateSiteProfile,
): CorporateSiteReadinessResult {
  const document = bounded(markdown, "site document", 1_000_000);
  const profile = validateCorporateSiteProfile(rawProfile);

  const checks: CorporateSiteReadinessCheck[] = [
    exactFieldCheck(
      document,
      "company_name",
      "登記上の法人名",
      profile.companyName,
      null,
      "登記どおりの法人名を会社概要に掲載してください。",
    ),
    exactFieldCheck(
      document,
      "representative_name",
      "代表者名",
      profile.representativeName,
      /(代表|代表取締役|代表者|CEO|社長)/i,
      "代表者の役職と氏名を会社概要に掲載してください。",
    ),
    exactFieldCheck(
      document,
      "registered_address",
      "登記上の本店所在地",
      profile.registeredAddress,
      /(所在地|本店|本社|住所)/i,
      "登記どおりの本店所在地を、所在地であると分かる見出しとともに掲載してください。",
    ),
    businessDetailsCheck(document, profile.businessPlanSummary),
    {
      id: "operating_evidence",
      label: "事業の運営実態",
      status: "manual_review",
      required: false,
      evidence: null,
      guidance:
        "公開期間、取引実績、契約書・請求書などは自動判定できません。銀行へ提出できる証拠を目視確認してください。",
    },
  ];

  if (profile.virtualOffice) {
    checks.push({
      id: "virtual_office_evidence",
      label: "バーチャルオフィス利用時の補足資料",
      status: "manual_review",
      required: false,
      evidence: null,
      guidance:
        "バーチャルオフィスでも申込可能な銀行がありますが、事業内容や運営実態を示す追加資料を準備してください。",
    });
  }

  const requiredChecks = checks.filter((check) => check.required);
  const presentCount =
    requiredChecks.filter((check) => check.status === "present").length;
  const missingRequiredItems = requiredChecks
    .filter((check) => check.status === "missing")
    .map((check) => check.id);
  return {
    readyForDocumentReview: missingRequiredItems.length === 0,
    score: Math.round((presentCount / requiredChecks.length) * 100),
    checks,
    missingRequiredItems,
    manualReviewItems: checks
      .filter((check) => check.status === "manual_review")
      .map((check) => check.id),
    disclaimer: DISCLAIMER,
  };
}

function escapeHtml(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;")
    .replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

function safeParagraphs(value: string): string {
  return value.split(/\r?\n/).map((line) => line.trim()).filter(Boolean)
    .map((line) => `<p>${escapeHtml(line)}</p>`).join("\n        ");
}

export function generateCorporateSiteHtml(
  rawInput: CorporateSiteGenerationInput,
): string {
  const profile = validateCorporateSiteProfile(rawInput);
  if (
    !Array.isArray(rawInput.wbsMilestones) ||
    rawInput.wbsMilestones.length === 0
  ) {
    throw new Error("at least one WBS milestone is required");
  }
  const input: CorporateSiteGenerationInput = {
    ...profile,
    contact: bounded(rawInput.contact, "contact", 300),
    wbsMilestones:
      (Array.isArray(rawInput.wbsMilestones) ? rawInput.wbsMilestones : [])
        .map((item) => bounded(item, "WBS milestone", 300))
        .slice(0, 20),
  };
  const milestones = input.wbsMilestones.length === 0
    ? "<li>準備中</li>"
    : input.wbsMilestones.map((item) => `<li>${escapeHtml(item)}</li>`).join(
      "\n          ",
    );
  return `<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(input.companyName)} | 公式サイト</title>
  <style>
    :root { color-scheme: light; --ink: #102a43; --accent: #0f766e; --paper: #f7fafc; }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: system-ui, -apple-system, "Noto Sans JP", sans-serif; color: var(--ink); background: var(--paper); line-height: 1.8; }
    header, main, footer { width: min(960px, calc(100% - 32px)); margin-inline: auto; }
    header { padding: 72px 0 40px; }
    header p { max-width: 680px; font-size: 1.1rem; }
    section { margin: 0 0 24px; padding: 32px; border-radius: 16px; background: white; box-shadow: 0 8px 30px rgb(16 42 67 / 8%); }
    h1, h2 { line-height: 1.35; }
    h1 { font-size: clamp(2rem, 6vw, 3.5rem); margin: 0 0 12px; }
    h2 { color: var(--accent); }
    dl { display: grid; grid-template-columns: minmax(9rem, 0.35fr) 1fr; gap: 12px 20px; }
    dt { font-weight: 700; }
    dd { margin: 0; }
    footer { padding: 24px 0 48px; font-size: .9rem; }
    @media (max-width: 600px) { section { padding: 22px; } dl { grid-template-columns: 1fr; gap: 4px; } dd { margin-bottom: 12px; } }
  </style>
</head>
<body>
  <header>
    <h1>${escapeHtml(input.companyName)}</h1>
    <p>私たちの事業内容、会社情報、今後の取り組みをご案内します。</p>
  </header>
  <main>
    <section id="business">
      <h2>事業内容</h2>
      ${safeParagraphs(input.businessPlanSummary)}
    </section>
    <section id="roadmap">
      <h2>事業計画・主な取り組み</h2>
      <ol>
          ${milestones}
      </ol>
    </section>
    <section id="company">
      <h2>会社概要</h2>
      <dl>
        <dt>法人名</dt><dd>${escapeHtml(input.companyName)}</dd>
        <dt>代表者</dt><dd>代表取締役 ${
    escapeHtml(input.representativeName)
  }</dd>
        <dt>本店所在地</dt><dd>${escapeHtml(input.registeredAddress)}</dd>
        <dt>お問い合わせ</dt><dd>${escapeHtml(input.contact)}</dd>
      </dl>
    </section>
  </main>
  <footer>&copy; ${escapeHtml(input.companyName)}</footer>
</body>
</html>`;
}

export const CORPORATE_SITE_READINESS_DISCLAIMER = DISCLAIMER;

type UnknownRecord = Record<string, unknown>;

export type PayslipProviderRequest = {
  provider: string;
  model?: string;
  messages: { role: string; content: string }[];
};

export type PayslipProviderResult = {
  ok: boolean;
  text?: string;
  modelUsed?: string;
  error?: string;
  isRetriable?: boolean;
};

export type PayslipProviderInvoker = (
  request: PayslipProviderRequest,
) => Promise<PayslipProviderResult>;

type QueryResult = {
  data?: unknown | null;
  error?: { message?: string } | null;
};

export type PayslipDbQuery = {
  upsert(
    value: UnknownRecord,
    options?: { onConflict?: string },
  ): {
    select(columns?: string): {
      single(): Promise<QueryResult>;
    };
  };
};

export type PayslipDb = {
  from(table: string): PayslipDbQuery;
};

export type PayslipStorageBucket = {
  download(path: string): Promise<{
    data?: Blob | ArrayBuffer | Uint8Array | null;
    error?: { message?: string } | null;
  }>;
};

export type PayslipStorage = {
  from(bucket: string): PayslipStorageBucket;
};

export type ParsedPayslip = {
  pay_date: string | null;
  company_name: string;
  gross_amount: number;
  net_amount: number;
  taxable_amount: number | null;
  social_insurance_total: number | null;
  deductions: UnknownRecord;
  earnings: UnknownRecord;
  attendance: UnknownRecord;
  confidence: number;
  parsed_by: string;
};

export type PayslipIngestionResult = {
  status: "parsed" | "needs_review";
  payslip: UnknownRecord;
  parsed: ParsedPayslip;
  masked_text_preview: string;
  warnings: string[];
};

export class PayslipIngestionError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "PayslipIngestionError";
    this.status = status;
  }
}

const DEDUCTION_FIELDS = [
  ["health_insurance", ["健康保険", "health insurance"]],
  ["pension", ["厚生年金", "pension"]],
  ["employment_insurance", ["雇用保険", "employment insurance"]],
  ["income_tax", ["所得税", "income tax"]],
  ["resident_tax", ["住民税", "resident tax"]],
  ["ideco", ["iDeCo", "ideco"]],
] as const;

const EARNING_FIELDS = [
  ["base_salary", ["基本給", "base salary"]],
  ["fixed_overtime", ["固定残業", "fixed overtime"]],
  ["overtime", ["時間外", "残業手当", "overtime"]],
  ["allowance", ["手当", "allowance"]],
  ["commuting", ["通勤手当", "commuting", "transportation"]],
] as const;

export function isPayslipIngestionAction(action: string): boolean {
  return action === "payslip.parse" || action === "parse-payslip";
}

export function normalizePayslipStoragePath(value: unknown): {
  bucket: string;
  path: string;
  fullPath: string;
} {
  const raw = typeof value === "string" ? value.trim() : "";
  if (!raw) {
    throw new PayslipIngestionError("storage_path is required", 400);
  }
  const withoutSlash = raw.replace(/^\/+/, "");
  if (withoutSlash.startsWith("payslips/")) {
    const path = withoutSlash.slice("payslips/".length);
    return { bucket: "payslips", path, fullPath: `payslips/${path}` };
  }
  return { bucket: "payslips", path: withoutSlash, fullPath: withoutSlash };
}

export function maskPayslipPii(text: string): string {
  return text
    .replace(
      /(氏名|名前|社員名|従業員名)\s*[:：]?\s*[^\s]+/g,
      "$1: [MASKED_NAME]",
    )
    .replace(
      /(社員番号|従業員番号|従業員No\.?|employee\s*id)\s*[:：#]?\s*[A-Za-z0-9-]+/gi,
      "$1: [MASKED_EMPLOYEE_ID]",
    )
    .replace(
      /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi,
      "[MASKED_EMAIL]",
    )
    .replace(/\b\d{8,12}\b/g, "[MASKED_NUMBER]");
}

export function decodePdfBytesToCandidateText(bytes: Uint8Array): string {
  const utf8 = new TextDecoder("utf-8", { fatal: false }).decode(bytes);
  const utf16be = decodeUtf16BeFragments(bytes);
  return cleanPdfCandidateText(`${utf8}\n${utf16be}`);
}

export function parsePayslipText(text: string): ParsedPayslip {
  const normalized = normalizeText(text);
  const deductions: UnknownRecord = {};
  for (const [key, labels] of DEDUCTION_FIELDS) {
    const amount = findAmountByLabels(normalized, labels);
    if (amount !== null) deductions[key] = amount;
  }

  const earnings: UnknownRecord = {};
  for (const [key, labels] of EARNING_FIELDS) {
    const amount = findAmountByLabels(normalized, labels);
    if (amount !== null) earnings[key] = amount;
  }

  const attendance: UnknownRecord = {};
  const workDays = findNumberByLabels(normalized, ["出勤日数", "勤務日数"]);
  const overtimeHours = findNumberByLabels(normalized, [
    "残業時間",
    "時間外時間",
  ]);
  if (workDays !== null) attendance.work_days = workDays;
  if (overtimeHours !== null) attendance.overtime_hours = overtimeHours;

  const parsed: ParsedPayslip = {
    pay_date: findPayDate(normalized),
    company_name: findCompanyName(normalized),
    gross_amount: findAmountByLabels(normalized, [
      "総支給額",
      "支給合計",
      "gross amount",
      "total earnings",
    ]) ?? 0,
    net_amount: findAmountByLabels(normalized, [
      "差引支給額",
      "差引支給",
      "銀行振込額",
      "振込支給額",
      "手取り",
      "net amount",
      "net pay",
    ]) ?? 0,
    taxable_amount: findAmountByLabels(normalized, [
      "課税対象額",
      "課税支給額",
    ]),
    social_insurance_total: findAmountByLabels(normalized, [
      "社会保険料計",
      "社会保険合計",
    ]),
    deductions,
    earnings,
    attendance,
    confidence: 0,
    parsed_by: "deterministic_text_layer",
  };
  parsed.confidence = scoreParsedPayslip(parsed);
  return parsed;
}

export async function handleParsePayslipAction(options: {
  db: PayslipDb;
  storage: PayslipStorage;
  body: UnknownRecord;
  userId: string;
  invokeProvider?: PayslipProviderInvoker;
}): Promise<PayslipIngestionResult> {
  const storagePath = normalizePayslipStoragePath(
    options.body.storage_path ?? options.body.source_pdf_path,
  );
  const download = await options.storage.from(storagePath.bucket).download(
    storagePath.path,
  );
  if (download.error) {
    throw new PayslipIngestionError(
      `payslip download failed: ${download.error.message ?? "unknown"}`,
      404,
    );
  }
  const bytes = await storagePayloadToBytes(download.data);
  if (bytes.length === 0) {
    throw new PayslipIngestionError("payslip PDF was empty", 400);
  }

  const rawText = decodePdfBytesToCandidateText(bytes);
  const maskedText = maskPayslipPii(rawText);
  const warnings: string[] = [];
  let parsed = parsePayslipText(maskedText);
  const aiFallbackEnabled = options.body.enable_ai_fallback === true ||
    Deno.env.get("PAYSLIP_AI_PARSE_ENABLED") === "true";
  if (
    aiFallbackEnabled && parsed.confidence < 0.72 && options.invokeProvider
  ) {
    const providerResult = await options.invokeProvider({
      provider: "google",
      model: typeof options.body.model === "string"
        ? options.body.model
        : "gemini-2.5-flash",
      messages: buildPayslipExtractionMessages(maskedText),
    });
    if (providerResult.ok && providerResult.text) {
      const providerParsed = parseProviderPayslipJson(providerResult.text);
      if (providerParsed && providerParsed.confidence >= parsed.confidence) {
        parsed = {
          ...providerParsed,
          parsed_by: providerResult.modelUsed ?? "llm_fallback",
        };
      }
    } else {
      warnings.push(
        `AI fallback skipped: ${providerResult.error ?? "empty response"}`,
      );
    }
  }

  validateParsedPayslip(parsed);
  const reviewStatus = parsed.confidence >= 0.72 ? "auto" : "needs_review";
  const rawTextSha256 = await sha256Hex(maskedText);
  const payslipRow = {
    user_id: options.userId,
    pay_date: parsed.pay_date,
    company_name: parsed.company_name || "unknown",
    gross_amount: parsed.gross_amount,
    net_amount: parsed.net_amount,
    taxable_amount: parsed.taxable_amount,
    social_insurance_total: parsed.social_insurance_total,
    deductions: parsed.deductions,
    earnings: parsed.earnings,
    attendance: parsed.attendance,
    source_pdf_path: storagePath.fullPath,
    parsed_by: parsed.parsed_by,
    confidence: parsed.confidence,
    raw_text_sha256: rawTextSha256,
    review_status: reviewStatus,
  };

  let persistedPayslip: UnknownRecord = payslipRow;
  if (options.body.dry_run !== true) {
    const { data, error } = await options.db.from("payslips")
      .upsert(payslipRow, { onConflict: "user_id,pay_date,company_name" })
      .select(
        "id,user_id,pay_date,company_name,gross_amount,net_amount,confidence,review_status,source_pdf_path",
      )
      .single();
    if (error) {
      throw new PayslipIngestionError(
        `payslips upsert failed: ${error.message ?? "unknown"}`,
        500,
      );
    }
    persistedPayslip = asRecord(data) ?? payslipRow;
    await options.db.from("salary_incomes")
      .upsert({
        user_id: options.userId,
        pay_date: parsed.pay_date,
        amount: parsed.net_amount,
        description: `Payslip: ${parsed.company_name || "salary"}`,
        source: "payslip_auto",
        payslip_id: persistedPayslip.id ?? null,
        confidence: parsed.confidence,
      }, { onConflict: "user_id,pay_date,source" })
      .select("id")
      .single();
  }

  return {
    status: reviewStatus === "auto" ? "parsed" : "needs_review",
    payslip: persistedPayslip,
    parsed,
    masked_text_preview: maskedText.slice(0, 1200),
    warnings,
  };
}

function buildPayslipExtractionMessages(maskedText: string) {
  return [
    {
      role: "system",
      content:
        "Extract one Japanese payslip into strict JSON. Return only JSON. Do not infer identity fields.",
    },
    {
      role: "user",
      content: JSON.stringify({
        schema: {
          pay_date: "YYYY-MM-DD",
          company_name: "string",
          gross_amount: "number",
          net_amount: "number",
          taxable_amount: "number|null",
          social_insurance_total: "number|null",
          deductions: "object",
          earnings: "object",
          attendance: "object",
          confidence: "0..1",
        },
        masked_text: maskedText.slice(0, 16000),
      }),
    },
  ];
}

function parseProviderPayslipJson(text: string): ParsedPayslip | null {
  const parsed = extractJsonObject(text);
  if (!parsed) return null;
  const result: ParsedPayslip = {
    pay_date: readDateString(parsed.pay_date),
    company_name: readString(parsed.company_name) || "unknown",
    gross_amount: readAmount(parsed.gross_amount) ?? 0,
    net_amount: readAmount(parsed.net_amount) ?? 0,
    taxable_amount: readAmount(parsed.taxable_amount),
    social_insurance_total: readAmount(parsed.social_insurance_total),
    deductions: asRecord(parsed.deductions) ?? {},
    earnings: asRecord(parsed.earnings) ?? {},
    attendance: asRecord(parsed.attendance) ?? {},
    confidence: clamp01(readNumber(parsed.confidence, 0.7)),
    parsed_by: "llm_fallback",
  };
  return result;
}

function validateParsedPayslip(parsed: ParsedPayslip) {
  if (!parsed.pay_date) {
    throw new PayslipIngestionError("pay_date could not be parsed", 422);
  }
  if (parsed.net_amount <= 0) {
    throw new PayslipIngestionError("net_amount could not be parsed", 422);
  }
}

async function storagePayloadToBytes(
  data: Blob | ArrayBuffer | Uint8Array | null | undefined,
): Promise<Uint8Array> {
  if (!data) return new Uint8Array();
  if (data instanceof Uint8Array) return data;
  if (data instanceof ArrayBuffer) return new Uint8Array(data);
  if (typeof (data as Blob).arrayBuffer === "function") {
    return new Uint8Array(await (data as Blob).arrayBuffer());
  }
  return new Uint8Array();
}

function normalizeText(text: string): string {
  return text
    .replace(
      /[０-９]/g,
      (char) => String.fromCharCode(char.charCodeAt(0) - 0xfee0),
    )
    .replace(/[，]/g, ",")
    .replace(/[￥]/g, "¥")
    .replace(/\r/g, "\n")
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n");
}

function cleanPdfCandidateText(text: string): string {
  return text
    .replace(/\0/g, "")
    .replace(/[^\S\r\n]+/g, " ")
    .split(/\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .join("\n")
    .slice(0, 100000);
}

function decodeUtf16BeFragments(bytes: Uint8Array): string {
  const chars: number[] = [];
  for (let i = 0; i < bytes.length - 1; i += 2) {
    const code = (bytes[i] << 8) | bytes[i + 1];
    if (
      code === 0x000a ||
      code === 0x000d ||
      code === 0x0020 ||
      (code >= 0x0030 && code <= 0x9fff)
    ) {
      chars.push(code);
    }
  }
  return String.fromCharCode(...chars.slice(0, 60000));
}

function findAmountByLabels(
  text: string,
  labels: readonly string[],
): number | null {
  for (const label of labels) {
    const index = text.toLowerCase().indexOf(label.toLowerCase());
    if (index < 0) continue;
    const after = text.slice(index + label.length, index + label.length + 96);
    const amount = readAmount(after);
    if (amount !== null) return amount;
  }
  return null;
}

function findNumberByLabels(
  text: string,
  labels: readonly string[],
): number | null {
  for (const label of labels) {
    const index = text.indexOf(label);
    if (index < 0) continue;
    const after = text.slice(index + label.length, index + label.length + 48);
    const match = after.match(/[-+]?\d+(?:\.\d+)?/);
    if (!match) continue;
    const value = Number(match[0]);
    if (Number.isFinite(value)) return value;
  }
  return null;
}

function findPayDate(text: string): string | null {
  const labeled = text.match(
    /(支給日|給与支給日|pay\s*date)[^\d]*(\d{4})[\/年.-](\d{1,2})[\/月.-](\d{1,2})/i,
  );
  if (labeled) {
    return formatDateParts(labeled[2], labeled[3], labeled[4]);
  }
  const any = text.match(/(\d{4})[\/年.-](\d{1,2})[\/月.-](\d{1,2})/);
  return any ? formatDateParts(any[1], any[2], any[3]) : null;
}

function findCompanyName(text: string): string {
  const match = text.match(
    /([^\s]{0,24}株式会社[^\s]{0,24}|株式会社[^\s]{1,32})/,
  );
  return match ? match[1].slice(0, 80) : "unknown";
}

function formatDateParts(year: string, month: string, day: string): string {
  return `${year.padStart(4, "0")}-${month.padStart(2, "0")}-${
    day.padStart(2, "0")
  }`;
}

function readAmount(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.max(0, value);
  }
  if (value == null) return null;
  const text = String(value).replace(
    /[０-９]/g,
    (char) => String.fromCharCode(char.charCodeAt(0) - 0xfee0),
  );
  const match = text.match(/[-+]?¥?\s*\d[\d,]*(?:\.\d+)?/);
  if (!match) return null;
  const parsed = Number(match[0].replace(/[¥,\s]/g, ""));
  return Number.isFinite(parsed) ? Math.abs(parsed) : null;
}

function readNumber(value: unknown, fallback: number): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (value == null) return fallback;
  const parsed = Number(String(value).replace(/,/g, ""));
  return Number.isFinite(parsed) ? parsed : fallback;
}

function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function readDateString(value: unknown): string | null {
  const raw = readString(value);
  if (!raw) return null;
  const date = raw.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  return date ? raw : findPayDate(raw);
}

function scoreParsedPayslip(parsed: ParsedPayslip): number {
  let score = 0;
  if (parsed.pay_date) score += 0.22;
  if (parsed.company_name && parsed.company_name !== "unknown") score += 0.08;
  if (parsed.gross_amount > 0) score += 0.18;
  if (parsed.net_amount > 0) score += 0.24;
  if (parsed.taxable_amount !== null) score += 0.08;
  if (parsed.social_insurance_total !== null) score += 0.08;
  score += Math.min(Object.keys(parsed.deductions).length, 4) * 0.025;
  score += Math.min(Object.keys(parsed.earnings).length, 3) * 0.02;
  return clamp01(score);
}

function clamp01(value: number): number {
  return Math.max(0, Math.min(1, Math.round(value * 1000) / 1000));
}

function extractJsonObject(text: string): UnknownRecord | null {
  const trimmed = text.replace(/```json|```/g, "").trim();
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    const parsed = JSON.parse(trimmed.slice(start, end + 1));
    return asRecord(parsed);
  } catch {
    return null;
  }
}

function asRecord(value: unknown): UnknownRecord | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as UnknownRecord;
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

import {
  handleParsePayslipAction,
  inferPayslipPayDateFromPath,
  maskPayslipPii,
  parsePayslipText,
  type PayslipDb,
  type PayslipDbQuery,
  type PayslipStorage,
} from "./payslip_ingestion.ts";

Deno.test("inferPayslipPayDateFromPath prefers pay date after upload timestamp", () => {
  assertEquals(
    inferPayslipPayDateFromPath(
      "user-1/20260526_082024-2026-05-25-2026-04-30-payslip.pdf",
    ),
    "2026-05-25",
  );
});

Deno.test("inferPayslipPayDateFromPath reads Japanese pay-date filenames", () => {
  assertEquals(
    inferPayslipPayDateFromPath(
      "2026\u5e7405\u670825\u65e5\u652f\u7d66_2026\u5e7404\u670830\u65e5\u7de0_\u7d66\u4e0e\u660e\u7d30.pdf",
    ),
    "2026-05-25",
  );
});

Deno.test("maskPayslipPii removes identity fields before AI fallback", () => {
  const masked = maskPayslipPii(
    "氏名: 山田太郎\n従業員番号: EMP-12345\nmail taro@example.com",
  );
  assertEquals(masked.includes("山田太郎"), false);
  assertEquals(masked.includes("EMP-12345"), false);
  assertEquals(masked.includes("taro@example.com"), false);
  assertEquals(masked.includes("[MASKED_NAME]"), true);
});

Deno.test("parsePayslipText extracts core money fields", () => {
  const parsed = parsePayslipText(`
    株式会社サンプル
    支給日 2026年05月25日
    総支給額 520,000
    課税対象額 480,000
    社会保険料計 71,000
    健康保険 24,000
    厚生年金 45,000
    差引支給額 465,108
  `);

  assertEquals(parsed.pay_date, "2026-05-25");
  assertEquals(parsed.company_name, "株式会社サンプル");
  assertEquals(parsed.gross_amount, 520000);
  assertEquals(parsed.net_amount, 465108);
  assertEquals(parsed.social_insurance_total, 71000);
  assertEquals(parsed.deductions.health_insurance, 24000);
  assertEquals(parsed.confidence >= 0.72, true);
});

Deno.test("handleParsePayslipAction upserts payslip and salary income", async () => {
  const db = new FakeDb();
  const storage = new FakeStorage(`
    株式会社サンプル
    支給日 2026/05/25
    総支給額 520,000
    差引支給額 465,108
  `);

  const result = await handleParsePayslipAction({
    db,
    storage,
    userId: "user-1",
    body: { storage_path: "user-1/20260525.pdf" },
  });

  assertEquals(result.status, "parsed");
  assertEquals(db.upserts[0].table, "payslips");
  assertEquals(db.upserts[0].value.net_amount, 465108);
  assertEquals(db.upserts[1].table, "salary_incomes");
  assertEquals(db.upserts[1].value.source, "payslip_auto");
});

Deno.test("合成: 低信頼でも給与 provider を呼ばず保存契約を維持", async () => {
  // Process-local fake flag only; restore after the test. No PDF is used.
  const old = Deno.env.get("PAYSLIP_AI_PARSE_ENABLED");
  try {
    for (const envEnabled of [false, true]) {
      Deno.env.set("PAYSLIP_AI_PARSE_ENABLED", String(envEnabled));
      for (const action of ["payslip.parse", "parse-payslip"]) {
        for (const clientEnabled of [false, true]) {
          const db = new FakeDb();
          const storage = new FakeStorage(`支給日: 2026-05-25\n差引支給額: 120000`);
          let providerCalls = 0;
          const result = await handleParsePayslipAction({
            db,
            storage,
            userId: "synthetic-owner",
            body: {
              action,
              storage_path: "synthetic-owner/fixture.txt",
              enable_ai_fallback: clientEnabled,
            },
            invokeProvider: () => {
              providerCalls++;
              return Promise.resolve({ ok: false, error: "synthetic spy" });
            },
          });
          assertEquals(result.status, "needs_review");
        assertEquals(result.parsed.pay_date, "2026-05-25");
        assertEquals(result.parsed.net_amount, 120000);
        assertEquals(result.parsed.confidence < 0.72, true);
        assertEquals(db.upserts[0].table, "payslips");
        assertEquals(db.upserts[1].table, "salary_incomes");
        assertEquals(db.upserts[0].value.review_status, "needs_review");
        assertEquals(db.upserts[0].value.pay_date, "2026-05-25");
        assertEquals(db.upserts[0].value.net_amount, 120000);
        assertEquals(db.upserts[1].value.pay_date, "2026-05-25");
        assertEquals(db.upserts[1].value.amount, 120000);
        assertEquals(Object.prototype.hasOwnProperty.call(db.upserts[1].value, "review_status"), false);
        assertEquals(providerCalls, 0);
          assertEquals(db.upserts.length, 2);
        }
      }
    }
  } finally {
    if (old == null) Deno.env.delete("PAYSLIP_AI_PARSE_ENABLED");
    else Deno.env.set("PAYSLIP_AI_PARSE_ENABLED", old);
  }
});

Deno.test("合成: 高信頼でも給与 provider を呼ばず保存契約を維持", async () => {
  // Process-local fake flag only; restore after the test. No PDF is used.
  const old = Deno.env.get("PAYSLIP_AI_PARSE_ENABLED");
  try {
    for (const envEnabled of [false, true]) {
      Deno.env.set("PAYSLIP_AI_PARSE_ENABLED", String(envEnabled));
      for (const action of ["payslip.parse", "parse-payslip"]) {
        for (const clientEnabled of [false, true]) {
          const db = new FakeDb();
          const storage = new FakeStorage(`会社名: 株式会社架空商事\n支給日: 2026-05-25\n総支給額: 150000\n差引支給額: 120000`);
          let providerCalls = 0;
          const result = await handleParsePayslipAction({
            db,
            storage,
            userId: "synthetic-owner",
            body: {
              action,
              storage_path: "synthetic-owner/fixture.txt",
              enable_ai_fallback: clientEnabled,
            },
            invokeProvider: () => {
              providerCalls++;
              return Promise.resolve({ ok: false, error: "synthetic spy" });
            },
          });
          assertEquals(result.status, "parsed");
        assertEquals(result.parsed.pay_date, "2026-05-25");
        assertEquals(result.parsed.net_amount, 120000);
        assertEquals(result.parsed.confidence < 0.72, false);
        assertEquals(db.upserts[0].table, "payslips");
        assertEquals(db.upserts[1].table, "salary_incomes");
        assertEquals(db.upserts[0].value.review_status, "auto");
        assertEquals(db.upserts[0].value.pay_date, "2026-05-25");
        assertEquals(db.upserts[0].value.net_amount, 120000);
        assertEquals(db.upserts[1].value.pay_date, "2026-05-25");
        assertEquals(db.upserts[1].value.amount, 120000);
        assertEquals(Object.prototype.hasOwnProperty.call(db.upserts[1].value, "review_status"), false);
        assertEquals(providerCalls, 0);
          assertEquals(db.upserts.length, 2);
        }
      }
    }
  } finally {
    if (old == null) Deno.env.delete("PAYSLIP_AI_PARSE_ENABLED");
    else Deno.env.set("PAYSLIP_AI_PARSE_ENABLED", old);
  }
});

Deno.test("合成: 必須値不足の既存エラーと provider なし", async () => {
  // Process-local fake flag only; restore after the test. No PDF is used.
  const old = Deno.env.get("PAYSLIP_AI_PARSE_ENABLED");
  try {
    for (const envEnabled of [false, true]) {
      Deno.env.set("PAYSLIP_AI_PARSE_ENABLED", String(envEnabled));
      for (const action of ["payslip.parse", "parse-payslip"]) {
        for (const clientEnabled of [false, true]) {
          const db = new FakeDb();
          const storage = new FakeStorage(`支給日: 2026-05-25`);
          let providerCalls = 0;
          let caught: unknown;
        try {
          await handleParsePayslipAction({
            db,
            storage,
            userId: "synthetic-owner",
            body: {
              action,
              storage_path: "synthetic-owner/fixture.txt",
              enable_ai_fallback: clientEnabled,
            },
            invokeProvider: () => {
              providerCalls++;
              return Promise.resolve({ ok: false, error: "synthetic spy" });
            },
          });
        } catch (error) {
          caught = error;
        }
          assertEquals(caught instanceof Error, true);
        assertEquals((caught as { status: number }).status, 422);
        assertEquals(providerCalls, 0);
          assertEquals(db.upserts.length, 0);
        }
      }
    }
  } finally {
    if (old == null) Deno.env.delete("PAYSLIP_AI_PARSE_ENABLED");
    else Deno.env.set("PAYSLIP_AI_PARSE_ENABLED", old);
  }
});

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Assertion failed:\nactual:   ${JSON.stringify(actual)}\nexpected: ${
        JSON.stringify(expected)
      }`,
    );
  }
}

class FakeDb implements PayslipDb {
  upserts: Array<{ table: string; value: Record<string, unknown> }> = [];

  from(table: string): PayslipDbQuery {
    return new FakeQuery(table, this);
  }
}

class FakeQuery implements PayslipDbQuery {
  constructor(
    private readonly table: string,
    private readonly db: FakeDb,
  ) {}

  upsert(value: Record<string, unknown>) {
    this.db.upserts.push({ table: this.table, value });
    return {
      select: () => ({
        single: () =>
          Promise.resolve({
            data: { id: `${this.table}-1`, ...value },
            error: null,
          }),
      }),
    };
  }
}

class FakeStorage implements PayslipStorage {
  constructor(private readonly text: string) {}

  from() {
    return {
      download: () =>
        Promise.resolve({
          data: new TextEncoder().encode(this.text),
          error: null,
        }),
    };
  }
}

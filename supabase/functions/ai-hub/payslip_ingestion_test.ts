import {
  handleParsePayslipAction,
  maskPayslipPii,
  parsePayslipText,
  type PayslipDb,
  type PayslipDbQuery,
  type PayslipStorage,
} from "./payslip_ingestion.ts";

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

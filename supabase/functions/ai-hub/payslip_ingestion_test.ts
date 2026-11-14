import {
  handleParsePayslipAction,
  isPayslipIngestionAction,
  PayslipIngestionError,
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

Deno.test("合成: 確認前の解析は給与テーブルを書き込まない", async () => {
  const fixtures = [
    {
      text: `支給日: 2026-05-25\n差引支給額: 120000`,
      lowConfidence: true,
    },
    {
      text: `会社名: 株式会社架空商事\n支給日: 2026-05-25\n総支給額: 150000\n差引支給額: 120000`,
      lowConfidence: false,
    },
  ];
  const old = Deno.env.get("PAYSLIP_AI_PARSE_ENABLED");
  try {
    for (const envEnabled of [false, true]) {
      Deno.env.set("PAYSLIP_AI_PARSE_ENABLED", String(envEnabled));
      for (const action of ["payslip.parse", "parse-payslip"]) {
        assertEquals(isPayslipIngestionAction(action), true);
        for (const clientEnabled of [false, true]) {
          for (const flags of [
            {},
            { dry_run: false },
            { dry_run: true },
            { confirmed: true },
          ]) {
            for (const fixture of fixtures) {
              const db = new FakeDb();
              const storage = new FakeStorage(fixture.text);
              let providerCalls = 0;
              const result = await handleParsePayslipAction({
                db,
                storage,
                userId: "synthetic-owner",
                body: {
                  action,
                  storage_path: "synthetic-owner/fixture.txt",
                  enable_ai_fallback: clientEnabled,
                  preview_only: true,
                  ...flags,
                },
                invokeProvider: () => {
                  providerCalls++;
                  return Promise.resolve({ ok: false, error: "synthetic spy" });
                },
              });
              assertEquals(result.status, "preview_only");
              assertEquals(result.persisted, false);
              assertEquals(result.parsed.pay_date, "2026-05-25");
              assertEquals(result.parsed.net_amount, 120000);
              assertEquals(result.parsed.confidence < 0.72, fixture.lowConfidence);
              assertEquals(result.payslip.review_status, "needs_review");
              assertEquals(
                Object.prototype.hasOwnProperty.call(result.payslip, "id"),
                false,
              );
              assertEquals(db.upserts.length, 0);
              assertEquals(providerCalls, 0);
            }
          }
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
                  preview_only: true,
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

Deno.test("payslip owner boundary denies ambiguous paths before storage access", async () => {
  const invalid = [
    { userId: "", path: "synthetic-owner/file.pdf", status: 403 },
    { userId: "synthetic-owner", path: "", status: 400 },
    { userId: "synthetic-owner", path: "other-owner/file.pdf", status: 403 },
    { userId: "synthetic-owner", path: "synthetic-owner-extra/file.pdf", status: 403 },
    { userId: "synthetic-owner", path: "synthetic-owner/../other/file.pdf", status: 403 },
    { userId: "synthetic-owner", path: "synthetic-owner//file.pdf", status: 403 },
    { userId: "synthetic-owner", path: "synthetic-owner/%2e%2e%2ffile.pdf", status: 403 },
    { userId: "synthetic-owner", path: "synthetic-owner/file%2fpdf", status: 403 },
    { userId: "synthetic-owner", path: "synthetic-owner/..", status: 403 },
    { userId: "synthetic-owner", path: "synthetic-owner/", status: 403 },
    { userId: "synthetic-owner/extra", path: "synthetic-owner/extra/file.pdf", status: 403 },
    { userId: "synthetic-owner", path: "synthetic-owner/other\\file.pdf", status: 403 },
  ];
  for (const sample of invalid) {
    let storageCalls = 0;
    const db = new FakeDb();
    const storage: PayslipStorage = {
      from: () => {
        storageCalls++;
        return { download: () => Promise.resolve({ data: null, error: null }) };
      },
    };
    let caught: unknown;
    try {
      await handleParsePayslipAction({
        userId: sample.userId,
        body: { storage_path: sample.path, dry_run: true, preview_only: true },
        db,
        storage,
      });
    } catch (error) {
      caught = error;
    }
    assertEquals(caught instanceof PayslipIngestionError, true);
    assertEquals((caught as PayslipIngestionError).status, sample.status);
    assertEquals(storageCalls, 0);
    assertEquals(db.upserts.length, 0);
  }
});

Deno.test("payslip owner boundary accepts normalized current UI paths", async () => {
  const paths = [
    "synthetic-owner/20261108_010203-sample.pdf",
    "payslips/synthetic-owner/20261108_010203-sample.pdf",
    "///synthetic-owner/20261108_010203-sample.pdf",
  ];
  for (const path of paths) {
    let bucketSeen = "";
    let pathSeen = "";
    const db = new FakeDb();
    const storage: PayslipStorage = {
      from: (bucket) => {
        bucketSeen = bucket;
        return { download: (value) => {
          pathSeen = value;
          return Promise.resolve({ data: null, error: { message: "synthetic stop" } });
        } };
      },
    };
    let caught: unknown;
    try {
      await handleParsePayslipAction({
        userId: "synthetic-owner",
        body: { storage_path: path, dry_run: true, preview_only: true },
        db,
        storage,
      });
    } catch (error) {
      caught = error;
    }
    assertEquals(caught instanceof PayslipIngestionError, true);
    assertEquals(bucketSeen, "payslips");
    assertEquals(pathSeen, "synthetic-owner/20261108_010203-sample.pdf");
    assertEquals(db.upserts.length, 0);
  }
});

Deno.test("payslip path guard preserves safe Unicode nested keys", async () => {
  const samples = [
    { raw: "synthetic-owner/年次 保管/給与 明細.pdf", key: "synthetic-owner/年次 保管/給与 明細.pdf" },
    { raw: "payslips/synthetic-owner/2026年/給与 明細.pdf", key: "synthetic-owner/2026年/給与 明細.pdf" },
    { raw: "///synthetic-owner/新しい 明細.pdf", key: "synthetic-owner/新しい 明細.pdf" },
  ];
  for (const sample of samples) {
    let bucketSeen = "";
    let pathSeen = "";
    const db = new FakeDb();
    const storage: PayslipStorage = {
      from: (bucket) => {
        bucketSeen = bucket;
        return { download: (path) => {
          pathSeen = path;
          return Promise.resolve({ data: null, error: { message: "synthetic stop" } });
        } };
      },
    };
    let caught: unknown;
    try {
      await handleParsePayslipAction({
        userId: "synthetic-owner", body: { storage_path: sample.raw, dry_run: true, preview_only: true },
        db, storage,
      });
    } catch (error) {
      caught = error;
    }
    assertEquals(caught instanceof PayslipIngestionError, true);
    assertEquals(bucketSeen, "payslips");
    assertEquals(pathSeen, sample.key);
    assertEquals(db.upserts.length, 0);
  }
});

Deno.test("payslip path guard rejects ambiguous Unicode and encodings", async () => {
  const invalid = [
    "synthetic-owner/sub/../file.pdf",
    "synthetic-owner/sub//file.pdf",
    "synthetic-owner/sub/%20name.pdf",
    "synthetic-owner/sub/%252e%252e/file.pdf",
    "synthetic-owner/sub/ leading.pdf",
    "synthetic-owner/．．/file.pdf",
    "synthetic-owner/sub／other/file.pdf",
    "synthetic-owner/sub\\other/file.pdf",
    "synthetic-owner/sub/file?other.pdf",
    "synthetic-owner/sub/\u202Efile.pdf",
    "synthetic-owner/sub/\uD800file.pdf",
  ];
  for (const path of invalid) {
    let storageCalls = 0;
    const db = new FakeDb();
    const storage: PayslipStorage = {
      from: () => {
        storageCalls++;
        return { download: () => Promise.resolve({ data: null, error: null }) };
      },
    };
    let caught: unknown;
    try {
      await handleParsePayslipAction({
        userId: "synthetic-owner", body: { storage_path: path, dry_run: true, preview_only: true },
        db, storage,
      });
    } catch (error) {
      caught = error;
    }
    assertEquals(caught instanceof PayslipIngestionError, true);
    assertEquals((caught as PayslipIngestionError).status, 403);
    assertEquals(storageCalls, 0);
    assertEquals(db.upserts.length, 0);
  }
});

Deno.test("payslip path rejects input-edge whitespace before storage access", async () => {
  const paths = [
    " synthetic-owner/folder/file.pdf",
    "synthetic-owner/folder/file.pdf ",
    "payslips/synthetic-owner/file.pdf\u00A0",
    "\tsynthetic-owner/file.pdf",
    " ",
  ];
  for (const path of paths) {
    let storageCalls = 0;
    const db = new FakeDb();
    const storage: PayslipStorage = {
      from: () => {
        storageCalls++;
        return { download: () => Promise.resolve({ data: null, error: null }) };
      },
    };
    let caught: unknown;
    try {
      await handleParsePayslipAction({
        userId: "synthetic-owner", body: { storage_path: path, dry_run: true, preview_only: true },
        db, storage,
      });
    } catch (error) {
      caught = error;
    }
    assertEquals(caught instanceof PayslipIngestionError, true);
    assertEquals((caught as PayslipIngestionError).status, 400);
    assertEquals(storageCalls, 0);
    assertEquals(db.upserts.length, 0);
  }
});

Deno.test("payslip path preserves internal whitespace through the SDK call", async () => {
  const key = "synthetic-owner/保管 場所/給与 明細.pdf";
  let keySeen = "";
  const db = new FakeDb();
  const storage: PayslipStorage = {
    from: () => ({ download: (path) => {
      keySeen = path;
      return Promise.resolve({ data: null, error: { message: "synthetic stop" } });
    } }),
  };
  let caught: unknown;
  try {
    await handleParsePayslipAction({
      userId: "synthetic-owner", body: { storage_path: key, dry_run: true, preview_only: true },
      db, storage,
    });
  } catch (error) {
    caught = error;
  }
  assertEquals(caught instanceof PayslipIngestionError, true);
  assertEquals(keySeen, key);
  assertEquals(db.upserts.length, 0);
});


Deno.test("legacy or malformed callers fail before storage and provider", async () => {
  for (const action of ["payslip.parse", "parse-payslip"]) {
    for (const preview of [undefined, false, null, "true", 1]) {
      const db = new FakeDb();
      let storageCalls = 0;
      let providerCalls = 0;
      const storage: PayslipStorage = {
        from: () => {
          storageCalls++;
          return { download: () => Promise.resolve({ data: null, error: null }) };
        },
      };
      let caught: unknown;
      try {
        await handleParsePayslipAction({
          db, storage, userId: "synthetic-owner",
          body: {
            action, storage_path: "synthetic-owner/fixture.txt",
            ...(preview === undefined ? {} : { preview_only: preview }),
          },
          invokeProvider: () => {
            providerCalls++;
            return Promise.resolve({ ok: false, error: "synthetic spy" });
          },
        });
      } catch (error) {
        caught = error;
      }
      assertEquals(caught instanceof PayslipIngestionError, true);
      assertEquals((caught as PayslipIngestionError).status, 409);
      assertEquals(storageCalls, 0);
      assertEquals(db.upserts.length, 0);
      assertEquals(providerCalls, 0);
    }
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

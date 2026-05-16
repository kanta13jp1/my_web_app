import {
  attachDepartmentCounts,
  attachFacultyCounts,
  buildProviderCounts,
} from "./university_faculty_actions.ts";

Deno.test("attachFacultyCounts adds active department and content totals", () => {
  const faculties = [
    baseFaculty("faculty-ai", "ai"),
    baseFaculty("faculty-cloud", "cloud"),
  ];
  const departments = [
    baseDepartment("dept-llm", "faculty-ai", "llm"),
    baseDepartment("dept-agent", "faculty-ai", "agent"),
    baseDepartment("dept-aws", "faculty-cloud", "aws"),
  ];
  const contents = [
    { id: "content-1", faculty_id: "faculty-ai" },
    { id: "content-2", faculty_id: "faculty-ai" },
    { id: "content-3", faculty_id: "faculty-cloud" },
  ];

  const result = attachFacultyCounts(faculties, departments, contents);

  assertEquals(result[0].department_count, 2);
  assertEquals(result[0].content_count, 2);
  assertEquals(result[1].department_count, 1);
  assertEquals(result[1].content_count, 1);
});

Deno.test("attachDepartmentCounts uses distinct provider counts per department", () => {
  const departments = [
    baseDepartment("dept-llm", "faculty-ai", "llm"),
    baseDepartment("dept-aws", "faculty-cloud", "aws"),
  ];
  const contents = [
    { provider: "openai", department_id: "dept-llm" },
    { provider: "openai", department_id: "dept-llm" },
    { provider: "anthropic", department_id: "dept-llm" },
    { provider: "aws_ec2", department_id: "dept-aws" },
  ];

  const result = attachDepartmentCounts(departments, contents);

  assertEquals(result[0].provider_count, 2);
  assertEquals(result[0].content_count, 3);
  assertEquals(result[1].provider_count, 1);
  assertEquals(result[1].content_count, 1);
});

Deno.test("buildProviderCounts groups and sorts provider rows", () => {
  const result = buildProviderCounts([
    { provider: "zeta" },
    { provider: "alpha" },
    { provider: "zeta" },
    { provider: "" },
    { provider: null },
  ]);

  assertEquals(result, [
    { provider: "alpha", content_count: 1 },
    { provider: "zeta", content_count: 2 },
  ]);
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

function baseFaculty(id: string, code: string) {
  return {
    id,
    faculty_code: code,
    name_ja: code,
    name_en: code,
    description: null,
    emoji: null,
    sort_order: 10,
  };
}

function baseDepartment(id: string, facultyId: string, code: string) {
  return {
    id,
    faculty_id: facultyId,
    department_code: code,
    name_ja: code,
    name_en: code,
    description: null,
    emoji: null,
    sort_order: 10,
  };
}

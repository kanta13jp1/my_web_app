type DbError = { message: string };
type DbResult<T> = { data: T | null; error?: DbError | null };
type QueryLike<T> = PromiseLike<DbResult<T>> & {
  select(columns: string): QueryLike<T>;
  eq(column: string, value: unknown): QueryLike<T>;
  order(column: string, options?: { ascending?: boolean }): QueryLike<T>;
  range(from: number, to: number): QueryLike<T>;
  maybeSingle(): PromiseLike<DbResult<T | null>>;
};
type UniversityDb = {
  from(table: string): { select(columns: string): QueryLike<unknown> };
};

type FacultyRow = {
  id: string;
  faculty_code: string;
  name_ja: string;
  name_en: string;
  description: string | null;
  emoji: string | null;
  sort_order: number;
};

type DepartmentRow = {
  id: string;
  faculty_id: string;
  department_code: string;
  name_ja: string;
  name_en: string;
  description: string | null;
  emoji: string | null;
  sort_order: number;
};

type ContentRow = {
  id?: string;
  provider?: string | null;
  faculty_id?: string | null;
  department_id?: string | null;
  [key: string]: unknown;
};

export type FacultySummary = FacultyRow & {
  department_count: number;
  content_count: number;
};

export type DepartmentSummary = DepartmentRow & {
  provider_count: number;
  content_count: number;
};

export type ProviderSummary = {
  provider: string;
  content_count: number;
};

export class UniversityActionError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "UniversityActionError";
    this.status = status;
  }
}

export function attachFacultyCounts(
  faculties: FacultyRow[],
  departments: DepartmentRow[],
  contents: ContentRow[],
): FacultySummary[] {
  const departmentCounts = new Map<string, number>();
  const contentCounts = new Map<string, number>();
  for (const department of departments) {
    departmentCounts.set(
      department.faculty_id,
      (departmentCounts.get(department.faculty_id) ?? 0) + 1,
    );
  }
  for (const item of contents) {
    if (!item.faculty_id) continue;
    contentCounts.set(
      item.faculty_id,
      (contentCounts.get(item.faculty_id) ?? 0) + 1,
    );
  }
  return faculties.map((faculty) => ({
    ...faculty,
    department_count: departmentCounts.get(faculty.id) ?? 0,
    content_count: contentCounts.get(faculty.id) ?? 0,
  }));
}

export function attachDepartmentCounts(
  departments: DepartmentRow[],
  contents: ContentRow[],
): DepartmentSummary[] {
  const contentCounts = new Map<string, number>();
  const providersByDepartment = new Map<string, Set<string>>();
  for (const item of contents) {
    if (!item.department_id) continue;
    contentCounts.set(
      item.department_id,
      (contentCounts.get(item.department_id) ?? 0) + 1,
    );
    if (typeof item.provider === "string" && item.provider.trim()) {
      const providers = providersByDepartment.get(item.department_id) ??
        new Set<string>();
      providers.add(item.provider);
      providersByDepartment.set(item.department_id, providers);
    }
  }
  return departments.map((department) => ({
    ...department,
    provider_count: providersByDepartment.get(department.id)?.size ?? 0,
    content_count: contentCounts.get(department.id) ?? 0,
  }));
}

export function buildProviderCounts(contents: ContentRow[]): ProviderSummary[] {
  const counts = new Map<string, number>();
  for (const item of contents) {
    if (typeof item.provider !== "string" || !item.provider.trim()) continue;
    counts.set(item.provider, (counts.get(item.provider) ?? 0) + 1);
  }
  return [...counts.entries()]
    .map(([provider, content_count]) => ({ provider, content_count }))
    .sort((a, b) => a.provider.localeCompare(b.provider));
}

export async function getUniversityFacultyList(db: unknown) {
  const source = db as UniversityDb;
  const faculties = await queryRows<FacultyRow>(
    source.from("university_faculties")
      .select("id,faculty_code,name_ja,name_en,description,emoji,sort_order")
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .order("faculty_code", { ascending: true }),
  );
  const departments = await queryRows<DepartmentRow>(
    source.from("university_departments")
      .select(
        "id,faculty_id,department_code,name_ja,name_en,description,emoji,sort_order",
      )
      .eq("is_active", true),
  );
  const contents = await queryRows<ContentRow>(
    source.from("ai_university_content")
      .select("id,faculty_id")
      .eq("is_active", true),
  );
  return { faculties: attachFacultyCounts(faculties, departments, contents) };
}

export async function getUniversityDepartmentList(
  db: unknown,
  body: Record<string, unknown>,
) {
  const source = db as UniversityDb;
  const faculty = await resolveFaculty(source, body);
  const departments = await queryRows<DepartmentRow>(
    source.from("university_departments")
      .select(
        "id,faculty_id,department_code,name_ja,name_en,description,emoji,sort_order",
      )
      .eq("faculty_id", faculty.id)
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .order("department_code", { ascending: true }),
  );
  const contents = await queryRows<ContentRow>(
    source.from("ai_university_content")
      .select("id,provider,department_id")
      .eq("is_active", true),
  );
  return {
    faculty,
    departments: attachDepartmentCounts(departments, contents),
  };
}

export async function getUniversityProviderByDepartment(
  db: unknown,
  body: Record<string, unknown>,
) {
  const source = db as UniversityDb;
  const department = await resolveDepartment(source, body);
  const contents = await queryRows<ContentRow>(
    source.from("ai_university_content")
      .select("provider,department_id")
      .eq("department_id", department.id)
      .eq("is_active", true),
  );
  return {
    department,
    providers: buildProviderCounts(contents),
  };
}

export async function getUniversityContentByFaculty(
  db: unknown,
  body: Record<string, unknown>,
) {
  const source = db as UniversityDb;
  const faculty = await resolveFaculty(source, body);
  const limit = boundedInt(body.limit, 200, 1, 500);
  const offset = boundedInt(body.offset, 0, 0, 10000);
  const items = await queryRows<ContentRow>(
    source.from("ai_university_content")
      .select("*")
      .eq("faculty_id", faculty.id)
      .eq("is_active", true)
      .order("published_at", { ascending: false })
      .range(offset, offset + limit - 1),
  );
  return { faculty, items, limit, offset };
}

async function resolveFaculty(
  db: UniversityDb,
  body: Record<string, unknown>,
): Promise<FacultyRow> {
  const facultyId = asTrimmedString(body.faculty_id);
  const facultyCode = asTrimmedString(body.faculty_code);
  if (!facultyId && !facultyCode) {
    throw new UniversityActionError("faculty_id or faculty_code required");
  }
  let query = db.from("university_faculties")
    .select("id,faculty_code,name_ja,name_en,description,emoji,sort_order")
    .eq("is_active", true);
  query = facultyId
    ? query.eq("id", facultyId)
    : query.eq("faculty_code", facultyCode);
  return await querySingle<FacultyRow>(
    query.maybeSingle(),
    "faculty not found",
  );
}

async function resolveDepartment(
  db: UniversityDb,
  body: Record<string, unknown>,
): Promise<DepartmentRow> {
  const departmentId = asTrimmedString(body.department_id);
  const departmentCode = asTrimmedString(body.department_code);
  if (departmentId) {
    return await querySingle<DepartmentRow>(
      db.from("university_departments")
        .select(
          "id,faculty_id,department_code,name_ja,name_en,description,emoji,sort_order",
        )
        .eq("id", departmentId)
        .eq("is_active", true)
        .maybeSingle(),
      "department not found",
    );
  }
  if (!departmentCode) {
    throw new UniversityActionError(
      "department_id or department_code required",
    );
  }
  const faculty = await resolveFaculty(db, body);
  return await querySingle<DepartmentRow>(
    db.from("university_departments")
      .select(
        "id,faculty_id,department_code,name_ja,name_en,description,emoji,sort_order",
      )
      .eq("faculty_id", faculty.id)
      .eq("department_code", departmentCode)
      .eq("is_active", true)
      .maybeSingle(),
    "department not found",
  );
}

async function queryRows<T>(
  query: PromiseLike<DbResult<unknown>>,
): Promise<T[]> {
  const { data, error } = await query;
  if (error) throw new UniversityActionError(error.message, 500);
  return Array.isArray(data) ? data as T[] : [];
}

async function querySingle<T>(
  query: PromiseLike<DbResult<unknown>>,
  notFoundMessage: string,
): Promise<T> {
  const { data, error } = await query;
  if (error) throw new UniversityActionError(error.message, 500);
  if (!data) throw new UniversityActionError(notFoundMessage, 404);
  return data as T;
}

function asTrimmedString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function boundedInt(
  value: unknown,
  fallback: number,
  min: number,
  max: number,
): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(Math.max(Math.trunc(parsed), min), max);
}

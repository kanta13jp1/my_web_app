import { AI_CHARACTER_PREAMBLE } from "./ai_character_preamble.ts";

export type SystemPromptOutputFormat =
  | "markdown"
  | "json_schema"
  | "plain_text";

export const OUTPUT_FORMAT_RULES = {
  markdown:
    "Respond in concise Markdown. Wrap code snippets in fenced code blocks " +
    "with a language tag.",
  json_schema:
    "Return valid JSON matching the requested schema only, without Markdown " +
    "fences or commentary.",
  plain_text: "Respond in concise plain text without Markdown code fences.",
} as const satisfies Record<SystemPromptOutputFormat, string>;

export interface DynamicSystemPromptOptions {
  now?: Date;
  outputFormat?: SystemPromptOutputFormat;
  staticInstructions?: string;
  jsonSchemaName?: string;
  templateVars?: Record<string, string>;
  includeCharacterPreamble?: boolean;
}

export interface TemplateValidationResult {
  valid: boolean;
  errors: string[];
  unresolvedPlaceholders: string[];
}

export interface BuiltDynamicSystemPrompt {
  prompt: string;
  staticPrefix: string;
  dynamicSuffix: string;
  utcIso: string;
  jstIso: string;
}

const JST_OFFSET_MS = 9 * 60 * 60 * 1000;
const PLACEHOLDER_NAME_RE = /^[a-zA-Z0-9_.-]+$/;

export function formatJstIsoTimestamp(now: Date): string {
  if (Number.isNaN(now.getTime())) {
    throw new TypeError("now must be a valid Date");
  }
  const jst = new Date(now.getTime() + JST_OFFSET_MS);
  const iso = jst.toISOString();
  return `${iso.slice(0, 23)}+09:00`;
}

export function validateSystemPromptTemplate(
  template: string,
  vars: Record<string, string> = {},
): TemplateValidationResult {
  const errors: string[] = [];
  const unresolvedPlaceholders: string[] = [];

  if (template.trim().length === 0) {
    errors.push("template must not be empty");
  }
  if (template.includes("<<<USER_DATA>>>") || template.includes("<<<END>>>")) {
    errors.push("template must not contain user-data boundary markers");
  }

  let cursor = 0;
  while (cursor < template.length) {
    const openIdx = template.indexOf("{{", cursor);
    const closeIdx = template.indexOf("}}", cursor);

    if (closeIdx !== -1 && (openIdx === -1 || closeIdx < openIdx)) {
      errors.push("unmatched closing placeholder brace '}}'");
      cursor = closeIdx + 2;
      continue;
    }
    if (openIdx === -1) {
      break;
    }

    const endIdx = template.indexOf("}}", openIdx + 2);
    if (endIdx === -1) {
      errors.push("unclosed placeholder brace '{{'");
      break;
    }

    const rawKey = template.slice(openIdx + 2, endIdx);
    const key = rawKey.trim();
    if (!PLACEHOLDER_NAME_RE.test(key)) {
      errors.push(`invalid placeholder name '${rawKey}'`);
    } else if (
      !Object.prototype.hasOwnProperty.call(vars, key) ||
      vars[key].trim().length === 0
    ) {
      if (!unresolvedPlaceholders.includes(key)) {
        unresolvedPlaceholders.push(key);
      }
      errors.push(`missing value for placeholder '${key}'`);
    }
    cursor = endIdx + 2;
  }

  return {
    valid: errors.length === 0,
    errors,
    unresolvedPlaceholders,
  };
}

function renderStaticTemplate(
  template: string,
  vars: Record<string, string> = {},
): string {
  const validation = validateSystemPromptTemplate(template, vars);
  if (!validation.valid) {
    throw new Error(validation.errors.join("; "));
  }
  return template.replace(/\{\{([^}]+)\}\}/g, (_match, rawKey: string) => {
    const key = rawKey.trim();
    return vars[key];
  });
}

export function buildDynamicSystemPrompt(
  options: DynamicSystemPromptOptions = {},
): BuiltDynamicSystemPrompt {
  const now = options.now ?? new Date();
  if (Number.isNaN(now.getTime())) {
    throw new TypeError("now must be a valid Date");
  }

  const utcIso = now.toISOString();
  const jstIso = formatJstIsoTimestamp(now);
  const outputFormat = options.outputFormat ?? "markdown";
  const includePreamble = options.includeCharacterPreamble ?? true;

  const staticSections: string[] = [];
  if (includePreamble) {
    staticSections.push(AI_CHARACTER_PREAMBLE);
  }

  const rawStatic = options.staticInstructions?.trim() ?? "";
  if (rawStatic.length > 0) {
    const rendered = renderStaticTemplate(rawStatic, options.templateVars);
    staticSections.push(`【アプリ固有指示】\n${rendered}`);
  }

  const formatRule = OUTPUT_FORMAT_RULES[outputFormat];
  const schemaName = options.jsonSchemaName?.trim() ?? "";
  const formatBody = outputFormat === "json_schema" && schemaName.length > 0
    ? `${formatRule}\nSchema: ${schemaName}`
    : formatRule;
  staticSections.push(`【出力形式】\n${formatBody}`);

  const staticPrefix = staticSections.join("\n\n");
  const dynamicSuffix = [
    "【動的コンテキスト】",
    `現在日付 (UTC): ${utcIso.slice(0, 10)}`,
    `現在時刻 (UTC, ISO 8601): ${utcIso}`,
    `現在時刻 (JST, ISO 8601): ${jstIso}`,
  ].join("\n");

  return {
    prompt: `${staticPrefix}\n\n${dynamicSuffix}`,
    staticPrefix,
    dynamicSuffix,
    utcIso,
    jstIso,
  };
}

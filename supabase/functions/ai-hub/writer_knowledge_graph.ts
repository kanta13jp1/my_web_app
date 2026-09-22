export const WRITER_KG_MAX_FILE_BYTES = 4 * 1024 * 1024;
export const WRITER_KG_MAX_QUESTION_CHARS = 2000;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const WRITER_KG_ALLOWED_MIME_TYPES = new Set([
  "text/plain",
  "text/csv",
  "text/html",
  "application/pdf",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-powerpoint",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
]);

export type UserWriterGraph = {
  user_id: string;
  writer_graph_id: string;
  created_at?: string;
  updated_at?: string;
};

export type UserWriterDocument = {
  id: string;
  user_id: string;
  writer_file_id: string;
  file_name: string;
  mime_type: string;
  size_bytes: number;
  processing_status: string;
  created_at: string;
  updated_at?: string;
};

export type WriterSource = {
  file_id: string;
  snippet: string;
};

export interface WriterKnowledgeGraphStore {
  findGraph(userId: string): Promise<UserWriterGraph | null>;
  saveGraph(userId: string, writerGraphId: string): Promise<UserWriterGraph>;
  listDocuments(userId: string): Promise<UserWriterDocument[]>;
  findDocument(
    userId: string,
    documentId: string,
  ): Promise<UserWriterDocument | null>;
  saveDocument(input: {
    userId: string;
    writerFileId: string;
    fileName: string;
    mimeType: string;
    sizeBytes: number;
    processingStatus: string;
  }): Promise<UserWriterDocument>;
  deleteDocument(userId: string, documentId: string): Promise<void>;
}

export interface WriterKnowledgeGraphGateway {
  createGraph(name: string, description: string): Promise<{ id: string }>;
  deleteGraph(graphId: string): Promise<void>;
  uploadFile(input: {
    graphId: string;
    fileName: string;
    mimeType: string;
    bytes: Uint8Array;
  }): Promise<{ id: string; status: string }>;
  ask(
    graphId: string,
    question: string,
  ): Promise<{ answer: string; sources: WriterSource[] }>;
  deleteFile(fileId: string): Promise<void>;
}

export class WriterKnowledgeGraphError extends Error {
  constructor(
    message: string,
    public readonly status = 400,
    public readonly code = "writer_knowledge_graph_error",
  ) {
    super(message);
    this.name = "WriterKnowledgeGraphError";
  }
}

type JsonRecord = Record<string, unknown>;

export function createWriterKnowledgeGraphGateway(
  apiKey: string,
  fetcher: typeof fetch = fetch,
): WriterKnowledgeGraphGateway {
  const request = async (
    path: string,
    init: RequestInit,
    options: { allowNotFound?: boolean } = {},
  ): Promise<JsonRecord> => {
    let response: Response;
    try {
      response = await fetcher(`https://api.writer.com${path}`, {
        ...init,
        headers: {
          Authorization: `Bearer ${apiKey}`,
          ...init.headers,
        },
        signal: AbortSignal.timeout(45_000),
      });
    } catch {
      throw new WriterKnowledgeGraphError(
        "Writer API is temporarily unavailable.",
        502,
        "writer_api_unavailable",
      );
    }
    const payload = await parseJsonResponse(response);
    if (response.status === 404 && options.allowNotFound) return payload;
    if (!response.ok) {
      const detail = safeErrorDetail(payload);
      throw new WriterKnowledgeGraphError(
        `Writer API request failed (${response.status})${detail}`,
        response.status === 429 ? 429 : 502,
        response.status === 429 ? "writer_rate_limited" : "writer_api_error",
      );
    }
    return payload;
  };

  return {
    async createGraph(name, description) {
      const payload = await request("/v1/graphs", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, description }),
      });
      return { id: requiredUuid(payload.id, "Writer graph id missing") };
    },
    async deleteGraph(graphId) {
      await request(`/v1/graphs/${encodeURIComponent(graphId)}`, {
        method: "DELETE",
      }, { allowNotFound: true });
    },
    async uploadFile(input) {
      const safeName = safeHeaderFileName(input.fileName);
      const requestBody = new ArrayBuffer(input.bytes.byteLength);
      new Uint8Array(requestBody).set(input.bytes);
      const payload = await request(
        `/v1/files?graphId=${encodeURIComponent(input.graphId)}`,
        {
          method: "POST",
          headers: {
            Accept: "application/json",
            "Content-Disposition": `attachment; filename="${safeName}"`,
            "Content-Length": String(input.bytes.byteLength),
            "Content-Type": input.mimeType,
          },
          body: requestBody,
        },
      );
      return {
        id: requiredString(payload.id, "Writer file id missing"),
        status: cleanString(payload.status, 80) || "in_progress",
      };
    },
    async ask(graphId, question) {
      const payload = await request("/v1/graphs/question", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          graph_ids: [graphId],
          question,
          stream: false,
          subqueries: false,
        }),
      });
      const rawSources = Array.isArray(payload.sources) ? payload.sources : [];
      const sources: WriterSource[] = rawSources.flatMap((entry) => {
        const item = asRecord(entry);
        if (!item) return [];
        const fileId = cleanString(item.file_id, 200);
        const snippet = cleanString(item.snippet, 1200);
        return fileId && snippet ? [{ file_id: fileId, snippet }] : [];
      });
      return {
        answer: requiredString(payload.answer, "Writer answer missing"),
        sources,
      };
    },
    async deleteFile(fileId) {
      await request(`/v1/files/${encodeURIComponent(fileId)}`, {
        method: "DELETE",
      }, { allowNotFound: true });
    },
  };
}

export async function handleWriterKnowledgeGraphAction(options: {
  action: string;
  body: JsonRecord;
  userId: string;
  configured: boolean;
  store: WriterKnowledgeGraphStore;
  gateway: WriterKnowledgeGraphGateway | null;
}): Promise<JsonRecord> {
  const { action, body, userId, configured, store, gateway } = options;
  if (action === "knowledge_graph.status") {
    const [graph, documents] = await Promise.all([
      store.findGraph(userId),
      store.listDocuments(userId),
    ]);
    return {
      success: true,
      configured,
      graph_ready: graph !== null,
      documents,
    };
  }

  if (!configured || !gateway) {
    throw new WriterKnowledgeGraphError(
      "Supabase Secret WRITER_API_KEY is required.",
      503,
      "writer_api_key_required",
    );
  }

  switch (action) {
    case "knowledge_graph.upload":
      return await uploadDocument(body, userId, store, gateway);
    case "knowledge_graph.query":
      return await queryGraph(body, userId, store, gateway);
    case "knowledge_graph.delete_document":
      return await deleteDocument(body, userId, store, gateway);
    default:
      throw new WriterKnowledgeGraphError(
        `Unknown knowledge graph action: ${action}`,
        400,
        "unknown_action",
      );
  }
}

async function uploadDocument(
  body: JsonRecord,
  userId: string,
  store: WriterKnowledgeGraphStore,
  gateway: WriterKnowledgeGraphGateway,
): Promise<JsonRecord> {
  const fileName = cleanFileName(body.file_name);
  const mimeType = cleanString(body.mime_type, 180).toLowerCase();
  if (!WRITER_KG_ALLOWED_MIME_TYPES.has(mimeType)) {
    throw new WriterKnowledgeGraphError(
      "Unsupported knowledge graph document type.",
      400,
      "unsupported_file_type",
    );
  }
  const bytes = decodeBase64(body.file_base64);
  if (bytes.byteLength === 0) {
    throw new WriterKnowledgeGraphError(
      "The selected document is empty.",
      400,
      "empty_file",
    );
  }
  if (bytes.byteLength > WRITER_KG_MAX_FILE_BYTES) {
    throw new WriterKnowledgeGraphError(
      "Knowledge graph documents must be 4 MB or smaller.",
      413,
      "file_too_large",
    );
  }

  const currentDocuments = await store.listDocuments(userId);
  if (currentDocuments.length >= 100) {
    throw new WriterKnowledgeGraphError(
      "A knowledge graph can contain at most 100 uploaded documents.",
      409,
      "document_limit_reached",
    );
  }

  const graph = await getOrCreateGraph(userId, store, gateway);
  const uploaded = await gateway.uploadFile({
    graphId: graph.writer_graph_id,
    fileName,
    mimeType,
    bytes,
  });
  try {
    const document = await store.saveDocument({
      userId,
      writerFileId: uploaded.id,
      fileName,
      mimeType,
      sizeBytes: bytes.byteLength,
      processingStatus: uploaded.status,
    });
    return { success: true, document };
  } catch (error) {
    try {
      await gateway.deleteFile(uploaded.id);
    } catch {
      // Preserve the original persistence error. The failed compensation is
      // visible in Writer audit logs and can be removed by an operator.
    }
    throw error;
  }
}

async function queryGraph(
  body: JsonRecord,
  userId: string,
  store: WriterKnowledgeGraphStore,
  gateway: WriterKnowledgeGraphGateway,
): Promise<JsonRecord> {
  const question = cleanString(body.question, WRITER_KG_MAX_QUESTION_CHARS);
  if (!question) {
    throw new WriterKnowledgeGraphError(
      "question required",
      400,
      "question_required",
    );
  }
  const graph = await store.findGraph(userId);
  if (!graph) {
    throw new WriterKnowledgeGraphError(
      "Upload a document before asking a question.",
      409,
      "graph_not_ready",
    );
  }
  const documents = await store.listDocuments(userId);
  if (documents.length === 0) {
    throw new WriterKnowledgeGraphError(
      "Upload a document before asking a question.",
      409,
      "document_required",
    );
  }
  const result = await gateway.ask(graph.writer_graph_id, question);
  const byFileId = new Map(
    documents.map((document) => [document.writer_file_id, document]),
  );
  const seen = new Set<string>();
  const citations = result.sources.flatMap((source) => {
    if (seen.has(source.file_id)) return [];
    const document = byFileId.get(source.file_id);
    if (!document) return [];
    seen.add(source.file_id);
    return [{
      index: seen.size,
      file_id: source.file_id,
      document_id: document.id,
      file_name: document.file_name,
      snippet: source.snippet,
    }];
  });
  if (citations.length === 0) {
    throw new WriterKnowledgeGraphError(
      "No cited source was available for this answer. Try again after document processing completes.",
      422,
      "no_cited_source",
    );
  }
  const markers = citations.map((citation) => `[${citation.index}]`).join("");
  const answerText = result.answer.replace(/\s*\[\d+\]/g, "").trim();
  if (!answerText) {
    throw new WriterKnowledgeGraphError(
      "Writer answer did not contain response text.",
      502,
      "writer_invalid_response",
    );
  }
  const answer = `${answerText} ${markers}`;
  return {
    success: true,
    question,
    answer,
    citations,
    citation_count: citations.length,
  };
}

async function deleteDocument(
  body: JsonRecord,
  userId: string,
  store: WriterKnowledgeGraphStore,
  gateway: WriterKnowledgeGraphGateway,
): Promise<JsonRecord> {
  const documentId = cleanString(body.document_id, 200);
  if (!documentId) {
    throw new WriterKnowledgeGraphError(
      "document_id required",
      400,
      "document_id_required",
    );
  }
  const document = await store.findDocument(userId, documentId);
  if (!document) {
    throw new WriterKnowledgeGraphError(
      "Document not found.",
      404,
      "document_not_found",
    );
  }
  await gateway.deleteFile(document.writer_file_id);
  await store.deleteDocument(userId, documentId);
  return { success: true, deleted_document_id: documentId };
}

async function getOrCreateGraph(
  userId: string,
  store: WriterKnowledgeGraphStore,
  gateway: WriterKnowledgeGraphGateway,
): Promise<UserWriterGraph> {
  const existing = await store.findGraph(userId);
  if (existing) return existing;
  const suffix = userId.replace(/-/g, "").slice(0, 12);
  const created = await gateway.createGraph(
    `my_web_app user ${suffix}`,
    "Private user documents uploaded from my_web_app.",
  );
  const saved = await store.saveGraph(userId, created.id);
  if (saved.writer_graph_id !== created.id) {
    try {
      await gateway.deleteGraph(created.id);
    } catch {
      // The winning user graph remains authoritative. A failed cleanup is
      // visible in Writer audit logs and can be removed by an operator.
    }
  }
  return saved;
}

function decodeBase64(value: unknown): Uint8Array {
  const encoded = typeof value === "string" ? value.trim() : "";
  if (!encoded) {
    throw new WriterKnowledgeGraphError(
      "file_base64 required",
      400,
      "file_required",
    );
  }
  const estimatedBytes = Math.floor(encoded.length * 3 / 4);
  if (estimatedBytes > WRITER_KG_MAX_FILE_BYTES + 2) {
    throw new WriterKnowledgeGraphError(
      "Knowledge graph documents must be 4 MB or smaller.",
      413,
      "file_too_large",
    );
  }
  try {
    const binary = atob(encoded);
    return Uint8Array.from(binary, (character) => character.charCodeAt(0));
  } catch {
    throw new WriterKnowledgeGraphError(
      "file_base64 is invalid",
      400,
      "invalid_file_encoding",
    );
  }
}

function cleanFileName(value: unknown): string {
  const cleaned = cleanString(value, 160)
    .replace(/[\\/\r\n\t]/g, "_")
    .replace(/[<>:"|?*]/g, "_");
  if (!cleaned) {
    throw new WriterKnowledgeGraphError(
      "file_name required",
      400,
      "file_name_required",
    );
  }
  return cleaned;
}

function safeHeaderFileName(value: string): string {
  return value.replace(/[^A-Za-z0-9._-]/g, "_").slice(0, 120) ||
    "document.txt";
}

function cleanString(value: unknown, maxLength: number): string {
  return Array.from(String(value ?? ""), (character) => {
    const code = character.charCodeAt(0);
    return code <= 31 || code === 127 ? " " : character;
  }).join("").trim().slice(0, maxLength);
}

function requiredString(value: unknown, message: string): string {
  const result = cleanString(value, 400);
  if (result) return result;
  throw new WriterKnowledgeGraphError(message, 502, "writer_invalid_response");
}

function requiredUuid(value: unknown, message: string): string {
  const result = requiredString(value, message);
  if (UUID_PATTERN.test(result)) return result;
  throw new WriterKnowledgeGraphError(
    "Writer graph id is invalid",
    502,
    "writer_invalid_response",
  );
}

function asRecord(value: unknown): JsonRecord | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonRecord
    : null;
}

async function parseJsonResponse(response: Response): Promise<JsonRecord> {
  try {
    return asRecord(await response.json()) ?? {};
  } catch {
    return {};
  }
}

function safeErrorDetail(payload: JsonRecord): string {
  const detail = cleanString(
    payload.message ?? payload.error ?? payload.detail,
    240,
  );
  return detail ? `: ${detail}` : "";
}

import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  createWriterKnowledgeGraphGateway,
  handleWriterKnowledgeGraphAction,
  type UserWriterDocument,
  type UserWriterGraph,
  WriterKnowledgeGraphError,
  type WriterKnowledgeGraphGateway,
  type WriterKnowledgeGraphStore,
} from "./writer_knowledge_graph.ts";

const GRAPH_ID = "50daa3d0-e7d9-44a4-be42-b53e2379ebf7";

class MemoryStore implements WriterKnowledgeGraphStore {
  graph: UserWriterGraph | null = null;
  documents: UserWriterDocument[] = [];

  findGraph(userId: string) {
    return Promise.resolve(this.graph?.user_id === userId ? this.graph : null);
  }

  saveGraph(userId: string, writerGraphId: string) {
    this.graph = { user_id: userId, writer_graph_id: writerGraphId };
    return Promise.resolve(this.graph);
  }

  listDocuments(userId: string) {
    return Promise.resolve(
      this.documents.filter((document) => document.user_id === userId),
    );
  }

  findDocument(userId: string, documentId: string) {
    return Promise.resolve(
      this.documents.find((document) =>
        document.user_id === userId && document.id === documentId
      ) ?? null,
    );
  }

  saveDocument(input: {
    userId: string;
    writerFileId: string;
    fileName: string;
    mimeType: string;
    sizeBytes: number;
    processingStatus: string;
  }) {
    const document: UserWriterDocument = {
      id: `document-${this.documents.length + 1}`,
      user_id: input.userId,
      writer_file_id: input.writerFileId,
      file_name: input.fileName,
      mime_type: input.mimeType,
      size_bytes: input.sizeBytes,
      processing_status: input.processingStatus,
      created_at: "2026-08-24T00:00:00Z",
    };
    this.documents.push(document);
    return Promise.resolve(document);
  }

  deleteDocument(userId: string, documentId: string) {
    this.documents = this.documents.filter((document) =>
      document.user_id !== userId || document.id !== documentId
    );
    return Promise.resolve();
  }
}

class FakeGateway implements WriterKnowledgeGraphGateway {
  createCount = 0;
  uploadedGraphId = "";
  deletedGraphIds: string[] = [];
  deletedFileIds: string[] = [];

  createGraph(_name: string, _description: string) {
    this.createCount += 1;
    return Promise.resolve({ id: GRAPH_ID });
  }

  deleteGraph(graphId: string) {
    this.deletedGraphIds.push(graphId);
    return Promise.resolve();
  }

  uploadFile(input: {
    graphId: string;
    fileName: string;
    mimeType: string;
    bytes: Uint8Array;
  }) {
    this.uploadedGraphId = input.graphId;
    return Promise.resolve({ id: "file-1", status: "in_progress" });
  }

  ask(_graphId: string, _question: string) {
    return Promise.resolve({
      answer: "The project launch is in October.",
      sources: [
        { file_id: "file-1", snippet: "Launch is planned for October." },
        { file_id: "file-1", snippet: "This duplicate should be ignored." },
      ],
    });
  }

  deleteFile(fileId: string) {
    this.deletedFileIds.push(fileId);
    return Promise.resolve();
  }
}

Deno.test("status does not require Writer API key and returns owner documents", async () => {
  const store = new MemoryStore();
  store.documents.push(documentFor("user-a"), documentFor("user-b"));

  const result = await handleWriterKnowledgeGraphAction({
    action: "knowledge_graph.status",
    body: {},
    userId: "user-a",
    configured: false,
    store,
    gateway: null,
  });

  assertEquals(result.configured, false);
  assertEquals((result.documents as UserWriterDocument[]).length, 1);
  assertEquals((result.documents as UserWriterDocument[])[0].user_id, "user-a");
});

Deno.test("upload creates an isolated graph and records metadata only", async () => {
  const store = new MemoryStore();
  const gateway = new FakeGateway();

  const result = await handleWriterKnowledgeGraphAction({
    action: "knowledge_graph.upload",
    body: {
      file_name: "roadmap.txt",
      mime_type: "text/plain",
      file_base64: btoa("October launch"),
    },
    userId: "user-a",
    configured: true,
    store,
    gateway,
  });

  assertEquals(result.success, true);
  assertEquals(gateway.createCount, 1);
  assertEquals(gateway.uploadedGraphId, GRAPH_ID);
  assertEquals(store.documents[0].file_name, "roadmap.txt");
  assertEquals(store.documents[0].size_bytes, 14);
  assertEquals("file_base64" in store.documents[0], false);
});

Deno.test("query uses only the owner graph and adds deterministic inline citations", async () => {
  const store = new MemoryStore();
  store.graph = { user_id: "user-a", writer_graph_id: GRAPH_ID };
  store.documents.push(documentFor("user-a"));

  const result = await handleWriterKnowledgeGraphAction({
    action: "knowledge_graph.query",
    body: { question: "When is launch?" },
    userId: "user-a",
    configured: true,
    store,
    gateway: new FakeGateway(),
  });

  assertStringIncludes(String(result.answer), "[1]");
  const citations = result.citations as Array<Record<string, unknown>>;
  assertEquals(citations.length, 1);
  assertEquals(citations[0].file_name, "roadmap.txt");
});

Deno.test("query ignores unknown files and rewrites numeric markers deterministically", async () => {
  const store = new MemoryStore();
  store.graph = { user_id: "user-a", writer_graph_id: GRAPH_ID };
  store.documents.push(documentFor("user-a"));
  const gateway = new FakeGateway();
  gateway.ask = () =>
    Promise.resolve({
      answer: "The launch is in October [99].",
      sources: [
        { file_id: "other-user-file", snippet: "Private source" },
        { file_id: "file-1", snippet: "October launch" },
      ],
    });

  const result = await handleWriterKnowledgeGraphAction({
    action: "knowledge_graph.query",
    body: { question: "When is launch?" },
    userId: "user-a",
    configured: true,
    store,
    gateway,
  });

  assertEquals(result.answer, "The launch is in October. [1]");
  const citations = result.citations as Array<Record<string, unknown>>;
  assertEquals(citations.length, 1);
  assertEquals(citations[0].file_id, "file-1");
  assertEquals(citations[0].document_id, "document-1");
});

Deno.test("upload removes a graph that loses a concurrent creation race", async () => {
  const store = new MemoryStore();
  const winningGraphId = "97095b89-d671-42b5-9911-631d494e33c7";
  store.saveGraph = (userId: string, _writerGraphId: string) => {
    store.graph = { user_id: userId, writer_graph_id: winningGraphId };
    return Promise.resolve(store.graph);
  };
  const gateway = new FakeGateway();

  await handleWriterKnowledgeGraphAction({
    action: "knowledge_graph.upload",
    body: {
      file_name: "roadmap.txt",
      mime_type: "text/plain",
      file_base64: btoa("October launch"),
    },
    userId: "user-a",
    configured: true,
    store,
    gateway,
  });

  assertEquals(gateway.deletedGraphIds, [GRAPH_ID]);
  assertEquals(gateway.uploadedGraphId, winningGraphId);
});

Deno.test("delete refuses another user's document", async () => {
  const store = new MemoryStore();
  store.documents.push(documentFor("user-b"));

  const error = await assertRejects(
    () =>
      handleWriterKnowledgeGraphAction({
        action: "knowledge_graph.delete_document",
        body: { document_id: "document-1" },
        userId: "user-a",
        configured: true,
        store,
        gateway: new FakeGateway(),
      }),
    WriterKnowledgeGraphError,
  );

  assertEquals(error.status, 404);
  assertEquals(error.code, "document_not_found");
});

Deno.test("external actions fail closed when the server secret is absent", async () => {
  const error = await assertRejects(
    () =>
      handleWriterKnowledgeGraphAction({
        action: "knowledge_graph.query",
        body: { question: "Hello" },
        userId: "user-a",
        configured: false,
        store: new MemoryStore(),
        gateway: null,
      }),
    WriterKnowledgeGraphError,
  );

  assertEquals(error.status, 503);
  assertEquals(error.code, "writer_api_key_required");
});

Deno.test("query refuses an answer without a cited source", async () => {
  const store = new MemoryStore();
  store.graph = { user_id: "user-a", writer_graph_id: GRAPH_ID };
  store.documents.push(documentFor("user-a"));
  const gateway = new FakeGateway();
  gateway.ask = () => Promise.resolve({ answer: "Unsupported", sources: [] });

  const error = await assertRejects(
    () =>
      handleWriterKnowledgeGraphAction({
        action: "knowledge_graph.query",
        body: { question: "When is launch?" },
        userId: "user-a",
        configured: true,
        store,
        gateway,
      }),
    WriterKnowledgeGraphError,
  );

  assertEquals(error.status, 422);
  assertEquals(error.code, "no_cited_source");
});

Deno.test("Writer gateway keeps the API key in Authorization and scopes calls to one graph", async () => {
  const requests: Array<{ url: string; init?: RequestInit }> = [];
  const fetcher = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    requests.push({ url, init });
    if (url.endsWith("/v1/graphs")) {
      return Promise.resolve(jsonResponse({ id: GRAPH_ID }));
    }
    if (url.includes("/v1/files?graphId=")) {
      return Promise.resolve(
        jsonResponse({ id: "file-1", status: "in_progress" }),
      );
    }
    if (url.endsWith("/v1/graphs/question")) {
      return Promise.resolve(
        jsonResponse({
          answer: "October",
          sources: [{ file_id: "file-1", snippet: "October launch" }],
        }),
      );
    }
    return Promise.resolve(jsonResponse({ id: "file-1", deleted: true }));
  }) as typeof fetch;
  const gateway = createWriterKnowledgeGraphGateway(
    "secret-writer-key",
    fetcher,
  );

  await gateway.createGraph("private", "private graph");
  await gateway.deleteGraph(GRAPH_ID);
  await gateway.uploadFile({
    graphId: GRAPH_ID,
    fileName: "roadmap.txt",
    mimeType: "text/plain",
    bytes: new TextEncoder().encode("October launch"),
  });
  await gateway.ask(GRAPH_ID, "When?");
  await gateway.deleteFile("file-1");

  assertEquals(requests.length, 5);
  for (const request of requests) {
    const headers = new Headers(request.init?.headers);
    assertEquals(headers.get("Authorization"), "Bearer secret-writer-key");
    assertEquals(
      String(request.init?.body ?? "").includes("secret-writer-key"),
      false,
    );
  }
  assertEquals(requests[1].url.endsWith(`/v1/graphs/${GRAPH_ID}`), true);
  assertStringIncludes(requests[2].url, `graphId=${GRAPH_ID}`);
  const questionBody = JSON.parse(String(requests[3].init?.body));
  assertEquals(questionBody.graph_ids, [GRAPH_ID]);
});

Deno.test("Writer delete treats an already removed file as success", async () => {
  const gateway = createWriterKnowledgeGraphGateway(
    "secret-writer-key",
    (() => Promise.resolve(jsonResponse({}, 404))) as typeof fetch,
  );

  await gateway.deleteFile("already-removed");
});

function documentFor(userId: string): UserWriterDocument {
  return {
    id: "document-1",
    user_id: userId,
    writer_file_id: "file-1",
    file_name: "roadmap.txt",
    mime_type: "text/plain",
    size_bytes: 14,
    processing_status: "completed",
    created_at: "2026-08-24T00:00:00Z",
  };
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

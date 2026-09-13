import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

import {
  type UserWriterDocument,
  type UserWriterGraph,
  type WriterKnowledgeGraphStore,
} from "./writer_knowledge_graph.ts";

export function createSupabaseWriterKnowledgeGraphStore(
  client: SupabaseClient,
): WriterKnowledgeGraphStore {
  return {
    async findGraph(userId) {
      const { data, error } = await client
        .from("user_writer_knowledge_graphs")
        .select("user_id,writer_graph_id,created_at,updated_at")
        .eq("user_id", userId)
        .maybeSingle();
      if (error) throw error;
      return data as UserWriterGraph | null;
    },

    async saveGraph(userId, writerGraphId) {
      const { data, error } = await client
        .from("user_writer_knowledge_graphs")
        .insert({ user_id: userId, writer_graph_id: writerGraphId })
        .select("user_id,writer_graph_id,created_at,updated_at")
        .single();
      if (!error) return data as UserWriterGraph;
      if (error.code === "23505") {
        const { data: existing, error: existingError } = await client
          .from("user_writer_knowledge_graphs")
          .select("user_id,writer_graph_id,created_at,updated_at")
          .eq("user_id", userId)
          .single();
        if (existingError) throw existingError;
        return existing as UserWriterGraph;
      }
      throw error;
    },

    async listDocuments(userId) {
      const { data, error } = await client
        .from("user_writer_knowledge_graph_documents")
        .select(
          "id,user_id,writer_file_id,file_name,mime_type,size_bytes,processing_status,created_at,updated_at",
        )
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(100);
      if (error) throw error;
      return (data ?? []) as UserWriterDocument[];
    },

    async findDocument(userId, documentId) {
      const { data, error } = await client
        .from("user_writer_knowledge_graph_documents")
        .select(
          "id,user_id,writer_file_id,file_name,mime_type,size_bytes,processing_status,created_at,updated_at",
        )
        .eq("user_id", userId)
        .eq("id", documentId)
        .maybeSingle();
      if (error) throw error;
      return data as UserWriterDocument | null;
    },

    async saveDocument(input) {
      const { data, error } = await client
        .from("user_writer_knowledge_graph_documents")
        .insert({
          user_id: input.userId,
          writer_file_id: input.writerFileId,
          file_name: input.fileName,
          mime_type: input.mimeType,
          size_bytes: input.sizeBytes,
          processing_status: input.processingStatus,
        })
        .select(
          "id,user_id,writer_file_id,file_name,mime_type,size_bytes,processing_status,created_at,updated_at",
        )
        .single();
      if (error) throw error;
      return data as UserWriterDocument;
    },

    async deleteDocument(userId, documentId) {
      const { error } = await client
        .from("user_writer_knowledge_graph_documents")
        .delete()
        .eq("user_id", userId)
        .eq("id", documentId);
      if (error) throw error;
    },
  };
}

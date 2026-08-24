# Writer PDF document analysis

Issue #1255 adds an authenticated PDF workflow to the consolidated writing
center. It is deliberately disabled by default because Writer's current PDF
Parser reference still documents the endpoint while also showing a removal
date of 2025-12-22. A tenant-specific staging check is therefore required
before enabling the feature.

## Request flow

1. The client verifies the `%PDF-` header, estimates the page count, and
   rejects files larger than 20 MB or 200 pages.
2. The user sees the page count and the documented parser estimate of
   `$0.055/page`, then explicitly confirms.
3. The client uploads the PDF to the private `pdf-analysis-inputs` bucket under
   its authenticated user ID.
4. `ai-hub` downloads the file, independently verifies its type, size, page
   count, owner path, budget, and offline-secure-mode policy.
5. When enabled, the Edge Function uses Writer Files, PDF Parser, and Palmyra
   X5 structured output to return Markdown, a Japanese summary, key points,
   and important fields.
6. The Edge Function and client both attempt to delete the temporary object.
   The Writer file deletion is also requested in a `finally` block. Extracted
   content and results are not persisted by this feature.

## Release gate

Keep `WRITER_PDF_PARSER_ENABLED=false` until all of the following are proven in
the target Writer tenant and staging Supabase project:

- `POST /v1/files` accepts the tenant's PDF upload.
- `POST /v1/tools/pdf-parser/{file_id}` succeeds for a multi-page PDF.
- `POST /v1/chat` with `palmyra-x5` accepts the structured response format.
- Both Supabase and Writer temporary files are absent after success and error.
- The displayed estimate matches tenant billing for the validation document.

Enable with server-side Edge Function secrets only:

```powershell
supabase secrets set WRITER_API_KEY=... WRITER_PDF_PARSER_ENABLED=true
```

Do not expose `WRITER_API_KEY` to Flutter or commit it. Roll back immediately by
setting `WRITER_PDF_PARSER_ENABLED=false`; the UI will keep selection and cost
inspection available but fail closed before the PDF is sent to Writer.

Official references:

- https://dev.writer.com/api-reference/tool-api/pdf-parser
- https://dev.writer.com/api-reference/file-api/upload-files
- https://dev.writer.com/api-reference/completion-api/chat-completion
- https://supabase.com/docs/guides/functions/limits

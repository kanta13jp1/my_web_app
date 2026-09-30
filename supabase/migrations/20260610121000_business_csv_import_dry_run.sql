-- Issue #2911: business CSV dry-run, error export, and controlled commit.

CREATE OR REPLACE FUNCTION public.preview_business_note_csv_import(
  p_rows jsonb,
  p_file_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_rows jsonb := COALESCE(p_rows, '[]'::jsonb);
  v_total int;
  v_index int := 0;
  v_row jsonb;
  v_row_number int;
  v_title text;
  v_content text;
  v_external_id text;
  v_raw_text text;
  v_tags jsonb;
  v_reasons jsonb;
  v_seen_external_ids text[] := ARRAY[]::text[];
  v_seen_titles text[] := ARRAY[]::text[];
  v_duplicate boolean;
  v_valid_rows jsonb := '[]'::jsonb;
  v_error_rows jsonb := '[]'::jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authenticated user required';
  END IF;

  IF jsonb_typeof(v_rows) <> 'array' THEN
    RAISE EXCEPTION 'p_rows must be a JSON array';
  END IF;

  v_total := jsonb_array_length(v_rows);
  IF v_total > 500 THEN
    RAISE EXCEPTION 'CSV dry-run is limited to 500 rows per request';
  END IF;

  FOR v_row IN SELECT value FROM jsonb_array_elements(v_rows) AS item(value)
  LOOP
    v_index := v_index + 1;
    v_row_number := CASE
      WHEN COALESCE(v_row->>'rowNumber', v_row->>'row_number', '') ~ '^[0-9]+$'
        THEN COALESCE(v_row->>'rowNumber', v_row->>'row_number')::int
      ELSE v_index + 1
    END;
    v_title := btrim(COALESCE(v_row->>'title', ''));
    v_content := btrim(COALESCE(v_row->>'content', ''));
    v_external_id := lower(btrim(COALESCE(v_row->>'externalId', v_row->>'external_id', '')));
    v_raw_text := COALESCE(v_row->>'rawText', v_row->>'raw_text', '');
    v_reasons := '[]'::jsonb;

    SELECT COALESCE(jsonb_agg(to_jsonb(tag_text)), '[]'::jsonb)
      INTO v_tags
    FROM (
      SELECT btrim(value) AS tag_text
      FROM jsonb_array_elements_text(
        CASE
          WHEN jsonb_typeof(v_row->'tags') = 'array' THEN v_row->'tags'
          ELSE '[]'::jsonb
        END
      ) AS tags(value)
      WHERE btrim(value) <> ''
    ) AS normalized_tags;

    IF v_title = '' THEN
      v_reasons := v_reasons || jsonb_build_array('required title missing');
    END IF;
    IF v_content = '' THEN
      v_reasons := v_reasons || jsonb_build_array('required content missing');
    END IF;
    IF length(v_title) > 160 THEN
      v_reasons := v_reasons || jsonb_build_array('title exceeds 160 characters');
    END IF;
    IF length(v_content) > 20000 THEN
      v_reasons := v_reasons || jsonb_build_array('content exceeds 20000 characters');
    END IF;
    IF v_external_id <> '' THEN
      IF v_external_id = ANY(v_seen_external_ids) THEN
        v_reasons := v_reasons || jsonb_build_array('duplicate external_id within file');
      ELSE
        v_seen_external_ids := array_append(v_seen_external_ids, v_external_id);
      END IF;
    END IF;
    IF v_title <> '' THEN
      IF lower(v_title) = ANY(v_seen_titles) THEN
        v_reasons := v_reasons || jsonb_build_array('duplicate title within file');
      ELSE
        v_seen_titles := array_append(v_seen_titles, lower(v_title));
      END IF;
    END IF;
    IF v_title <> '' AND v_content <> '' THEN
      SELECT EXISTS(
        SELECT 1
        FROM public.notes
        WHERE user_id = v_user_id
          AND lower(btrim(title)) = lower(v_title)
          AND left(COALESCE(content, ''), 500) = left(v_content, 500)
        LIMIT 1
      )
      INTO v_duplicate;
      IF v_duplicate THEN
        v_reasons := v_reasons || jsonb_build_array('duplicate note already exists');
      END IF;
    END IF;

    IF jsonb_array_length(v_reasons) = 0 THEN
      v_valid_rows := v_valid_rows || jsonb_build_array(
        jsonb_build_object(
          'rowNumber', v_row_number,
          'rawText', v_raw_text,
          'title', v_title,
          'content', v_content,
          'tags', v_tags,
          'externalId', v_external_id
        )
      );
    ELSE
      v_error_rows := v_error_rows || jsonb_build_array(
        jsonb_build_object(
          'rowNumber', v_row_number,
          'rawText', v_raw_text,
          'title', v_title,
          'reasons', v_reasons
        )
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'fileName', COALESCE(p_file_name, ''),
    'totalRows', v_total,
    'validRows', v_valid_rows,
    'errorRows', v_error_rows,
    'validCount', jsonb_array_length(v_valid_rows),
    'errorCount', jsonb_array_length(v_error_rows),
    'checkedBy', 'postgres-rpc',
    'warnings', '[]'::jsonb
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.commit_business_note_csv_import(
  p_rows jsonb,
  p_file_name text DEFAULT NULL,
  p_rollback_on_error boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_preview jsonb;
  v_error_count int;
  v_row jsonb;
  v_tags text[];
  v_inserted_count int := 0;
  v_inserted_ids jsonb := '[]'::jsonb;
  v_note_id bigint;
  v_commit_mode text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authenticated user required';
  END IF;

  v_preview := public.preview_business_note_csv_import(p_rows, p_file_name);
  v_error_count := COALESCE((v_preview->>'errorCount')::int, 0);
  v_commit_mode := CASE
    WHEN p_rollback_on_error THEN 'all_or_rollback'
    ELSE 'valid_rows_only'
  END;

  IF p_rollback_on_error AND v_error_count > 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'insertedCount', 0,
      'rolledBack', true,
      'commitMode', v_commit_mode,
      'dryRun', v_preview
    );
  END IF;

  FOR v_row IN SELECT value FROM jsonb_array_elements(v_preview->'validRows') AS item(value)
  LOOP
    SELECT COALESCE(array_agg(value), ARRAY[]::text[])
      INTO v_tags
    FROM jsonb_array_elements_text(COALESCE(v_row->'tags', '[]'::jsonb)) AS tags(value);

    INSERT INTO public.notes (
      user_id,
      title,
      content,
      is_archived,
      is_pinned,
      tags
    )
    VALUES (
      v_user_id,
      btrim(v_row->>'title'),
      btrim(v_row->>'content'),
      false,
      false,
      v_tags
    )
    RETURNING id INTO v_note_id;

    v_inserted_count := v_inserted_count + 1;
    v_inserted_ids := v_inserted_ids || jsonb_build_array(to_jsonb(v_note_id));
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'insertedCount', v_inserted_count,
    'rolledBack', false,
    'commitMode', v_commit_mode,
    'insertedIds', v_inserted_ids,
    'dryRun', v_preview
  );
END;
$$;

REVOKE ALL ON FUNCTION public.preview_business_note_csv_import(jsonb, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.commit_business_note_csv_import(jsonb, text, boolean)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.preview_business_note_csv_import(jsonb, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.commit_business_note_csv_import(jsonb, text, boolean)
  TO authenticated, service_role;

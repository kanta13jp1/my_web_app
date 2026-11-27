export const DEFAULT_ENDPOINT =
  'https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/tools-hub';

const MIN_KEY_LENGTH = 16;

export function validateApiKey(key) {
  if (typeof key !== 'string') {
    return { ok: false, error: 'APIキーを入力してください。' };
  }
  const trimmed = key.trim();
  if (!trimmed.startsWith('jibun_sk_') || trimmed.length < MIN_KEY_LENGTH) {
    return {
      ok: false,
      error: 'APIキーは「jibun_sk_」から始まる有効なキーを入力してください。',
    };
  }
  return { ok: true, key: trimmed };
}

function mapHttpError(status, payload) {
  const detail = payload && typeof payload.error === 'string' ? payload.error : '';
  if (status === 401) {
    return '認証エラー (401): APIキーが無効または失効しています。';
  }
  if (status === 403) {
    return detail.includes('notes.write')
      ? '権限エラー (403): APIキーに notes.write スコープがありません。'
      : '権限エラー (403): 実行権限が不足しています。';
  }
  if (status === 429) {
    return 'レート制限 (429): 短時間にリクエストが集中しました。少し待って再試行してください。';
  }
  if (status >= 500) {
    return `サーバーエラー (${status}): 時間をおいて再試行してください。`;
  }
  return detail ? `保存エラー (${status}): ${detail}` : `保存エラー (${status})`;
}

async function callJibunApi({
  apiKey,
  endpoint = DEFAULT_ENDPOINT,
  payload,
  fetchImpl = globalThis.fetch,
}) {
  const validation = validateApiKey(apiKey);
  if (!validation.ok) {
    return { ok: false, status: 400, error: validation.error };
  }
  if (typeof fetchImpl !== 'function') {
    return { ok: false, status: 0, error: 'fetch API が利用できません。' };
  }

  let response;
  try {
    response = await fetchImpl(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${validation.key}`,
      },
      body: JSON.stringify(payload),
    });
  } catch (err) {
    return {
      ok: false,
      status: 0,
      error: `通信エラー: ${err instanceof Error ? err.message : String(err)}`,
    };
  }

  let data = null;
  try {
    data = await response.json();
  } catch {
    data = null;
  }

  if (!response.ok) {
    return {
      ok: false,
      status: response.status,
      error: mapHttpError(response.status, data),
      data,
    };
  }

  return { ok: true, status: response.status, data };
}

export async function testConnection({
  apiKey,
  endpoint = DEFAULT_ENDPOINT,
  fetchImpl = globalThis.fetch,
}) {
  const res = await callJibunApi({
    apiKey,
    endpoint,
    payload: { action: 'api.me' },
    fetchImpl,
  });
  if (!res.ok) return res;
  const scopes = Array.isArray(res.data?.key?.scopes) ? res.data.key.scopes : [];
  return {
    ok: true,
    status: res.status,
    userId: res.data?.user_id ?? null,
    scopes,
    canWriteNotes: scopes.includes('notes.write'),
  };
}

export async function saveClippedNote({
  apiKey,
  endpoint = DEFAULT_ENDPOINT,
  title,
  content,
  tags = ['web-clip'],
  captureStatus = 'inbox',
  sourceKey,
  fetchImpl = globalThis.fetch,
}) {
  const payload = {
    action: 'api.notes.create',
    title,
    content,
    tags,
    capture_status: captureStatus,
    capture_source: 'web_clipper',
  };
  if (typeof sourceKey === 'string' && sourceKey.trim()) {
    payload.source_key = sourceKey.trim();
  }
  const res = await callJibunApi({
    apiKey,
    endpoint,
    payload,
    fetchImpl,
  });
  if (!res.ok) return res;
  return {
    ok: true,
    status: res.status,
    note: res.data?.note ?? null,
    traceId: res.data?.trace_id ?? null,
  };
}

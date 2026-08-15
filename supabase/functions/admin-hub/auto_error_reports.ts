// error_reporter (クライアント auto error report) は hub_data に
// source='user_feedback' + metadata.source='auto_error_report' で入る。
// metadata.message は "[自動エラー報告]\n<本文>\n\n<stack 6行>" 形式。
// 管理ダッシュボードの可視化カード用に、行を表示しやすい形へ写像する純関数。

export interface HubDataRow {
  id?: string | number | null;
  created_at?: string | null;
  metadata?: Record<string, unknown> | null;
}

export interface AutoErrorReport {
  id: string;
  message: string;
  firstLine: string;
  createdAt: string;
}

const _autoReportHeader = "[自動エラー報告]";

/// message から表示用の先頭意味行を抽出する。ヘッダ行と空行を除いた最初の行
/// (= 実際のエラーメッセージ) を返し、長すぎる場合は省略する。
export function extractAutoErrorFirstLine(message: string): string {
  const lines = (message ?? "")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
  // ヘッダ行以外の最初の行 (headerless message なら lines[0] が返る)。
  // ヘッダのみ/空なら "" に落とす。
  const meaningful = lines.find((line) => line !== _autoReportHeader) ?? "";
  return meaningful.length > 140 ? `${meaningful.slice(0, 138)}…` : meaningful;
}

/// hub_data 行配列を AutoErrorReport 配列へ写像する。
export function mapAutoErrorReports(
  rows: HubDataRow[] | null | undefined,
): AutoErrorReport[] {
  return (rows ?? []).map((row) => {
    const meta = row?.metadata ?? {};
    const message = String((meta as Record<string, unknown>).message ?? "")
      .trim();
    return {
      id: String(row?.id ?? ""),
      message,
      firstLine: extractAutoErrorFirstLine(message),
      createdAt: String(row?.created_at ?? ""),
    };
  });
}

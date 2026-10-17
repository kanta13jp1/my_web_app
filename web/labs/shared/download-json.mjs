/**
 * JSONをブラウザーから1回ダウンロードするための共通ヘルパー。
 * 保存ボタンなどのユーザー操作から呼び出す。通信・クラウド保存は行わない。
 * 呼び出し側がスキーマ、ファイル名、エラー表示を決める。
 * JSON.stringifyの変換規則が適用され、undefined等の値は省略される場合がある。
 * トップレベルにはJSONへ変換可能な値を渡すこと。型の検証やサイズ制限は行わない。
 * ダウンロードの開始を要求するだけで、保存完了や保存先を確認する機能ではない。
 * 一時URLはクリック後1秒で解放する。ブラウザーの保存許可・ポリシーによっては保存されない。
 *
 * @param {*} value - JSONへ変換する値。循環参照やBigIntを含めない。
 * @param {string} filename - 呼び出し側が決めるファイル名（例: settings.json）。
 * @returns {void} 保存完了を表すPromiseや結果は返さない。
 * @throws {TypeError} 循環参照やBigInt等でJSON.stringifyが失敗した場合。その他の変換・DOM操作の例外も呼び出し側へ伝わる。
 * @example
 * import { downloadJson } from '/labs/shared/download-json.mjs';
 *
 * // ボタンのクリックハンドラー内で、合成した設定を保存する。
 * try {
 *   downloadJson({ version: 1, theme: 'light' }, 'settings.json');
 * } catch (error) {
 *   // 実際の画面では入力を保持し、再試行できるエラーを表示する。
 *   console.error('JSON保存を開始できませんでした', error);
 * }
 */
export function downloadJson(value, filename) {
  const blob = new Blob([JSON.stringify(value, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  try {
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.click();
  } finally {
    // Give the browser time to start the download, including on repeated saves.
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
}

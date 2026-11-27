import {
  buildClipMarkdown,
  buildSourceKey,
  normalizeTagsInput,
} from './lib/clip_formatter.mjs';
import { saveClippedNote, testConnection } from './lib/jibun_api_client.mjs';

const STORAGE_KEY_API = 'jibun_api_key';

const elements = {
  engineBadge: document.getElementById('engineBadge'),
  clipMode: document.getElementById('clipMode'),
  clipTitle: document.getElementById('clipTitle'),
  clipTags: document.getElementById('clipTags'),
  saveToInbox: document.getElementById('saveToInbox'),
  clipPreview: document.getElementById('clipPreview'),
  saveButton: document.getElementById('saveButton'),
  settingsPanel: document.getElementById('settingsPanel'),
  apiKeyInput: document.getElementById('apiKeyInput'),
  saveKeyButton: document.getElementById('saveKeyButton'),
  testKeyButton: document.getElementById('testKeyButton'),
  statusMessage: document.getElementById('statusMessage'),
};

let extractedState = null;

function setStatus(message, kind = 'info') {
  elements.statusMessage.textContent = message;
  elements.statusMessage.className = `status ${kind}`;
}

async function readStoredApiKey() {
  const stored = await chrome.storage.local.get(STORAGE_KEY_API);
  return typeof stored[STORAGE_KEY_API] === 'string' ? stored[STORAGE_KEY_API] : '';
}

async function writeStoredApiKey(apiKey) {
  await chrome.storage.local.set({ [STORAGE_KEY_API]: apiKey.trim() });
}

function updatePreviewFromState() {
  if (!extractedState) return;
  const mode = elements.clipMode.value;
  const formatted = buildClipMarkdown({
    title: elements.clipTitle.value || extractedState.title,
    url: extractedState.url,
    excerpt: extractedState.excerpt,
    markdownBody: extractedState.markdownBody,
    selectedText: extractedState.selectedText,
    mode,
  });
  elements.clipPreview.value = formatted.content;
}

async function injectOptionalVendorScripts(tabId) {
  const vendorFiles = ['vendor/Readability.js', 'vendor/turndown.js'];
  for (const file of vendorFiles) {
    try {
      const check = await fetch(chrome.runtime.getURL(file));
      if (!check.ok) continue;
      await chrome.scripting.executeScript({
        target: { tabId },
        files: [file],
      });
    } catch {
      // Optional vendor bundle not built yet; content_extractor.js falls back cleanly.
    }
  }
}

async function extractActiveTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || typeof tab.id !== 'number') {
    throw new Error('アクティブなタブが見つかりません。');
  }
  if (!tab.url || (!tab.url.startsWith('http://') && !tab.url.startsWith('https://'))) {
    throw new Error('http / https ページのみクリップできます。');
  }

  await injectOptionalVendorScripts(tab.id);
  const results = await chrome.scripting.executeScript({
    target: { tabId: tab.id },
    files: ['content_extractor.js'],
  });
  const result = results?.[0]?.result;
  if (!result) {
    throw new Error('ページ内容の抽出に失敗しました。');
  }
  extractedState = result;
  elements.clipTitle.value = result.title || tab.title || '';
  if (result.selectedText) {
    elements.clipMode.value = 'selection';
  }
  elements.engineBadge.textContent =
    result.engine === 'readability+turndown'
      ? 'Readability'
      : 'DOM抽出';
  updatePreviewFromState();
}

async function handleSaveClip() {
  if (!extractedState) {
    setStatus('ページ内容を読み込み中です。', 'error');
    return;
  }
  const apiKey = elements.apiKeyInput.value.trim() || (await readStoredApiKey());
  if (!apiKey) {
    elements.settingsPanel.open = true;
    setStatus('先に APIキー（jibun_sk_...）を設定してください。', 'error');
    return;
  }

  elements.saveButton.disabled = true;
  setStatus('自分株式会社へ保存しています...');
  try {
    const mode = elements.clipMode.value;
    const formatted = buildClipMarkdown({
      title: elements.clipTitle.value,
      url: extractedState.url,
      excerpt: extractedState.excerpt,
      markdownBody: extractedState.markdownBody,
      selectedText: extractedState.selectedText,
      mode,
    });
    const tags = normalizeTagsInput(elements.clipTags.value);
    const captureStatus = elements.saveToInbox.checked ? 'inbox' : 'organized';
    const sourceKey = buildSourceKey(extractedState.url, mode);

    const res = await saveClippedNote({
      apiKey,
      title: formatted.title,
      content: formatted.content,
      tags,
      captureStatus,
      sourceKey,
    });
    if (!res.ok) {
      setStatus(res.error, 'error');
      return;
    }
    setStatus(
      `保存しました（ノートID: ${res.note?.id ?? '-'} / ${captureStatus}）`,
      'success',
    );
  } finally {
    elements.saveButton.disabled = false;
  }
}

async function init() {
  const savedKey = await readStoredApiKey();
  if (savedKey) {
    elements.apiKeyInput.value = savedKey;
  } else {
    elements.settingsPanel.open = true;
  }

  elements.clipMode.addEventListener('change', updatePreviewFromState);
  elements.clipTitle.addEventListener('input', updatePreviewFromState);
  elements.saveButton.addEventListener('click', handleSaveClip);

  elements.saveKeyButton.addEventListener('click', async () => {
    const key = elements.apiKeyInput.value.trim();
    await writeStoredApiKey(key);
    setStatus('APIキーをブラウザローカルに保存しました。', 'success');
  });

  elements.testKeyButton.addEventListener('click', async () => {
    const key = elements.apiKeyInput.value.trim();
    setStatus('接続を確認しています...');
    const res = await testConnection({ apiKey: key });
    if (!res.ok) {
      setStatus(res.error, 'error');
      return;
    }
    if (!res.canWriteNotes) {
      setStatus('接続成功ですが notes.write スコープがありません。', 'error');
      return;
    }
    await writeStoredApiKey(key);
    setStatus('接続成功（notes.write 有効）', 'success');
  });

  try {
    await extractActiveTab();
    setStatus('クリップ準備完了');
  } catch (err) {
    elements.engineBadge.textContent = '対象外';
    elements.saveButton.disabled = true;
    setStatus(err instanceof Error ? err.message : String(err), 'error');
  }
}

init();

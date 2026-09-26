// One-shot local JSON download. Callers own the schema, name and UI feedback.
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

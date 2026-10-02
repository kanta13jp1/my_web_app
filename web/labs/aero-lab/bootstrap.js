import('./lab.js').catch((error) => {
  const status = document.getElementById('scene-status');
  status.hidden = false;
  status.setAttribute('role', 'alert');
  status.textContent = '実験室を読み込めませんでした。ページを再読み込みしてください。';
  console.error('AERO LAB module loading failed', error);
});

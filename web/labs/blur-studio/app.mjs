const palettes = {
  apricot: ['#ffb85e', '#f68368', '#f6d789', 'Apricot'],
  iris: ['#b7b3ee', '#dda6c4', '#c9d6f4', 'Iris'],
  mint: ['#a5d7b6', '#9ecfca', '#d5e6a0', 'Mint'],
};
const form = document.querySelector('form');
const blur = document.querySelector('#blur');
const palette = document.querySelector('#palette');
const enabled = document.querySelector('#enabled');
const reduction = matchMedia('(prefers-reduced-transparency: reduce)');
function render() {
  const [one, two, three, name] = palettes[palette.value] ?? palettes.apricot;
  const radius = Math.max(0, Math.min(48, Number(blur.value) || 0));
  for (const [key, value] of Object.entries({ one, two, three, blur: `${enabled.checked ? radius : 0}px` })) {
    document.documentElement.style.setProperty(`--${key}`, value);
  }
  document.querySelector('#amount').value = `${radius} px`;
  blur.disabled = !enabled.checked;
  document.querySelector('#status').textContent = reduction.matches
    ? `${name} · OSの透明度低減設定により、ぼかしなし`
    : `${name} · ${enabled.checked ? `${radius} px` : 'ぼかしなし'}`;
}
form.addEventListener('input', render);
form.addEventListener('reset', event => {
  event.preventDefault();
  blur.value = blur.defaultValue;
  palette.value = 'apricot';
  enabled.checked = enabled.defaultChecked;
  render();
});
reduction.addEventListener('change', render);
document.querySelector('#settings').disabled = false;
render();
document.querySelector('#fallback').hidden = true;

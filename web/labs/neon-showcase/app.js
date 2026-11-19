import { renderBlenderArtwork, renderDemoArtwork } from './artworks.js';
import {
  BLENDER_WORKS,
  CONCEPT_PLANS,
  LIVE_DEMOS,
  VIRAL_LAWS,
  X_BENCHMARKS,
} from './catalog.js';

const SAFE_SLUG = /^[a-z0-9-]+$/;
const SAFE_X_URL = /^https:\/\/x\.com\/[A-Za-z0-9_]+\/status\/[0-9]+(?:\/[A-Za-z0-9_/-]*)?$/;

const state = {
  tab: 'demos',
  query: '',
  demoCat: 'all',
  benchCat: 'all',
  benchSort: 'views',
  blenderAngles: {},
};

const contentRoot = document.getElementById('content-root');
const filterChips = document.getElementById('filter-chips');
const resultCount = document.getElementById('result-count');
const searchInput = document.getElementById('search-input');
const resetBtn = document.getElementById('reset-filter');
const tabButtons = Array.from(document.querySelectorAll('[data-tab]'));

const modal = document.getElementById('demo-modal');
const modalTitle = document.getElementById('modal-title');
const modalSub = document.getElementById('modal-sub');
const modalOpenTab = document.getElementById('modal-open-tab');
const modalFullscreen = document.getElementById('modal-fullscreen');
const modalClose = document.getElementById('modal-close');
const modalStageWrap = document.getElementById('modal-stage-wrap');
const modalIframe = document.getElementById('modal-iframe');

function esc(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function safeXUrl(url) {
  const value = String(url ?? '').trim();
  return SAFE_X_URL.test(value) ? value : 'https://x.com/';
}

function syncCounts() {
  const pairs = [
    ['stat-demos', LIVE_DEMOS.length],
    ['tab-count-demos', LIVE_DEMOS.length],
    ['stat-blender', BLENDER_WORKS.length],
    ['tab-count-blender', BLENDER_WORKS.length],
    ['stat-plans', CONCEPT_PLANS.length],
    ['tab-count-plans', CONCEPT_PLANS.length],
    ['stat-bench', X_BENCHMARKS.length],
    ['tab-count-benchmarks', X_BENCHMARKS.length],
  ];
  for (const [id, count] of pairs) {
    const el = document.getElementById(id);
    if (el) el.textContent = String(count);
  }
}

function fmtNum(n) {
  return Number(n || 0).toLocaleString('ja-JP');
}

function matchesQuery(fields) {
  const q = state.query.trim().toLowerCase();
  if (!q) return true;
  return fields.some((f) => String(f ?? '').toLowerCase().includes(q));
}

function syncModalFullscreenLabel() {
  if (!modalFullscreen) return;
  const active = Boolean(document.fullscreenElement);
  modalFullscreen.textContent = active ? '⛶ フル画面解除' : '⛶ フル画面';
}

function openDemoModal(slug) {
  const demo = LIVE_DEMOS.find((d) => d.slug === slug);
  if (!demo || !SAFE_SLUG.test(demo.slug)) return;
  const url = `./demos/${demo.slug}.html`;
  modalTitle.textContent = demo.title;
  modalSub.textContent = `${demo.model} · ${demo.categoryLabel} · ${demo.sizeKb} KB · 外部ライブラリ 0`;
  modalOpenTab.href = url;
  modal.hidden = false;
  syncModalFullscreenLabel();
  modalIframe.src = url;
  modalClose.focus();
}

function closeDemoModal() {
  if (modal.hidden) return;
  if (document.fullscreenElement) {
    document.exitFullscreen?.().catch(() => {});
  }
  modalIframe.src = 'about:blank';
  modal.hidden = true;
}

function renderEmpty(message) {
  contentRoot.innerHTML = `
    <div class="empty-box" role="status">
      <p>${esc(message)}</p>
      <button type="button" class="btn btn-primary" data-action="reset-all">条件をリセットして全件表示</button>
    </div>
  `;
}

function renderDemos() {
  const categories = [
    ['all', 'すべて'],
    ['cinema', '3Dシネマ'],
    ['workstation', '3Dワークステーション'],
    ['game', 'ゲーム'],
    ['physics', '物理・GLSL'],
    ['ui', 'UIショーケース'],
  ];
  filterChips.innerHTML = categories
    .map(
      ([id, label]) =>
        `<button type="button" class="chip ${state.demoCat === id ? 'active' : ''}" data-demo-cat="${id}">${label}</button>`,
    )
    .join('');

  const filtered = LIVE_DEMOS.filter((d) => {
    if (state.demoCat !== 'all' && d.category !== state.demoCat) return false;
    return matchesQuery([d.title, d.enTitle, d.summary, d.model, d.categoryLabel, ...(d.tags || [])]);
  });

  resultCount.textContent = `${filtered.length} / ${LIVE_DEMOS.length} 作品`;
  if (filtered.length === 0) {
    renderEmpty('一致するライブ作品が見つかりませんでした。');
    return;
  }

  contentRoot.innerHTML = `<div class="grid">${filtered
    .map((d) => {
      const safeSlug = SAFE_SLUG.test(d.slug) ? d.slug : '';
      return `
        <article class="card ${d.featured ? 'featured' : ''}" data-demo-slug="${esc(safeSlug)}">
          <div class="thumb-box">
            ${renderDemoArtwork(d)}
            <div class="badge-row">
              <span class="pill pill-gold">${esc(d.episode)} · ${esc(d.model)}</span>
              <span class="pill pill-cyan">${esc(d.categoryLabel)}</span>
            </div>
          </div>
          <div class="card-body">
            <div class="card-meta">
              <span>${d.sizeKb} KB 単一HTML</span>
              ${d.metrics ? `<span class="metric-chip">${esc(d.metrics)}</span>` : ''}
            </div>
            <h2 class="card-title">${esc(d.title)}</h2>
            <p class="card-desc">${esc(d.summary)}</p>
            <div class="tag-list">${(d.tags || []).map((t) => `<span class="tag">${esc(t)}</span>`).join('')}</div>
            <div class="card-actions">
              <button type="button" class="btn btn-primary" data-launch-demo="${esc(safeSlug)}">今すぐ体験</button>
              <a class="btn btn-ghost" href="./demos/${esc(safeSlug)}.html" target="_blank" rel="noopener noreferrer">別タブ</a>
            </div>
          </div>
        </article>
      `;
    })
    .join('')}</div>`;
}

function renderBlender() {
  filterChips.innerHTML = `<span class="chip active">Blender 5.3 Python 完全プロシージャル（外部素材 0）</span>`;
  const filtered = BLENDER_WORKS.filter((b) =>
    matchesQuery([b.title, b.model, b.summary, b.specs, ...(b.highlights || [])]),
  );
  resultCount.textContent = `${filtered.length} / ${BLENDER_WORKS.length} 作品`;
  if (filtered.length === 0) {
    renderEmpty('一致するBlender作品が見つかりませんでした。');
    return;
  }

  contentRoot.innerHTML = `<div class="grid">${filtered
    .map((b) => {
      const angles = b.angles || [{ key: 'main', label: '構成プレビュー' }];
      const activeIdx = state.blenderAngles[b.id] ?? 0;
      const angle = angles[activeIdx] || angles[0];
      const switcher =
        angles.length > 1
          ? `<div class="angle-bar">${angles
              .map(
                (t, idx) =>
                  `<button type="button" class="angle-btn ${idx === activeIdx ? 'active' : ''}" data-blender-id="${esc(b.id)}" data-angle-idx="${idx}">${esc(t.label)}</button>`,
              )
              .join('')}</div>`
          : '';
      return `
        <article class="card ${b.id === 'tourbillon-watch-3d' ? 'featured' : ''}">
          <div class="thumb-box" data-blender-card="${esc(b.id)}" data-art-angle="${esc(angle.key)}">
            ${renderBlenderArtwork(b, angle.key)}
            <div class="badge-row">
              <span class="pill pill-gold">${esc(b.episode)}</span>
              <span class="pill pill-cyan">${esc(b.model)}</span>
            </div>
          </div>
          <div class="card-body">
            <div class="card-meta">
              <span>${esc(b.scriptSize)}</span>
              ${b.metrics ? `<span class="metric-chip">${esc(b.metrics)}</span>` : ''}
            </div>
            <h2 class="card-title">${esc(b.title)}</h2>
            ${switcher}
            <p class="card-desc">${esc(b.summary)}</p>
            <ul class="bullet-list">${(b.highlights || []).map((h) => `<li>${esc(h)}</li>`).join('')}</ul>
            <div class="card-meta"><span>仕様: ${esc(b.specs)}</span></div>
            ${
              b.demoSlug && SAFE_SLUG.test(b.demoSlug)
                ? `<div class="card-actions">
                     <button type="button" class="btn btn-primary" data-launch-demo="${esc(b.demoSlug)}">今すぐライブ体験（WebGL2）</button>
                     <a class="btn btn-ghost" href="./demos/${esc(b.demoSlug)}.html" target="_blank" rel="noopener noreferrer">別タブ</a>
                   </div>`
                : ''
            }
          </div>
        </article>
      `;
    })
    .join('')}</div>`;
}

function renderPlans() {
  filterChips.innerHTML = `<span class="chip active">20件のバズ分析から導出した4法則 ＋ 次回作ロードマップ</span>`;
  const filteredPlans = CONCEPT_PLANS.filter((p) =>
    matchesQuery([p.title, p.summary, p.benchmark, p.status]),
  );
  resultCount.textContent = `${filteredPlans.length} / ${CONCEPT_PLANS.length} 企画`;

  const lawsHtml = `
    <section aria-label="20件分析の4法則">
      <div class="laws-grid">
        ${VIRAL_LAWS.map(
          (l) => `
          <div class="law-card">
            <div class="law-num">LAW ${esc(l.num)}</div>
            <h2 class="law-title">${esc(l.title)}</h2>
            <div class="law-ev">${esc(l.evidence)}</div>
            <p class="law-detail">${esc(l.detail)}</p>
          </div>
        `,
        ).join('')}
      </div>
    </section>
  `;

  if (filteredPlans.length === 0) {
    contentRoot.innerHTML = lawsHtml;
    const emptyDiv = document.createElement('div');
    emptyDiv.innerHTML = `
      <div class="empty-box" role="status">
        <p>一致する企画案が見つかりませんでした。</p>
        <button type="button" class="btn btn-primary" data-action="reset-all">条件をリセットして全件表示</button>
      </div>
    `;
    contentRoot.appendChild(emptyDiv);
    return;
  }

  const plansHtml = `<div class="grid">${filteredPlans
    .map((p) => {
      const toneCls =
        p.statusTone === 'done' ? 'status-done' : p.statusTone === 'live' ? 'status-live' : 'status-next';
      let actionHtml = '';
      if (p.demoSlug && SAFE_SLUG.test(p.demoSlug)) {
        actionHtml = `<div class="card-actions"><button type="button" class="btn btn-primary" data-launch-demo="${esc(p.demoSlug)}">${esc(p.actionLabel || '今すぐライブ体験')}</button><a class="btn btn-ghost" href="./demos/${esc(p.demoSlug)}.html" target="_blank" rel="noopener noreferrer">別タブ</a></div>`;
      } else if (p.actionTab) {
        actionHtml = `<div class="card-actions"><button type="button" class="btn btn-ghost" data-jump-tab="${esc(p.actionTab)}">${esc(p.actionLabel)}</button></div>`;
      }
      return `
        <article class="card">
          <div class="card-body">
            <div><span class="status-badge ${toneCls}">${esc(p.status)}</span></div>
            <h3 class="card-title">${esc(p.title)}</h3>
            <div class="card-meta"><span>参照ベンチマーク: ${esc(p.benchmark)}</span></div>
            <p class="card-desc">${esc(p.summary)}</p>
            ${actionHtml}
          </div>
        </article>
      `;
    })
    .join('')}</div>`;

  contentRoot.innerHTML = lawsHtml + plansHtml;
}

function renderBenchmarks() {
  const cats = [
    ['all', 'すべて'],
    ['official', '公式'],
    ['comparison', '比較・コスパ'],
    ['fullscreen-3d', '全画面3Dアート'],
    ['japan', '日本語発信'],
  ];
  const sorts = [
    ['views', '再生数順'],
    ['likes', 'いいね順'],
    ['bookmarks', '保存(BM)順'],
  ];

  filterChips.innerHTML = [
    ...cats.map(
      ([id, label]) =>
        `<button type="button" class="chip ${state.benchCat === id ? 'active' : ''}" data-bench-cat="${id}">${label}</button>`,
    ),
    ...sorts.map(
      ([id, label]) =>
        `<button type="button" class="chip ${state.benchSort === id ? 'active' : ''}" data-bench-sort="${id}">⇅ ${label}</button>`,
    ),
  ].join('');

  const filtered = X_BENCHMARKS.filter((b) => {
    if (state.benchCat !== 'all' && b.category !== state.benchCat) return false;
    return matchesQuery([b.author, b.name, b.hook, b.visual, b.categoryLabel, b.format]);
  }).sort((a, b) => b[state.benchSort] - a[state.benchSort]);

  resultCount.textContent = `${filtered.length} / ${X_BENCHMARKS.length} 投稿`;
  if (filtered.length === 0) {
    renderEmpty('一致する参照X投稿が見つかりませんでした。');
    return;
  }

  contentRoot.innerHTML = `<div class="bench-list">${filtered
    .map(
      (b) => `
      <article class="bench-card">
        <div class="bench-head">
          <div>
            <div class="bench-author">${esc(b.author)} <span style="color:#94a3b8;font-weight:500;">· ${esc(b.name)}</span></div>
            <div class="card-meta"><span>${esc(b.format)}</span></div>
          </div>
          <span class="pill pill-cyan">${esc(b.categoryLabel)}</span>
        </div>
        <div class="bench-metrics" aria-label="エンゲージメント指標">
          <div><div class="bm-val ${state.benchSort === 'views' ? 'hi' : ''}">${fmtNum(b.views)}</div><div class="bm-lbl">Views</div></div>
          <div><div class="bm-val ${state.benchSort === 'likes' ? 'hi' : ''}">${fmtNum(b.likes)}</div><div class="bm-lbl">Likes</div></div>
          <div><div class="bm-val">${fmtNum(b.reposts)}</div><div class="bm-lbl">RP</div></div>
          <div><div class="bm-val">${fmtNum(b.replies)}</div><div class="bm-lbl">Reply</div></div>
          <div><div class="bm-val ${state.benchSort === 'bookmarks' ? 'hi' : ''}">${fmtNum(b.bookmarks)}</div><div class="bm-lbl">BM</div></div>
        </div>
        <p class="card-desc"><strong>伸びた要因:</strong> ${esc(b.hook)}</p>
        <p class="card-desc" style="color:#94a3b8;"><strong>表現メモ:</strong> ${esc(b.visual)}</p>
        <div class="card-actions">
          <a class="btn btn-ghost" style="flex:1;" href="${esc(safeXUrl(b.url))}" target="_blank" rel="noopener noreferrer">Xの元投稿を開く ↗</a>
        </div>
      </article>
    `,
    )
    .join('')}</div>`;
}

function render() {
  for (const btn of tabButtons) {
    btn.setAttribute('aria-selected', String(btn.dataset.tab === state.tab));
  }
  if (state.tab === 'demos') renderDemos();
  else if (state.tab === 'blender') renderBlender();
  else if (state.tab === 'plans') renderPlans();
  else renderBenchmarks();
}

function resetFilters() {
  state.query = '';
  state.demoCat = 'all';
  state.benchCat = 'all';
  state.benchSort = 'views';
  searchInput.value = '';
  render();
}

for (const btn of tabButtons) {
  btn.addEventListener('click', () => {
    state.tab = btn.dataset.tab;
    render();
  });
}

searchInput.addEventListener('input', () => {
  state.query = searchInput.value;
  render();
});

resetBtn.addEventListener('click', resetFilters);

filterChips.addEventListener('click', (e) => {
  const target = e.target.closest('button');
  if (!target) return;
  if (target.dataset.demoCat) {
    state.demoCat = target.dataset.demoCat;
    render();
  } else if (target.dataset.benchCat) {
    state.benchCat = target.dataset.benchCat;
    render();
  } else if (target.dataset.benchSort) {
    state.benchSort = target.dataset.benchSort;
    render();
  }
});

contentRoot.addEventListener('click', (e) => {
  const btn = e.target.closest('button');
  if (!btn) return;
  if (btn.dataset.launchDemo) {
    openDemoModal(btn.dataset.launchDemo);
  } else if (btn.dataset.jumpTab) {
    state.tab = btn.dataset.jumpTab;
    render();
  } else if (btn.dataset.blenderId) {
    state.blenderAngles[btn.dataset.blenderId] = Number(btn.dataset.angleIdx || 0);
    render();
  } else if (btn.dataset.action === 'reset-all') {
    resetFilters();
  }
});

modalClose.addEventListener('click', closeDemoModal);
if (modalFullscreen) {
  modalFullscreen.addEventListener('click', () => {
    if (document.fullscreenElement) {
      document.exitFullscreen?.().catch(() => {});
    } else {
      modalStageWrap.requestFullscreen?.().catch(() => {});
    }
  });
}
modalIframe.addEventListener('load', () => {
  if (!modal.hidden) {
    try {
      modalIframe.focus();
    } catch (_) {}
  }
});
document.addEventListener('fullscreenchange', syncModalFullscreenLabel);
modal.addEventListener('click', (e) => {
  if (e.target === modal) closeDemoModal();
});
window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !document.fullscreenElement) closeDemoModal();
});

// Support deep-link query ?tab=benchmarks or ?demo=sea-train-3d
const params = new URLSearchParams(window.location.search);
const initTab = params.get('tab');
if (initTab && ['demos', 'blender', 'plans', 'benchmarks'].includes(initTab)) {
  state.tab = initTab;
}
syncCounts();
render();
const initDemo = params.get('demo');
if (initDemo) {
  openDemoModal(initDemo);
}

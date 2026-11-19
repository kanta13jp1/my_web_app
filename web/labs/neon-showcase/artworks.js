// Procedural SVG artwork previews for NEON SHOWCASE cards.
// Pure self-contained vector graphics: zero external URLs, zero binary blobs.

function escAttr(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function wrapSvg(id, bgA, bgB, accent, body, label) {
  const safeId = escAttr(id).replace(/[^a-zA-Z0-9_-]/g, '');
  const caption = label
    ? `<text x="20" y="340" fill="rgba(226,232,240,0.72)" font-family="ui-monospace,SFMono-Regular,Consolas,monospace" font-size="11" letter-spacing="1.4">${escAttr(label)}</text>`
    : '';
  return `<svg class="art-svg" viewBox="0 0 640 360" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${escAttr(label || id)}">
    <defs>
      <linearGradient id="bg-${safeId}" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="${bgA}" />
        <stop offset="100%" stop-color="${bgB}" />
      </linearGradient>
      <radialGradient id="glow-${safeId}" cx="50%" cy="46%" r="48%">
        <stop offset="0%" stop-color="${accent}" stop-opacity="0.32" />
        <stop offset="100%" stop-color="${accent}" stop-opacity="0" />
      </radialGradient>
    </defs>
    <rect width="640" height="360" fill="url(#bg-${safeId})" />
    <rect width="640" height="360" fill="url(#glow-${safeId})" />
    ${body}
    ${caption}
  </svg>`;
}

function gearPath(cx, cy, rOuter, rInner, teeth) {
  const pts = [];
  for (let i = 0; i < teeth * 2; i += 1) {
    const a = (i * Math.PI) / teeth;
    const r = i % 2 === 0 ? rOuter : rInner;
    pts.push(`${(cx + Math.cos(a) * r).toFixed(1)},${(cy + Math.sin(a) * r).toFixed(1)}`);
  }
  return `M ${pts.join(' L ')} Z`;
}

export function renderDemoArtwork(demo) {
  const slug = demo.slug;
  if (slug === 'sea-train-3d') {
    return wrapSvg(
      slug,
      '#0b132b',
      '#1e294f',
      '#fbbf24',
      `
        <circle cx="496" cy="96" r="38" fill="#fef3c7" opacity="0.92" />
        <circle cx="496" cy="96" r="64" fill="#fbbf24" opacity="0.16" />
        <rect x="0" y="218" width="640" height="142" fill="#071326" />
        <line x1="0" y1="218" x2="640" y2="218" stroke="#fbbf24" stroke-opacity="0.55" stroke-width="1.5" />
        <g stroke="#fde68a" stroke-opacity="0.34" stroke-width="2">
          <line x1="448" y1="234" x2="544" y2="234" />
          <line x1="428" y1="252" x2="558" y2="252" />
          <line x1="452" y1="274" x2="532" y2="274" />
          <line x1="468" y1="296" x2="518" y2="296" />
        </g>
        <g fill="#0f172a" stroke="#f59e0b" stroke-width="1.4">
          <rect x="76" y="176" width="136" height="36" rx="4" />
          <rect x="220" y="176" width="136" height="36" rx="4" />
          <path d="M 366 172 L 454 172 L 474 196 L 474 212 L 366 212 Z" />
          <rect x="430" y="148" width="16" height="24" rx="2" />
        </g>
        <g fill="#fde68a">
          <rect x="92" y="186" width="18" height="12" rx="1.5" />
          <rect x="118" y="186" width="18" height="12" rx="1.5" />
          <rect x="144" y="186" width="18" height="12" rx="1.5" />
          <rect x="170" y="186" width="18" height="12" rx="1.5" />
          <rect x="236" y="186" width="18" height="12" rx="1.5" />
          <rect x="262" y="186" width="18" height="12" rx="1.5" />
          <rect x="288" y="186" width="18" height="12" rx="1.5" />
          <rect x="314" y="186" width="18" height="12" rx="1.5" />
          <rect x="382" y="184" width="24" height="14" rx="1.5" />
        </g>
        <g fill="#f59e0b" opacity="0.28">
          <rect x="92" y="226" width="96" height="10" rx="4" />
          <rect x="236" y="226" width="96" height="10" rx="4" />
        </g>
        <g fill="#fef08a" opacity="0.72">
          <circle cx="144" cy="144" r="2.2" />
          <circle cx="294" cy="128" r="2.6" />
          <circle cx="348" cy="148" r="2.0" />
          <circle cx="188" cy="272" r="3.5" />
          <circle cx="272" cy="286" r="3.0" />
          <circle cx="394" cy="266" r="3.2" />
        </g>
      `,
      'LIVE WEBGL2 · PLANAR REFLECTION · 5 CAMERAS',
    );
  }

  if (slug === 'blackhole-gr-3d') {
    return wrapSvg(
      slug,
      '#03050c',
      '#120b1e',
      '#f97316',
      `
        <ellipse cx="320" cy="180" rx="228" ry="44" fill="none" stroke="#fdba74" stroke-width="14" opacity="0.25" />
        <ellipse cx="320" cy="180" rx="196" ry="32" fill="none" stroke="#f97316" stroke-width="8" opacity="0.7" />
        <ellipse cx="320" cy="180" rx="156" ry="22" fill="none" stroke="#fef3c7" stroke-width="4" opacity="0.92" />
        <circle cx="320" cy="180" r="96" fill="none" stroke="#fb923c" stroke-width="6" opacity="0.65" />
        <circle cx="320" cy="180" r="84" fill="none" stroke="#fef3c7" stroke-width="2.5" opacity="0.9" />
        <circle cx="320" cy="180" r="76" fill="#020307" />
        <line x1="320" y1="26" x2="320" y2="104" stroke="#38bdf8" stroke-width="3" stroke-opacity="0.5" />
        <line x1="320" y1="256" x2="320" y2="334" stroke="#38bdf8" stroke-width="3" stroke-opacity="0.5" />
        <path d="M 116 184 Q 320 218 524 176" fill="none" stroke="#fff7ed" stroke-width="4.5" opacity="0.95" />
      `,
      'LIVE GLSL · 164-STEP GEODESIC RAYTRACER · 0 POLYGONS',
    );
  }

  if (slug === 'sentinel-earth-3d') {
    return wrapSvg(
      slug,
      '#040b18',
      '#08223d',
      '#38bdf8',
      `
        <circle cx="320" cy="176" r="102" fill="#07192f" stroke="#38bdf8" stroke-width="2.2" />
        <ellipse cx="320" cy="176" rx="102" ry="38" fill="none" stroke="#0ea5e9" stroke-opacity="0.45" />
        <ellipse cx="320" cy="176" rx="48" ry="102" fill="none" stroke="#0ea5e9" stroke-opacity="0.45" />
        <ellipse cx="320" cy="176" rx="154" ry="52" transform="rotate(-22 320 176)" fill="none" stroke="#22d3ee" stroke-dasharray="6 6" stroke-width="1.6" />
        <ellipse cx="320" cy="176" rx="154" ry="52" transform="rotate(26 320 176)" fill="none" stroke="#34d399" stroke-dasharray="4 7" stroke-width="1.6" />
        <path d="M 244 150 Q 320 86 402 156" fill="none" stroke="#fbbf24" stroke-width="2.4" />
        <path d="M 268 212 Q 344 134 396 196" fill="none" stroke="#f43f5e" stroke-width="2.2" />
        <circle cx="244" cy="150" r="5" fill="#fbbf24" />
        <circle cx="402" cy="156" r="5" fill="#22d3ee" />
        <circle cx="396" cy="196" r="5" fill="#f43f5e" />
      `,
      'LIVE WEBGL2 · 2K DIGITAL TWIN · 72 LEO SATELLITES',
    );
  }

  if (slug === 'quant-terminal-3d') {
    return wrapSvg(
      slug,
      '#040914',
      '#0f172a',
      '#10b981',
      `
        <g stroke="#1e293b" stroke-width="1">
          <line x1="60" y1="80" x2="580" y2="80" />
          <line x1="60" y1="140" x2="580" y2="140" />
          <line x1="60" y1="200" x2="580" y2="200" />
          <line x1="60" y1="260" x2="580" y2="260" />
        </g>
        <path d="M 60 260 L 140 220 L 210 236 L 280 156 L 340 168 L 410 112 L 490 132 L 580 76 L 580 280 L 60 280 Z" fill="#10b981" fill-opacity="0.16" />
        <polyline points="60,260 140,220 210,236 280,156 340,168 410,112 490,132 580,76" fill="none" stroke="#34d399" stroke-width="3" />
        <polyline points="60,272 150,248 230,256 310,214 390,228 480,192 580,176" fill="none" stroke="#f43f5e" stroke-width="2.4" stroke-dasharray="6 4" />
        <g fill="#38bdf8" opacity="0.65">
          <rect x="86" y="250" width="16" height="30" />
          <rect x="120" y="232" width="16" height="48" />
          <rect x="154" y="242" width="16" height="38" />
          <rect x="462" y="218" width="16" height="62" fill="#f43f5e" />
          <rect x="496" y="202" width="16" height="78" fill="#f43f5e" />
        </g>
      `,
      'LIVE WEBGL2 · 3D DEPTH TERRAIN & IV SURFACE',
    );
  }

  if (slug === 'fsd-lidar-3d') {
    return wrapSvg(
      slug,
      '#050a14',
      '#0d1c32',
      '#22d3ee',
      `
        <ellipse cx="320" cy="240" rx="220" ry="72" fill="none" stroke="#0ea5e9" stroke-opacity="0.35" stroke-dasharray="5 6" />
        <ellipse cx="320" cy="240" rx="150" ry="48" fill="none" stroke="#22d3ee" stroke-opacity="0.55" stroke-dasharray="4 5" />
        <ellipse cx="320" cy="240" rx="84" ry="28" fill="none" stroke="#38bdf8" stroke-opacity="0.8" />
        <path d="M 300 290 C 304 220 272 164 252 94" fill="none" stroke="#34d399" stroke-width="6" stroke-linecap="round" />
        <path d="M 340 290 C 336 220 304 164 284 94" fill="none" stroke="#34d399" stroke-width="6" stroke-linecap="round" opacity="0.55" />
        <rect x="292" y="218" width="56" height="36" rx="8" fill="#0f172a" stroke="#38bdf8" stroke-width="2.2" />
        <rect x="348" y="138" width="44" height="28" rx="4" fill="#f43f5e" fill-opacity="0.28" stroke="#fb7185" stroke-width="2" />
      `,
      'LIVE WEBGL2 · 64-CH LIDAR · OCCUPANCY VOXELS',
    );
  }

  if (slug === 'aeroflow-cfd-3d') {
    return wrapSvg(
      slug,
      '#050a16',
      '#111d36',
      '#38bdf8',
      `
        <path d="M 40 130 C 170 126 230 94 340 104 C 450 114 520 144 600 138" fill="none" stroke="#38bdf8" stroke-width="2.5" />
        <path d="M 40 162 C 170 158 230 122 340 132 C 450 142 520 176 600 166" fill="none" stroke="#22d3ee" stroke-width="2.5" />
        <path d="M 40 196 C 170 192 230 154 340 164 C 450 174 520 206 600 198" fill="none" stroke="#fbbf24" stroke-width="2.6" />
        <path d="M 40 230 C 170 226 240 224 350 228 C 460 232 520 238 600 230" fill="none" stroke="#f43f5e" stroke-width="2.2" />
        <path d="M 186 206 L 266 178 L 392 178 L 456 204 L 448 218 L 194 218 Z" fill="#0f172a" stroke="#e2e8f0" stroke-width="2" />
        <circle cx="244" cy="216" r="18" fill="#020617" stroke="#38bdf8" stroke-width="3" />
        <circle cx="404" cy="216" r="18" fill="#020617" stroke="#38bdf8" stroke-width="3" />
      `,
      'LIVE WEBGL2 · 136 STREAMLINES · CP HEATMAP',
    );
  }

  if (slug === 'helix-bio-3d') {
    return wrapSvg(
      slug,
      '#040d18',
      '#0c2238',
      '#34d399',
      `
        <path d="M 90 120 C 170 240 250 100 330 220 C 410 100 490 240 560 130" fill="none" stroke="#38bdf8" stroke-width="5" />
        <path d="M 90 220 C 170 100 250 240 330 120 C 410 240 490 100 560 210" fill="none" stroke="#34d399" stroke-width="5" />
        <g stroke="#fbbf24" stroke-width="3" stroke-opacity="0.72">
          <line x1="145" y1="158" x2="145" y2="184" />
          <line x1="210" y1="142" x2="210" y2="202" />
          <line x1="286" y1="146" x2="286" y2="196" />
          <line x1="364" y1="144" x2="364" y2="198" />
          <line x1="442" y1="142" x2="442" y2="200" />
          <line x1="510" y1="156" x2="510" y2="186" />
        </g>
        <circle cx="328" cy="170" r="24" fill="#34d399" fill-opacity="0.22" stroke="#6ee7b7" stroke-width="2" />
      `,
      'LIVE WEBGL2 · MOLECULAR DOCKING · LIVE FOLDING',
    );
  }

  if (slug === 'neocity-fpv-3d') {
    return wrapSvg(
      slug,
      '#090517',
      '#1e0b36',
      '#f472b6',
      `
        <g fill="#0f0722" stroke="#22d3ee" stroke-width="1.5">
          <rect x="64" y="108" width="66" height="196" />
          <rect x="148" y="64" width="76" height="240" stroke="#f472b6" />
          <rect x="246" y="128" width="58" height="176" />
          <rect x="336" y="84" width="84" height="220" stroke="#f472b6" />
          <rect x="442" y="114" width="64" height="190" />
          <rect x="524" y="92" width="56" height="212" stroke="#a855f7" />
        </g>
        <line x1="40" y1="304" x2="600" y2="304" stroke="#22d3ee" stroke-width="2" />
        <line x1="184" y1="168" x2="454" y2="168" stroke="#f472b6" stroke-width="3" />
        <line x1="112" y1="224" x2="516" y2="224" stroke="#38bdf8" stroke-width="2" stroke-dasharray="18 10" />
      `,
      'LIVE WEBGL2 · 284 SKYSCRAPERS · WASD FPV',
    );
  }

  if (slug === 'aegis-zero-3d') {
    return wrapSvg(
      slug,
      '#040917',
      '#1a102d',
      '#fb7185',
      `
        <circle cx="320" cy="400" r="210" fill="none" stroke="#38bdf8" stroke-width="3" opacity="0.55" />
        <polygon points="320,98 378,214 320,192 262,214" fill="#0f172a" stroke="#38bdf8" stroke-width="2.4" />
        <circle cx="320" cy="146" r="34" fill="none" stroke="#fb7185" stroke-width="2" stroke-dasharray="8 6" />
        <line x1="286" y1="146" x2="354" y2="146" stroke="#fb7185" stroke-width="1.4" />
        <line x1="320" y1="112" x2="320" y2="180" stroke="#fb7185" stroke-width="1.4" />
        <path d="M 164 268 Q 220 184 294 152" fill="none" stroke="#fbbf24" stroke-width="2.5" />
        <path d="M 476 268 Q 420 184 346 152" fill="none" stroke="#fbbf24" stroke-width="2.5" />
      `,
      'LIVE WEBGL2 · PLAYABLE 3D BOSS RAID · WASD+SPACE',
    );
  }

  const paletteByCat = {
    cinema: ['#0a1026', '#1e1b4b', '#fbbf24'],
    workstation: ['#061326', '#0f2544', '#38bdf8'],
    game: ['#120824', '#2a1044', '#f472b6'],
    physics: ['#04131c', '#0e2c3d', '#34d399'],
    ui: ['#0c1224', '#1e293b', '#818cf8'],
  };
  const [cA, cB, acc] = paletteByCat[demo.category] || ['#091224', '#162544', '#38bdf8'];
  return wrapSvg(
    slug,
    cA,
    cB,
    acc,
    `
      <g stroke="${acc}" stroke-opacity="0.24" fill="none">
        <circle cx="320" cy="172" r="118" stroke-width="1.4" />
        <circle cx="320" cy="172" r="82" stroke-width="1.8" stroke-dasharray="6 6" />
        <circle cx="320" cy="172" r="42" stroke-width="2.2" />
        <line x1="120" y1="172" x2="520" y2="172" stroke-width="1" />
        <line x1="320" y1="54" x2="320" y2="290" stroke-width="1" />
      </g>
      <text x="320" y="168" text-anchor="middle" fill="#f8fafc" font-family="system-ui,sans-serif" font-size="18" font-weight="700">${escAttr(demo.enTitle.slice(0, 36))}</text>
      <text x="320" y="196" text-anchor="middle" fill="${acc}" font-family="ui-monospace,Consolas,monospace" font-size="12">${escAttr(demo.model)} · ${escAttr(demo.sizeKb)} KB HTML</text>
    `,
    `ZERO-LIBRARY INTERACTIVE · ${String(demo.categoryLabel || '').toUpperCase()}`,
  );
}

export function renderBlenderArtwork(work, angleKey) {
  const id = `${work.id}-${angleKey}`;
  if (work.id === 'tourbillon-watch-3d') {
    if (angleKey === 'macro') {
      const g1 = gearPath(248, 178, 86, 74, 18);
      const g2 = gearPath(398, 178, 66, 56, 14);
      return wrapSvg(
        id,
        '#060509',
        '#1a1210',
        '#f59e0b',
        `
          <path d="${g1}" fill="#d97706" fill-opacity="0.22" stroke="#fbbf24" stroke-width="2.4" />
          <path d="${g2}" fill="#0284c7" fill-opacity="0.22" stroke="#38bdf8" stroke-width="2.4" />
          <circle cx="248" cy="178" r="46" fill="none" stroke="#fde68a" stroke-width="1.8" stroke-dasharray="5 4" />
          <circle cx="248" cy="178" r="14" fill="#be123c" stroke="#fda4af" stroke-width="2" />
          <circle cx="398" cy="178" r="11" fill="#be123c" stroke="#fda4af" stroke-width="2" />
          <path d="M 248 178 m -30 0 a 30 30 0 1 1 60 0 a 22 22 0 1 1 -44 0 a 14 14 0 1 1 28 0" fill="none" stroke="#38bdf8" stroke-width="1.8" />
          <line x1="248" y1="82" x2="398" y2="82" stroke="#94a3b8" stroke-dasharray="4 4" />
          <text x="323" y="74" text-anchor="middle" fill="#fde68a" font-family="ui-monospace,Consolas,monospace" font-size="11">d = m(N1+N2)/2 · PHASE LOCK</text>
        `,
        '手続図解プレビュー · 0:10 MACRO ESCAPEMENT & 3-AXIS CAGE',
      );
    }
    if (angleKey === 'exploded') {
      return wrapSvg(
        id,
        '#05060b',
        '#14111b',
        '#fbbf24',
        `
          <g transform="translate(320 0)">
            <ellipse cx="0" cy="64" rx="134" ry="26" fill="#38bdf8" fill-opacity="0.14" stroke="#7dd3fc" stroke-width="1.8" />
            <ellipse cx="0" cy="112" rx="126" ry="24" fill="#0f172a" fill-opacity="0.7" stroke="#fbbf24" stroke-width="2" />
            <line x1="0" y1="112" x2="72" y2="104" stroke="#38bdf8" stroke-width="3" />
            <ellipse cx="0" cy="166" rx="132" ry="26" fill="#f59e0b" fill-opacity="0.16" stroke="#fde68a" stroke-width="2" />
            <ellipse cx="0" cy="222" rx="116" ry="22" fill="#be123c" fill-opacity="0.2" stroke="#fb7185" stroke-width="1.8" />
            <ellipse cx="0" cy="278" rx="136" ry="26" fill="#1e293b" fill-opacity="0.7" stroke="#94a3b8" stroke-width="2" />
            <line x1="0" y1="64" x2="0" y2="278" stroke="#fbbf24" stroke-opacity="0.38" stroke-dasharray="4 5" />
          </g>
          <g fill="#cbd5e1" font-family="ui-monospace,Consolas,monospace" font-size="10">
            <text x="472" y="68">L5 SAPPHIRE</text>
            <text x="472" y="116">L4 BLUED HANDS</text>
            <text x="472" y="170">L3 18-GEAR TRAIN</text>
            <text x="472" y="226">L2 3-AXIS CAGE</text>
            <text x="472" y="282">L1 CASEBACK</text>
          </g>
        `,
        '手続図解プレビュー · 0:15 5-LAYER EXPLODED VIEW',
      );
    }
    const dialGear = gearPath(320, 212, 42, 35, 14);
    return wrapSvg(
      id,
      '#050509',
      '#1a130e',
      '#fbbf24',
      `
        <circle cx="320" cy="176" r="126" fill="#0b0d14" stroke="#f59e0b" stroke-width="6" />
        <circle cx="320" cy="176" r="112" fill="none" stroke="#fde68a" stroke-opacity="0.45" stroke-width="1.4" />
        <path d="${dialGear}" fill="#d97706" fill-opacity="0.24" stroke="#fbbf24" stroke-width="1.8" />
        <circle cx="320" cy="212" r="24" fill="none" stroke="#38bdf8" stroke-width="1.6" />
        <circle cx="320" cy="212" r="6" fill="#e11d48" />
        <line x1="320" y1="176" x2="320" y2="96" stroke="#38bdf8" stroke-width="4" stroke-linecap="round" />
        <line x1="320" y1="176" x2="388" y2="146" stroke="#7dd3fc" stroke-width="3" stroke-linecap="round" />
        <circle cx="320" cy="176" r="7" fill="#fbbf24" />
        <g stroke="#fde68a" stroke-width="2.4">
          <line x1="320" y1="62" x2="320" y2="74" />
          <line x1="434" y1="176" x2="422" y2="176" />
          <line x1="206" y1="176" x2="218" y2="176" />
        </g>
      `,
      '手続図解プレビュー · CALIBRE N-04 DIAL · 28,800 VPH',
    );
  }

  if (work.id === 'neon-tower-smash') {
    return wrapSvg(
      id,
      '#08091a',
      '#1e1136',
      '#22d3ee',
      `
        <g fill="#0e172a" stroke="#22d3ee" stroke-width="1.6">
          <rect x="274" y="88" width="28" height="22" transform="rotate(-14 288 99)" />
          <rect x="318" y="76" width="28" height="22" transform="rotate(18 332 87)" />
          <rect x="256" y="138" width="36" height="26" transform="rotate(-8 274 151)" />
          <rect x="304" y="142" width="36" height="26" />
          <rect x="348" y="136" width="36" height="26" transform="rotate(11 366 149)" />
          <rect x="268" y="180" width="104" height="28" />
          <rect x="268" y="214" width="104" height="28" />
          <rect x="268" y="248" width="104" height="28" />
        </g>
        <circle cx="196" cy="134" r="24" fill="#f43f5e" fill-opacity="0.32" stroke="#fb7185" stroke-width="2.5" />
        <line x1="108" y1="120" x2="170" y2="130" stroke="#fb7185" stroke-width="3" stroke-dasharray="8 6" />
      `,
      '手続図解プレビュー · 144 RIGID-BODY BLOCKS · BULLET',
    );
  }

  if (work.id === 'cyberpunk-city') {
    return wrapSvg(
      id,
      '#0b0518',
      '#210c38',
      '#f472b6',
      `
        <g fill="#120926" stroke="#f472b6" stroke-width="1.6">
          <rect x="84" y="96" width="64" height="196" />
          <rect x="174" y="58" width="84" height="234" stroke="#22d3ee" />
          <rect x="284" y="110" width="70" height="182" />
          <rect x="380" y="72" width="82" height="220" stroke="#22d3ee" />
          <rect x="488" y="106" width="64" height="186" />
        </g>
        <path d="M 60 288 L 284 190 L 356 190 L 580 288" fill="none" stroke="#38bdf8" stroke-width="2" />
      `,
      '手続図解プレビュー · BLENDER CYBERPUNK CITY + FPV',
    );
  }

  if (work.id === 'blender-domino') {
    return wrapSvg(
      id,
      '#070d1c',
      '#15233c',
      '#fbbf24',
      `
        <g fill="#0f172a" stroke="#fbbf24" stroke-width="2">
          <rect x="130" y="168" width="22" height="84" rx="3" transform="rotate(34 141 252)" />
          <rect x="206" y="166" width="22" height="86" rx="3" transform="rotate(24 217 252)" />
          <rect x="282" y="164" width="22" height="88" rx="3" transform="rotate(14 293 252)" />
          <rect x="358" y="162" width="22" height="90" rx="3" transform="rotate(5 369 252)" />
          <rect x="434" y="162" width="22" height="90" rx="3" />
          <rect x="502" y="162" width="22" height="90" rx="3" />
        </g>
        <line x1="72" y1="262" x2="568" y2="262" stroke="#38bdf8" stroke-opacity="0.6" stroke-width="2" />
      `,
      '手続図解プレビュー · RIGID-BODY DOMINO CASCADE',
    );
  }

  return wrapSvg(
    id,
    '#06101f',
    '#122844',
    '#38bdf8',
    `
      <g fill="none" stroke="#38bdf8" stroke-width="2">
        <polygon points="320,66 420,176 320,286 220,176" fill="#38bdf8" fill-opacity="0.1" />
        <polygon points="320,98 388,176 320,254 252,176" stroke="#a855f7" />
        <circle cx="320" cy="176" r="34" stroke="#fbbf24" />
      </g>
    `,
    '手続図解プレビュー · CRYSTAL KINETIC LOOP',
  );
}

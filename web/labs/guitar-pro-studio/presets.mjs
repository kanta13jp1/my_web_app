export const PRESETS = [
  {
    id: "midnight-fingerpicking-study",
    title: "Midnight Fingerpicking Study",
    description:
      "オリジナル練習曲：アルペジオ、ハンマリングオン、反復記号、コードネーム付き SMuFL 五線＋6線TAB。",
    alphaTex: String.raw`\title "Midnight Fingerpicking Study"
\subtitle "Original Acoustic Practice Etude"
\tempo 92
.
\track "Acoustic Guitar"
\instrument 25
\clef G2
\ts 4 4
\ro 0.5.8{ch "Am"} 1.4 2.3 0.2{h} 2.2 0.2 2.3 1.4 |
1.6.8{ch "Fmaj7"} 3.5 3.4 2.3 1.2 2.3 3.4 3.5 |
3.5.8{ch "C"} 2.4 0.3 1.2 0.1 1.2 0.3 2.4 |
3.6.8{ch "G"} 2.5 0.4 0.3 3.2 0.3 0.4 0.2 \rc 2 |
0.4.8{ch "Dm7"} 2.3 1.2 1.1 3.1 1.1 1.2 2.3 |
0.6.4{ch "E7"} 2.5.4 1.3.4 0.2.4 |
0.5.2{ch "Am"} (0.5 2.4 2.3 1.2 0.1).2 |
`,
  },
  {
    id: "acoustic-duo-etude",
    title: "Sunday Acoustic Duo",
    description:
      "オリジナル2トラック練習曲：Lead Melody と Rhythm Chords のトラック切替・SMuFL 連携確認。",
    alphaTex: String.raw`\title "Sunday Acoustic Duo"
\subtitle "2-Track Arpeggio & Harmony Etude"
\tempo 104
.
\track "Lead Melody"
\instrument 25
\clef G2
\ts 4 4
3.2.4{ch "G"} 0.1.8 2.1.8 3.1.4 2.1.4 |
3.2.4{ch "Em7"} 0.1.8 2.1.8 0.1.2 |
1.2.4{ch "C"} 3.2.4 0.1.4 3.2.8 1.2.8 |
3.3.4{ch "D"} 2.3.4 3.2.2 |
\track "Rhythm Chords"
\instrument 25
\clef G2
\ts 4 4
(3.6 2.5 0.4 0.3 3.2 3.1).2 (3.6 2.5 0.4 0.3 3.2 3.1).2 |
(0.6 2.5 2.4 0.3 3.2 0.1).2 (0.6 2.5 2.4 0.3 3.2 0.1).2 |
(3.5 2.4 0.3 1.2 0.1).2 (3.5 2.4 0.3 1.2 0.1).2 |
(0.4 2.3 3.2 2.1).2 (0.4 2.3 3.2 2.1).2 |
`,
  },
];

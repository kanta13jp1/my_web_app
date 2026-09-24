// lm_head slice: 候補トークン（A〜H等、最大数個）の行だけで logits を計算する。
//   logits[s, c] = dot(h[row_idx[s]], W_cand[c])     1ワークグループ = (系列s, 候補c)
struct Params { n_seq: u32, n_cand: u32, dim: u32, _pad: u32 }
@group(0) @binding(0) var<uniform> p: Params;
@group(0) @binding(1) var<storage, read> h: array<f32>;        // [T, dim]（最終RMSNorm後）
@group(0) @binding(2) var<storage, read> row_idx: array<u32>;  // 各系列の最終トークン位置
@group(0) @binding(3) var<storage, read> w: array<f32>;        // [n_cand, dim]
@group(0) @binding(4) var<storage, read_write> logits: array<f32>;  // [n_seq, n_cand]

const WG: u32 = 256u;
var<workgroup> partial: array<f32, WG>;

@compute @workgroup_size(WG)
fn main(@builtin(workgroup_id) wid: vec3<u32>, @builtin(local_invocation_id) lid: vec3<u32>) {
  let s = wid.x;
  let c = wid.y;
  let hb = row_idx[s] * p.dim;
  let wb = c * p.dim;
  var acc = 0.0;
  for (var i = lid.x; i < p.dim; i += WG) { acc += h[hb + i] * w[wb + i]; }
  partial[lid.x] = acc;
  workgroupBarrier();
  for (var off = WG / 2u; off > 0u; off >>= 1u) {
    if (lid.x < off) { partial[lid.x] += partial[lid.x + off]; }
    workgroupBarrier();
  }
  if (lid.x == 0u) { logits[s * p.n_cand + c] = partial[0]; }
}

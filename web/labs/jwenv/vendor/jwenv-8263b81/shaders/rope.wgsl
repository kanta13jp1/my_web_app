// RoPE（NEOX形式 = rotate_half。Qwen系はQ/K重みの並べ替えなし）in-place。
// cos/sin は CPU で (位置, i) ごとに計算したテーブルを使う（大きな角度でのGPU三角関数の精度差を避ける）
struct Params { tokens: u32, heads: u32, head_dim: u32, _pad: u32 }
@group(0) @binding(0) var<uniform> p: Params;
@group(0) @binding(1) var<storage, read_write> x: array<f32>;
@group(0) @binding(2) var<storage, read> pos: array<u32>;      // トークンごとの位置（パッキング時はシーケンス内位置）
@group(0) @binding(3) var<storage, read> cos_sin: array<f32>;  // [max_pos, head_dim/2, 2]

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) gid: vec3<u32>, @builtin(num_workgroups) nwg: vec3<u32>) {
  let half = p.head_dim / 2u;
  let i = gid.x + gid.y * nwg.x * 64u;
  if (i >= p.tokens * p.heads * half) { return; }
  let d = i % half;
  let th = i / half;           // token * heads + head
  let t = th / p.heads;
  let base = th * p.head_dim;
  let cs = (pos[t] * half + d) * 2u;
  let c = cos_sin[cs];
  let s = cos_sin[cs + 1u];
  let x0 = x[base + d];
  let x1 = x[base + d + half];
  x[base + d] = x0 * c - x1 * s;
  x[base + d + half] = x1 * c + x0 * s;
}

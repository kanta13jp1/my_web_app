// QK-Norm（Qwen3固有）: Q/Kをヘッド単位でRMSNorm（in-place）。 1ワークグループ = (トークン, ヘッド)
struct Params { tokens: u32, heads: u32, head_dim: u32, eps: f32 }
@group(0) @binding(0) var<uniform> p: Params;
@group(0) @binding(1) var<storage, read_write> x: array<f32>;
@group(0) @binding(2) var<storage, read> w: array<f32>;

const WG: u32 = 64u;
var<workgroup> partial: array<f32, WG>;

@compute @workgroup_size(WG)
fn main(@builtin(workgroup_id) wid: vec3<u32>, @builtin(local_invocation_id) lid: vec3<u32>) {
  let idx = wid.x + wid.y * 65535u;  // (token * heads + head)
  if (idx >= p.tokens * p.heads) { return; }
  let base = idx * p.head_dim;
  var s = 0.0;
  for (var i = lid.x; i < p.head_dim; i += WG) { let v = x[base + i]; s += v * v; }
  partial[lid.x] = s;
  workgroupBarrier();
  for (var off = WG / 2u; off > 0u; off >>= 1u) {
    if (lid.x < off) { partial[lid.x] += partial[lid.x + off]; }
    workgroupBarrier();
  }
  let inv = inverseSqrt(partial[0] / f32(p.head_dim) + p.eps);
  workgroupBarrier();
  for (var i = lid.x; i < p.head_dim; i += WG) { x[base + i] = x[base + i] * inv * w[i]; }
}

// RMSNorm: y = x / sqrt(mean(x^2) + eps) * w     1ワークグループ = 1行
struct Params { rows: u32, dim: u32, eps: f32, _pad: u32 }
@group(0) @binding(0) var<uniform> p: Params;
@group(0) @binding(1) var<storage, read> x: array<f32>;
@group(0) @binding(2) var<storage, read> w: array<f32>;
@group(0) @binding(3) var<storage, read_write> y: array<f32>;

const WG: u32 = 256u;
var<workgroup> partial: array<f32, WG>;

@compute @workgroup_size(WG)
fn main(@builtin(workgroup_id) wid: vec3<u32>, @builtin(local_invocation_id) lid: vec3<u32>) {
  let row = wid.x;
  if (row >= p.rows) { return; }
  let base = row * p.dim;
  var s = 0.0;
  for (var i = lid.x; i < p.dim; i += WG) { let v = x[base + i]; s += v * v; }
  partial[lid.x] = s;
  workgroupBarrier();
  for (var off = WG / 2u; off > 0u; off >>= 1u) {
    if (lid.x < off) { partial[lid.x] += partial[lid.x + off]; }
    workgroupBarrier();
  }
  let inv = inverseSqrt(partial[0] / f32(p.dim) + p.eps);
  for (var i = lid.x; i < p.dim; i += WG) { y[base + i] = x[base + i] * inv * w[i]; }
}

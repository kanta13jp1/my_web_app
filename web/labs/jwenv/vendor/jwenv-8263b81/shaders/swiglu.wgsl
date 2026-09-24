// SwiGLU: a = silu(gate) * up
struct Params { n: u32, _p0: u32, _p1: u32, _p2: u32 }
@group(0) @binding(0) var<uniform> p: Params;
@group(0) @binding(1) var<storage, read> gate: array<f32>;
@group(0) @binding(2) var<storage, read> up: array<f32>;
@group(0) @binding(3) var<storage, read_write> a: array<f32>;

@compute @workgroup_size(256)
fn main(@builtin(global_invocation_id) gid: vec3<u32>, @builtin(num_workgroups) nwg: vec3<u32>) {
  let i = gid.x + gid.y * nwg.x * 256u;
  if (i >= p.n) { return; }
  let g = gate[i];
  a[i] = g / (1.0 + exp(-g)) * up[i];
}

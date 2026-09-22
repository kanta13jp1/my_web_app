// 今回計算したK(RoPE後)/Vを、プレフィックスKVキャッシュのプールへ書き込む（1層分）。
// info[2t].w = 書き込み先スロット（0xFFFFFFFF なら書かない）
struct Params { tokens: u32, kv_dim: u32, _p0: u32, _p1: u32 }
@group(0) @binding(0) var<uniform> p: Params;
@group(0) @binding(1) var<storage, read> k: array<f32>;
@group(0) @binding(2) var<storage, read> v: array<f32>;
@group(0) @binding(3) var<storage, read> info: array<vec4<u32>>;
@group(0) @binding(4) var<storage, read_write> ck: array<f32>;
@group(0) @binding(5) var<storage, read_write> cv: array<f32>;

@compute @workgroup_size(256)
fn main(@builtin(global_invocation_id) gid: vec3<u32>, @builtin(num_workgroups) nwg: vec3<u32>) {
  let i = gid.x + gid.y * nwg.x * 256u;
  if (i >= p.tokens * p.kv_dim) { return; }
  let t = i / p.kv_dim;
  let d = i % p.kv_dim;
  let slot = info[2u * t].w;
  if (slot == 0xFFFFFFFFu) { return; }
  ck[slot * p.kv_dim + d] = k[i];
  cv[slot * p.kv_dim + d] = v[i];
}

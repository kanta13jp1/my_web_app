// プレフィックスKVキャッシュ内のスロット範囲コピー（全層、K/V両方）。
// WebGPUのcopyBufferToBufferは同一バッファ内のコピーを許さないため、シェーダで行う（範囲は重ならない前提）。
struct Params { src: u32, dst: u32, rows: u32, kv_dim: u32, layer_stride: u32, n_layer: u32, _p0: u32, _p1: u32 }
@group(0) @binding(0) var<uniform> p: Params;
@group(0) @binding(1) var<storage, read_write> ck: array<f32>;
@group(0) @binding(2) var<storage, read_write> cv: array<f32>;

@compute @workgroup_size(256)
fn main(@builtin(global_invocation_id) gid: vec3<u32>, @builtin(num_workgroups) nwg: vec3<u32>) {
  let i = gid.x + gid.y * nwg.x * 256u;
  let per_layer = p.rows * p.kv_dim;
  if (i >= per_layer * p.n_layer) { return; }
  let l = i / per_layer;
  let r = i % per_layer;
  let s = l * p.layer_stride + p.src * p.kv_dim + r;
  let d = l * p.layer_stride + p.dst * p.kv_dim + r;
  ck[d] = ck[s];
  cv[d] = cv[s];
}

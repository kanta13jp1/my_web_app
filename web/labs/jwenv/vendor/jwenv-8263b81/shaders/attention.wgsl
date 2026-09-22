// GQA因果アテンション（プリフィル専用）。1ワークグループ = (クエリトークン, クエリヘッド)
// 複数リクエストを1系列にパッキングするため、トークンtは自分の系列のキーのみを参照する。
// プレフィックスKVキャッシュ: 系列の先頭 pref_len トークン分のK/Vはキャッシュプール(ck/cv)の
// スロット [pref_off, pref_off+pref_len) にあり、残り（今回計算した部分）はバッチ内の k/v にある。
//   キー番号 j < pref_len : pref_src=0 なら ck/cv[pref_off + j]、
//                           pref_src=1 ならバッチ内の別の系列の行 k/v[pref_off + j]（同じ接頭辞を持つ系列の共有）
//   キー番号 j >= pref_len: k/v[seg_start + (j - pref_len)]
// キーを128個ずつのチャンクで処理するオンラインsoftmax（共有メモリを小さく保ち占有率を上げる）。
// head_dim は 4 の倍数かつ 4*WG 以下を仮定（Qwen3は128）。
struct Params { tokens: u32, n_head: u32, n_kv: u32, head_dim: u32, scale: f32, _p0: u32, _p1: u32, _p2: u32 }
@group(0) @binding(0) var<uniform> p: Params;
@group(0) @binding(1) var<storage, read> q: array<vec4<f32>>;   // [T, n_head, hd]
@group(0) @binding(2) var<storage, read> k: array<vec4<f32>>;   // [T, n_kv, hd]
@group(0) @binding(3) var<storage, read> v: array<f32>;         // [T, n_kv, hd]
@group(0) @binding(4) var<storage, read> info: array<vec4<u32>>; // 2個/トークン: (seg_start, pref_off, pref_len, store_slot), (pref_src,-,-,-)
@group(0) @binding(5) var<storage, read> ck: array<vec4<f32>>;  // この層のキャッシュK [slots, n_kv, hd]
@group(0) @binding(6) var<storage, read> cv: array<f32>;        // この層のキャッシュV
@group(0) @binding(7) var<storage, read_write> o: array<f32>;   // [T, n_head, hd]

const WG: u32 = 128u;
var<workgroup> qs: array<vec4<f32>, 64>;
var<workgroup> pr: array<f32, WG>;
var<workgroup> red: array<f32, WG>;

fn reduce_max(x: f32, lid: u32) -> f32 {
  red[lid] = x;
  workgroupBarrier();
  for (var off = WG / 2u; off > 0u; off >>= 1u) {
    if (lid < off) { red[lid] = max(red[lid], red[lid + off]); }
    workgroupBarrier();
  }
  let r = red[0];
  workgroupBarrier();
  return r;
}

fn reduce_sum(x: f32, lid: u32) -> f32 {
  red[lid] = x;
  workgroupBarrier();
  for (var off = WG / 2u; off > 0u; off >>= 1u) {
    if (lid < off) { red[lid] += red[lid + off]; }
    workgroupBarrier();
  }
  let r = red[0];
  workgroupBarrier();
  return r;
}

@compute @workgroup_size(WG)
fn main(@builtin(workgroup_id) wid: vec3<u32>, @builtin(local_invocation_id) lid3: vec3<u32>) {
  let t = wid.x;
  let h = wid.y;
  let lid = lid3.x;
  let hd = p.head_dim;
  let hd4 = hd / 4u;
  let kvh = h / (p.n_head / p.n_kv);
  let qbase4 = (t * p.n_head + h) * hd4;
  if (lid < hd4) { qs[lid] = q[qbase4 + lid]; }
  workgroupBarrier();

  let inf = info[2u * t];
  let from_batch = info[2u * t + 1u].x == 1u;
  let s0 = inf.x;
  let pref_off = inf.y;
  let pref_len = inf.z;
  let n = pref_len + (t - s0 + 1u);
  var m_run = -3.0e38;
  var l_run = 0.0;
  var acc = 0.0;  // スレッドlidが次元lidを担当（lid < hd）
  for (var c0 = 0u; c0 < n; c0 += WG) {
    let j = c0 + lid;
    var s = -3.0e38;
    if (j < n) {
      var a = vec4<f32>(0.0);
      if (j < pref_len && !from_batch) {
        let kb4 = ((pref_off + j) * p.n_kv + kvh) * hd4;
        for (var d = 0u; d < hd4; d++) { a += qs[d] * ck[kb4 + d]; }
      } else if (j < pref_len) {
        let kb4 = ((pref_off + j) * p.n_kv + kvh) * hd4;
        for (var d = 0u; d < hd4; d++) { a += qs[d] * k[kb4 + d]; }
      } else {
        let kb4 = ((s0 + j - pref_len) * p.n_kv + kvh) * hd4;
        for (var d = 0u; d < hd4; d++) { a += qs[d] * k[kb4 + d]; }
      }
      s = (a.x + a.y + a.z + a.w) * p.scale;
    }
    let m_new = max(m_run, reduce_max(s, lid));
    var e = 0.0;
    if (j < n) { e = exp(s - m_new); }
    pr[lid] = e;
    let csum = reduce_sum(e, lid);  // 内部のバリアで pr の書き込みも見える
    let alpha = exp(m_run - m_new);
    l_run = l_run * alpha + csum;
    if (lid < hd) {
      var sacc = 0.0;
      let cn = min(WG, n - c0);
      for (var jj = 0u; jj < cn; jj++) {
        let jg = c0 + jj;
        var vv: f32;
        if (jg < pref_len && !from_batch) { vv = cv[((pref_off + jg) * p.n_kv + kvh) * hd + lid]; }
        else if (jg < pref_len) { vv = v[((pref_off + jg) * p.n_kv + kvh) * hd + lid]; }
        else { vv = v[((s0 + jg - pref_len) * p.n_kv + kvh) * hd + lid]; }
        sacc += pr[jj] * vv;
      }
      acc = acc * alpha + sacc;
    }
    m_run = m_new;
    workgroupBarrier();
  }
  if (lid < hd) { o[(t * p.n_head + h) * hd + lid] = acc / l_run; }
}

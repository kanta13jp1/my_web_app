// 行列積 C[M,N] (+)= A[M,K] · W[N,K]^T    （W は PyTorch/ggml と同じ [out, in] 行優先）
// タイル 64x64x32、256スレッド（各4x4出力）。共有メモリはvec4で読み、内側ループは vec4ロード2回 + FMA16回。
//   main_f32 : W は f32
//   main_q8  : W は Q8_0 を再配置したもの（quants: int8×4 を u32 に詰めた配列 / scales: 32要素ごとのf32スケール）
//              BK=32 が Q8_0 のブロック長と一致するため、タイル内の各行はスケール1個で逆量子化できる
//   main_kq  : W は K-quant（Q2_K〜Q6_K）を共通の形に再配置したもの（dequant.ts の repackKQuant）
//              quants: code を bits(2/4/8) ビットずつ u32 に詰めた配列 / scales: サブブロック(16 or 32要素)ごとの (scale, min)
//              x = scale * (code - zero) - min。サブブロックは BK=32 の中に収まる
// accumulate=1 のとき C += A·W^T（残差加算の融合）
struct Params { M: u32, N: u32, K: u32, accumulate: u32, bits: u32, gshift: u32, zero: u32, _p: u32 }
@group(0) @binding(0) var<uniform> p: Params;
@group(0) @binding(1) var<storage, read> A: array<vec4<f32>>;
@group(0) @binding(2) var<storage, read_write> C: array<f32>;
@group(0) @binding(3) var<storage, read> W: array<vec4<f32>>;
@group(0) @binding(4) var<storage, read> Wq: array<u32>;
@group(0) @binding(5) var<storage, read> Ws: array<f32>;

const BM: u32 = 64u;
const BN: u32 = 64u;
const BK: u32 = 32u;
// [BK][BM/4] / [BK][BN/4]
var<workgroup> As: array<vec4<f32>, 512>;
var<workgroup> Bs: array<vec4<f32>, 512>;

// A[m0.., k0..] をAsへ転置して格納（各スレッド vec4×2 をグローバルから読む）
fn load_a(tid: u32, m0: u32, k0: u32) {
  let K4 = p.K / 4u;
  for (var e = 0u; e < 2u; e++) {
    let idx = tid + e * 256u;       // 64行 × 8 vec4
    let m = idx / 8u;
    let k4 = idx % 8u;
    var v = vec4<f32>(0.0);
    if (m0 + m < p.M) { v = A[(m0 + m) * K4 + k0 / 4u + k4]; }
    let kk = k4 * 4u;
    As[(kk + 0u) * 16u + m / 4u][m % 4u] = v.x;
    As[(kk + 1u) * 16u + m / 4u][m % 4u] = v.y;
    As[(kk + 2u) * 16u + m / 4u][m % 4u] = v.z;
    As[(kk + 3u) * 16u + m / 4u][m % 4u] = v.w;
  }
}

fn compute_store(tx: u32, ty: u32, m0: u32, n0: u32, acc0: vec4<f32>, acc1: vec4<f32>, acc2: vec4<f32>, acc3: vec4<f32>) {
  var acc = array<vec4<f32>, 4>(acc0, acc1, acc2, acc3);
  for (var i = 0u; i < 4u; i++) {
    let m = m0 + ty * 4u + i;
    if (m >= p.M) { continue; }
    let base = m * p.N + n0 + tx * 4u;
    var v = acc[i];
    if (p.accumulate == 1u) { v += vec4<f32>(C[base], C[base + 1u], C[base + 2u], C[base + 3u]); }
    C[base] = v.x;
    C[base + 1u] = v.y;
    C[base + 2u] = v.z;
    C[base + 3u] = v.w;
  }
}

@compute @workgroup_size(16, 16)
fn main_f32(@builtin(workgroup_id) wid: vec3<u32>, @builtin(local_invocation_id) lid: vec3<u32>) {
  let tx = lid.x;
  let ty = lid.y;
  let tid = ty * 16u + tx;
  let n0 = wid.x * BN;
  let m0 = wid.y * BM;
  let K4 = p.K / 4u;
  var a0 = vec4<f32>(0.0); var a1 = vec4<f32>(0.0); var a2 = vec4<f32>(0.0); var a3 = vec4<f32>(0.0);
  for (var k0 = 0u; k0 < p.K; k0 += BK) {
    load_a(tid, m0, k0);
    for (var e = 0u; e < 2u; e++) {
      let idx = tid + e * 256u;
      let n = idx / 8u;
      let k4 = idx % 8u;
      let v = W[(n0 + n) * K4 + k0 / 4u + k4];
      let kk = k4 * 4u;
      Bs[(kk + 0u) * 16u + n / 4u][n % 4u] = v.x;
      Bs[(kk + 1u) * 16u + n / 4u][n % 4u] = v.y;
      Bs[(kk + 2u) * 16u + n / 4u][n % 4u] = v.z;
      Bs[(kk + 3u) * 16u + n / 4u][n % 4u] = v.w;
    }
    workgroupBarrier();
    for (var kk = 0u; kk < BK; kk++) {
      let a = As[kk * 16u + ty];
      let b = Bs[kk * 16u + tx];
      a0 += a.x * b; a1 += a.y * b; a2 += a.z * b; a3 += a.w * b;
    }
    workgroupBarrier();
  }
  compute_store(tx, ty, m0, n0, a0, a1, a2, a3);
}

@compute @workgroup_size(16, 16)
fn main_q8(@builtin(workgroup_id) wid: vec3<u32>, @builtin(local_invocation_id) lid: vec3<u32>) {
  let tx = lid.x;
  let ty = lid.y;
  let tid = ty * 16u + tx;
  let n0 = wid.x * BN;
  let m0 = wid.y * BM;
  var a0 = vec4<f32>(0.0); var a1 = vec4<f32>(0.0); var a2 = vec4<f32>(0.0); var a3 = vec4<f32>(0.0);
  for (var k0 = 0u; k0 < p.K; k0 += BK) {
    load_a(tid, m0, k0);
    for (var e = 0u; e < 2u; e++) {
      let idx = tid + e * 256u;   // 64行 × 8ワード
      let n = idx / 8u;
      let word = idx % 8u;
      let elem = (n0 + n) * p.K + k0;
      let qw = bitcast<i32>(Wq[elem / 4u + word]);
      let sc = Ws[elem / 32u];
      let kk = word * 4u;
      Bs[(kk + 0u) * 16u + n / 4u][n % 4u] = f32(extractBits(qw, 0u, 8u)) * sc;
      Bs[(kk + 1u) * 16u + n / 4u][n % 4u] = f32(extractBits(qw, 8u, 8u)) * sc;
      Bs[(kk + 2u) * 16u + n / 4u][n % 4u] = f32(extractBits(qw, 16u, 8u)) * sc;
      Bs[(kk + 3u) * 16u + n / 4u][n % 4u] = f32(extractBits(qw, 24u, 8u)) * sc;
    }
    workgroupBarrier();
    for (var kk = 0u; kk < BK; kk++) {
      let a = As[kk * 16u + ty];
      let b = Bs[kk * 16u + tx];
      a0 += a.x * b; a1 += a.y * b; a2 += a.z * b; a3 += a.w * b;
    }
    workgroupBarrier();
  }
  compute_store(tx, ty, m0, n0, a0, a1, a2, a3);
}

@compute @workgroup_size(16, 16)
fn main_kq(@builtin(workgroup_id) wid: vec3<u32>, @builtin(local_invocation_id) lid: vec3<u32>) {
  let tx = lid.x;
  let ty = lid.y;
  let tid = ty * 16u + tx;
  let n0 = wid.x * BN;
  let m0 = wid.y * BM;
  let per = 32u / p.bits;  // 1ワードに入る要素数
  let wpr = p.bits;        // タイル1行（32要素）あたりのワード数
  let zero = f32(p.zero);
  var a0 = vec4<f32>(0.0); var a1 = vec4<f32>(0.0); var a2 = vec4<f32>(0.0); var a3 = vec4<f32>(0.0);
  for (var k0 = 0u; k0 < p.K; k0 += BK) {
    load_a(tid, m0, k0);
    for (var idx = tid; idx < 64u * wpr; idx += 256u) {
      let n = idx / wpr;
      let word = idx % wpr;
      let e0 = (n0 + n) * p.K + k0;  // この行のタイル先頭の要素番号（32の倍数）
      let qw = Wq[(e0 / 32u) * wpr + word];
      for (var b = 0u; b < per; b++) {
        let kk = word * per + b;
        let g = (e0 + kk) >> p.gshift;
        let c = f32(extractBits(qw, b * p.bits, p.bits)) - zero;
        Bs[kk * 16u + n / 4u][n % 4u] = Ws[2u * g] * c - Ws[2u * g + 1u];
      }
    }
    workgroupBarrier();
    for (var kk = 0u; kk < BK; kk++) {
      let a = As[kk * 16u + ty];
      let b = Bs[kk * 16u + tx];
      a0 += a.x * b; a1 += a.y * b; a2 += a.z * b; a3 += a.w * b;
    }
    workgroupBarrier();
  }
  compute_store(tx, ty, m0, n0, a0, a1, a2, a3);
}

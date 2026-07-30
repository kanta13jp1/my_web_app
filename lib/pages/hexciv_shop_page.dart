import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/shop_funnel_service.dart';
import '../services/shop_service.dart';
import '../theme/design_tokens.dart';

/// HexCiv (Windows 版) の商品ページ (2026-07-28 追加)。
///
/// 状態は4つあり、どれになるかで出す導線が変わる:
///   1. 商品が準備中 (`is_active = false` / Price 未設定) → 購入導線を出さない
///   2. 未ログイン → ログインへ誘導 (購入は user_id に紐づけるため)
///   3. ログイン済み・未購入 → 購入ボタン
///   4. 購入済み → ダウンロードボタン (何度でも押せる)
///
/// 「買えるように見えて買えない」を作らないことを優先している。
/// 商品が未整備のときに購入ボタンを出すと、押した先で必ず失敗するため。
class HexcivShopPage extends StatefulWidget {
  const HexcivShopPage({
    super.key,
    this.purchaseResult,
    this.service,
    this.funnel,
  });

  /// Stripe からの戻り (`?purchase=success` / `?purchase=canceled`)。
  final String? purchaseResult;

  /// テストから差し替えるための注入口。
  final ShopGateway? service;

  /// 計測の注入口。テストでは省略でき、その場合は計測を行わない。
  final ShopFunnelService? funnel;

  @override
  State<HexcivShopPage> createState() => _HexcivShopPageState();
}

/// ギャラリー1枚ぶんの情報 (2026-07-29 追加)。
///
/// `Assets/Editor/GameplayScreenshot.cs`(HexCiv リポジトリ) が同じターン数で
/// 焼いた絵に対応する。撮り直したらここのラベルも合わせること。
class _Screenshot {
  const _Screenshot({
    required this.asset,
    required this.labelJa,
    required this.captionJa,
  });

  final String asset;
  final String labelJa;
  final String captionJa;
}

class _HexcivShopPageState extends State<HexcivShopPage> {
  /// 並べる順序が「育っていく」説明そのものになっている。
  static const List<_Screenshot> _shots = [
    _Screenshot(
      asset: 'assets/shop/hexciv_turn30.png',
      labelJa: 'ターン30',
      captionJa: '序盤。4つの文明がそれぞれ都市を1〜3個持つだけで、地図の大半は未開のまま。',
    ),
    _Screenshot(
      asset: 'assets/shop/hexciv_turn80.png',
      labelJa: 'ターン80',
      captionJa: '中盤。国境が接し始め、都市と部隊が増えて版図の差が見えてくる。',
    ),
    _Screenshot(
      asset: 'assets/shop/hexciv_turn150.png',
      labelJa: 'ターン150',
      captionJa: '終盤。大陸をまたぐ版図と多数の部隊。序盤の地図と見比べると育ち方が分かる。',
    ),
  ];

  late final ShopGateway _service = widget.service ?? ShopService();

  bool _loading = true;
  String? _loadError;
  ShopProduct? _product;
  bool _purchased = false;

  /// ギャラリーで大きく表示している枚数の添字。
  int _selectedShot = 0;

  /// 購入・ダウンロードの実行中。二重押しを防ぐ。
  bool _working = false;
  String? _actionError;
  DownloadTicket? _lastTicket;

  /// 流入元。`?utm_source=itch_io` のように付いて来る。無ければ 'direct'。
  /// **これが無いとチャネル別の効果が最後まで判定できない**ため、
  /// 購入導線のどの記録にも同じ値を添える。
  late final String _source = ShopFunnelService.sourceFromUri(Uri.base);
  late final String _campaign = ShopFunnelService.campaignFromUri(Uri.base);

  @override
  void initState() {
    super.initState();
    _load();
    _recordFunnel(ShopFunnelService.stageProductView);
  }

  /// funnel を1段記録する。計測は本体機能ではないので待たず、失敗も無視する。
  void _recordFunnel(String stage) {
    final funnel = widget.funnel;
    if (funnel == null) return;
    unawaited(
      funnel.record(
        stage,
        productId: ShopService.hexcivProductId,
        source: _source,
        campaign: _campaign,
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final product = await _service.fetchProduct(ShopService.hexcivProductId);
      final purchased = product == null
          ? false
          : await _service.hasPurchased(ShopService.hexcivProductId);
      if (!mounted) return;
      setState(() {
        _product = product;
        _purchased = purchased;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  bool get _signedIn => _service.isSignedIn;

  Future<void> _startPurchase() async {
    setState(() {
      _working = true;
      _actionError = null;
    });
    // 押した時点で記録する。この後 Stripe 側で失敗しても「押された」事実は
    // 残したい (押下と Checkout 到達の差が、決済側の問題を映す)。
    _recordFunnel(ShopFunnelService.stagePurchaseClick);
    try {
      final start = await _service.startCheckout(
        ShopService.hexcivProductId,
        visitorId: await widget.funnel?.visitorId(),
        source: _source,
      );
      if (start.alreadyPurchased) {
        // 二重課金させず、そのまま購入済み表示へ切り替える。
        if (!mounted) return;
        setState(() {
          _purchased = true;
          _working = false;
        });
        return;
      }
      final url = Uri.parse(start.checkoutUrl!);
      // Checkout URL が返った = 決済画面まで到達。押下との差が決済側の問題を映す。
      _recordFunnel(ShopFunnelService.stageCheckoutRedirect);
      // 決済ページは同一タブで開く。別タブだと戻り先 (success_url) が
      // 元の画面と分かれてしまい、購入後の状態更新が伝わらない。
      await launchUrl(url, webOnlyWindowName: '_self');
      if (!mounted) return;
      setState(() => _working = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionError = error.toString();
        _working = false;
      });
    }
  }

  Future<void> _download() async {
    setState(() {
      _working = true;
      _actionError = null;
    });
    try {
      // URL は有効期限つきなので、押されたタイミングで都度取り直す。
      final ticket =
          await _service.requestDownloadUrl(ShopService.hexcivProductId);
      await launchUrl(
        Uri.parse(ticket.url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      setState(() {
        _lastTicket = ticket;
        _working = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionError = error.toString();
        _working = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface1,
        foregroundColor: DesignTokens.textPrimary,
        title: const Text('HexCiv — ダウンロード版'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return _notice(
        icon: Icons.error_outline,
        color: DesignTokens.orange,
        title: '商品情報を読み込めませんでした',
        body: _loadError!,
        action: TextButton(onPressed: _load, child: const Text('再試行')),
      );
    }

    final product = _product;
    // RLS により is_active=false の商品はそもそも読めない。
    // 「準備中」と「存在しない」を利用者に区別させる意味はないので同じ扱いにする。
    if (product == null) {
      return _notice(
        icon: Icons.schedule,
        color: DesignTokens.textSecondary,
        title: '準備中です',
        body: 'HexCiv のダウンロード版は現在準備中です。公開までもうしばらくお待ちください。',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.purchaseResult == 'canceled') ...[
          _notice(
            icon: Icons.info_outline,
            color: DesignTokens.textSecondary,
            title: '購入は完了していません',
            body: '購入手続きが中断されました。もう一度お試しいただけます。',
          ),
          const SizedBox(height: 16),
        ],
        _productCard(product),
        const SizedBox(height: 24),
        // スクリーンショット (2026-07-29 追加)。購入ボタンより**上**に置く。
        // ゲームは見た目を見ないと買う判断ができないため、判断材料を
        // 決断より先に出す。
        _screenshotGallery(),
        const SizedBox(height: 24),
        _actionArea(product),
        if (_actionError != null) ...[
          const SizedBox(height: 16),
          _notice(
            icon: Icons.error_outline,
            color: DesignTokens.orange,
            title: 'エラー',
            body: _actionError!,
          ),
        ],
        const SizedBox(height: 32),
        _specs(product),
      ],
    );
  }

  /// スクリーンショット (2026-07-29 追加)。
  ///
  /// 並べる順序が説明そのものになっている。ターン30→150 と進むにつれて
  /// 版図と都市が増えるので、**3枚並べるだけで「育っていくのを見る」という
  /// このゲームの価値が伝わる**。単に綺麗な1枚を出すより強い。
  Widget _screenshotGallery() {
    final selected = _shots[_selectedShot];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.asset(
              selected.asset,
              fit: BoxFit.cover,
              // 読み込み中に高さが 0 へ潰れると、下のボタンが飛び跳ねる。
              // 枠を先に確保しておく (AspectRatio がその役目)。
              errorBuilder: (context, error, stack) => Container(
                color: DesignTokens.surface2,
                alignment: Alignment.center,
                child: const Text(
                  '画像を読み込めませんでした',
                  style: TextStyle(color: DesignTokens.textSecondary),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          selected.captionJa,
          style: const TextStyle(
            color: DesignTokens.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < _shots.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _shotThumbnail(i)),
            ],
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          '同じ世界(seed 42)がターンを追って育っていく様子です。'
          'AI同士の観戦でもこの変化を眺められます。',
          style: TextStyle(
            color: DesignTokens.textSecondary,
            fontSize: 12,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _shotThumbnail(int index) {
    final shot = _shots[index];
    final active = index == _selectedShot;
    return InkWell(
      onTap: () => setState(() => _selectedShot = index),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              // 選択中を枠で示す。押せることが分かる最小の手掛かり。
              decoration: BoxDecoration(
                border: Border.all(
                  color: active ? DesignTokens.orange : DesignTokens.divider,
                  width: active ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  shot.asset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      Container(color: DesignTokens.surface2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            shot.labelJa,
            style: TextStyle(
              color: active ? DesignTokens.orange : DesignTokens.textSecondary,
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(ShopProduct product) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.nameJa,
            style: const TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product.summaryJa,
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '¥${product.priceJpy}',
                style: const TextStyle(
                  color: DesignTokens.orange,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '税込 / 買い切り',
                style: TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionArea(ShopProduct product) {
    if (_purchased) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.purchaseResult == 'success') ...[
            _notice(
              icon: Icons.check_circle_outline,
              color: DesignTokens.green,
              title: 'ご購入ありがとうございます',
              body: '下のボタンからダウンロードできます。購入後は何度でもダウンロードできます。',
            ),
            const SizedBox(height: 16),
          ],
          _primaryButton(
            label: 'ダウンロード',
            icon: Icons.download,
            onPressed: _working ? null : _download,
          ),
          if (_lastTicket != null) ...[
            const SizedBox(height: 12),
            Text(
              'ダウンロードURLの有効期限は約'
              '${(_lastTicket!.expiresInSeconds / 60).round()}分です。'
              '期限が切れたら、もう一度このボタンを押してください。',
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
        ],
      );
    }

    // 決済は終わったが購入行がまだ見えない状態。Stripe の webhook 処理は
    // 数秒遅れることがあり、ここで購入ボタンを出し直すと**二重購入を誘発する**。
    // 反映待ちであることを明示し、再読み込みだけを促す。
    if (widget.purchaseResult == 'success') {
      return _notice(
        icon: Icons.hourglass_top,
        color: DesignTokens.indigo,
        title: '決済を確認しています',
        body: 'お支払いは完了しています。反映まで数秒かかることがあります。'
            'この画面を再読み込みすると、ダウンロードボタンが表示されます。',
        action: TextButton(onPressed: _load, child: const Text('再読み込み')),
      );
    }

    if (!product.isPurchasable) {
      // Price 未設定。押せば必ず失敗するので、購入ボタン自体を出さない。
      return _notice(
        icon: Icons.schedule,
        color: DesignTokens.textSecondary,
        title: '販売準備中です',
        body: '購入の受付開始までもうしばらくお待ちください。',
      );
    }

    if (!_signedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '購入にはログインが必要です。購入履歴とダウンロード権利をアカウントに'
            '紐づけるため、再インストール時も同じアカウントで再ダウンロードできます。',
            style: TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          _primaryButton(
            label: 'ログインして購入',
            icon: Icons.login,
            onPressed: () => Navigator.of(context).pushNamed('/login'),
          ),
        ],
      );
    }

    return _primaryButton(
      label: _working ? '手続き中…' : '¥${product.priceJpy} で購入',
      icon: Icons.shopping_cart_outlined,
      onPressed: _working ? null : _startPurchase,
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: DesignTokens.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _specs(ShopProduct product) {
    final sizeMb = product.fileSizeBytes == null
        ? null
        : (product.fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '製品情報',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _specRow('対応環境', 'Windows 10 / 11 (64bit)'),
          _specRow('バージョン', product.version),
          if (sizeMb != null) _specRow('ダウンロード容量', '約 $sizeMb MB (zip)'),
          _specRow('形式', 'zip 展開後に HexCiv.exe を実行'),
          if (product.sha256.isNotEmpty)
            // 落としたファイルの同一性を購入者自身が確認できるようにする。
            _specRow('SHA256', product.sha256, monospace: true),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value, {bool monospace = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: DesignTokens.textPrimary,
                fontSize: 13,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 8),
                  action,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

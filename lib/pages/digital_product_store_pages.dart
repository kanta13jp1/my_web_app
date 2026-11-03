import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/shop_funnel_service.dart';
import '../services/shop_service.dart';
import '../theme/design_tokens.dart';
import '../view_models/shop_view_models.dart';

typedef ShopUrlLauncher = Future<bool> Function(Uri uri, bool external);

Future<bool> _launchShopUrl(Uri uri, bool external) {
  if (external) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return launchUrl(uri, webOnlyWindowName: '_self');
}

/// 運営者が制作したデジタル商品の公開カタログ。
class DigitalProductStorePage extends StatefulWidget {
  const DigitalProductStorePage({super.key, this.service});

  final ShopGateway? service;

  @override
  State<DigitalProductStorePage> createState() =>
      _DigitalProductStorePageState();
}

class _DigitalProductStorePageState extends State<DigitalProductStorePage> {
  late final ShopCatalogViewModel _viewModel = ShopCatalogViewModel(
    gateway: widget.service ?? ShopService(),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_viewModel.load());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface1,
        foregroundColor: DesignTokens.textPrimary,
        title: const Text('デジタル作品ストア'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/shop/downloads'),
            icon: const Icon(Icons.download_done_outlined),
            label: const Text('購入済み'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _viewModel.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _hero()),
                SliverToBoxAdapter(child: _filters()),
                if (_viewModel.loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_viewModel.error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: _ShopNotice(
                        icon: Icons.error_outline,
                        color: DesignTokens.orange,
                        title: '商品を読み込めませんでした',
                        body: _viewModel.error!,
                        action: TextButton(
                          onPressed: _viewModel.load,
                          child: const Text('再試行'),
                        ),
                      ),
                    ),
                  )
                else if (_viewModel.visibleProducts.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: _ShopNotice(
                        icon: Icons.inventory_2_outlined,
                        color: DesignTokens.textSecondary,
                        title: 'この種別の商品は準備中です',
                        body: '公開された商品がここに表示されます。別の種別もご覧ください。',
                      ),
                    ),
                  )
                else
                  _productGrid(_viewModel.visibleProducts),
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hero() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(20, 40, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'つくる時間を、次の価値へ。',
                style: TextStyle(
                  color: DesignTokens.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '画像・音声・動画・デザイン・文章・プロンプト・アイデア・ゲーム・'
                'テンプレートを、買い切りで安全に購入できます。',
                style: TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 15,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('すべて'),
                selected: _viewModel.selectedType == null,
                onSelected: (_) => _viewModel.selectType(null),
              ),
              const SizedBox(width: 8),
              for (final type in ShopProductType.values) ...[
                ChoiceChip(
                  avatar: Icon(_iconForType(type), size: 17),
                  label: Text(type.labelJa),
                  selected: _viewModel.selectedType == type,
                  onSelected: (_) => _viewModel.selectType(type),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _productGrid(List<ShopProduct> products) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent.clamp(0, 1180).toDouble();
          final horizontalInset = (constraints.crossAxisExtent - width) / 2;
          return SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontalInset),
            sliver: SliverGrid.builder(
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: 350,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                final product = products[index];
                return _ProductCatalogCard(
                  product: product,
                  onOpen: () => Navigator.of(context).pushNamed(
                    '/shop/product?product_id='
                    '${Uri.encodeQueryComponent(product.id)}',
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProductCatalogCard extends StatelessWidget {
  const _ProductCatalogCard({required this.product, required this.onOpen});

  final ShopProduct product;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: DesignTokens.surface1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 132,
              width: double.infinity,
              child: _ProductPreview(product: product),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: _iconForType(product.type),
                          label: product.type.labelJa,
                        ),
                        _MetaChip(
                          icon: Icons.file_present_outlined,
                          label: product.formatLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      product.nameJa,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: DesignTokens.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.summaryJa,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: DesignTokens.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '¥${product.priceJpy}',
                          style: const TextStyle(
                            color: DesignTokens.orange,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '詳細を見る',
                          style: TextStyle(
                            color: DesignTokens.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 任意の商品IDを表示する汎用商品詳細ページ。
class DigitalProductPage extends StatefulWidget {
  const DigitalProductPage({
    super.key,
    required this.productId,
    this.purchaseResult,
    this.service,
    this.funnel,
    this.urlLauncher,
  });

  final String productId;
  final String? purchaseResult;
  final ShopGateway? service;
  final ShopFunnelService? funnel;
  final ShopUrlLauncher? urlLauncher;

  @override
  State<DigitalProductPage> createState() => _DigitalProductPageState();
}

class _ProductScreenshot {
  const _ProductScreenshot({
    required this.asset,
    required this.labelJa,
    required this.captionJa,
  });

  final String asset;
  final String labelJa;
  final String captionJa;
}

const _hexcivScreenshots = <_ProductScreenshot>[
  _ProductScreenshot(
    asset: 'assets/landing_journey/hexciv_turn30.png',
    labelJa: 'ターン30',
    captionJa: '序盤。各文明の小さな領域が点在し、地図の大半には開拓の余地が残っています。',
  ),
  _ProductScreenshot(
    asset: 'assets/landing_journey/hexciv_turn80.png',
    labelJa: 'ターン80',
    captionJa: '中盤。国境が接し、都市と部隊が増えて文明ごとの勢力差が現れます。',
  ),
  _ProductScreenshot(
    asset: 'assets/landing_journey/hexciv_turn150.png',
    labelJa: 'ターン150',
    captionJa: '終盤。広い版図と多数の部隊が並び、序盤からの発展を一望できます。',
  ),
];

class _DigitalProductPageState extends State<DigitalProductPage> {
  late final ShopProductViewModel _viewModel = ShopProductViewModel(
    gateway: widget.service ?? ShopService(),
    productId: widget.productId,
  );
  late final ShopUrlLauncher _urlLauncher =
      widget.urlLauncher ?? _launchShopUrl;
  late final String _source = ShopFunnelService.sourceFromUri(Uri.base);
  late final String _campaign = ShopFunnelService.campaignFromUri(Uri.base);
  int _selectedProductScreenshotIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_viewModel.load());
    _recordFunnel(ShopFunnelService.stageProductView);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _recordFunnel(String stage) {
    final funnel = widget.funnel;
    if (funnel == null) return;
    unawaited(
      funnel.record(
        stage,
        productId: widget.productId,
        source: _source,
        campaign: _campaign,
      ),
    );
  }

  Future<void> _startPurchase() async {
    _recordFunnel(ShopFunnelService.stagePurchaseClick);
    final start = await _viewModel.startCheckout(
      visitorId: await widget.funnel?.visitorId(),
      source: _source,
    );
    if (start == null || start.alreadyPurchased) return;
    _recordFunnel(ShopFunnelService.stageCheckoutRedirect);
    await _urlLauncher(Uri.parse(start.checkoutUrl!), false);
  }

  Future<void> _download() async {
    final ticket = await _viewModel.requestDownload();
    if (ticket == null) return;
    await _urlLauncher(Uri.parse(ticket.url), true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface1,
        foregroundColor: DesignTokens.textPrimary,
        title: const Text('デジタル商品'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/shop'),
            child: const Text('ストア'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/shop/downloads'),
            child: const Text('購入済み'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: _buildBody(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_viewModel.loadError != null) {
      return _ShopNotice(
        icon: Icons.error_outline,
        color: DesignTokens.orange,
        title: '商品情報を読み込めませんでした',
        body: _viewModel.loadError!,
        action: TextButton(
          onPressed: _viewModel.load,
          child: const Text('再試行'),
        ),
      );
    }
    final product = _viewModel.product;
    if (product == null) {
      return const _ShopNotice(
        icon: Icons.schedule,
        color: DesignTokens.textSecondary,
        title: '準備中です',
        body: 'この商品は現在公開されていません。ストアから販売中の商品をご覧ください。',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.purchaseResult == 'canceled') ...[
          const _ShopNotice(
            icon: Icons.info_outline,
            color: DesignTokens.textSecondary,
            title: '購入は完了していません',
            body: '購入手続きが中断されました。もう一度お試しいただけます。',
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final preview = _ProductPreview(product: product);
            final information = _productInformation(product);
            if (constraints.maxWidth >= 760) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, height: 300, child: preview),
                  const SizedBox(width: 28),
                  Expanded(child: information),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 240, child: preview),
                const SizedBox(height: 20),
                information,
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        if (product.id == ShopService.hexcivProductId) ...[
          _productScreenshotGallery(),
          const SizedBox(height: 24),
        ],
        _actionArea(product),
        if (_viewModel.actionError != null) ...[
          const SizedBox(height: 16),
          _ShopNotice(
            icon: Icons.error_outline,
            color: DesignTokens.orange,
            title: 'エラー',
            body: _viewModel.actionError!,
          ),
        ],
        const SizedBox(height: 32),
        _specs(product),
      ],
    );
  }

  Widget _productInformation(ShopProduct product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetaChip(
              icon: _iconForType(product.type),
              label: product.type.labelJa,
            ),
            _MetaChip(
              icon: Icons.file_present_outlined,
              label: product.formatLabel,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          product.nameJa,
          style: const TextStyle(
            color: DesignTokens.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          product.effectiveDescription,
          style: const TextStyle(
            color: DesignTokens.textSecondary,
            fontSize: 14,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 24),
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
              style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _productScreenshotGallery() {
    final selected = _hexcivScreenshots[_selectedProductScreenshotIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ゲーム画面',
          style: TextStyle(
            color: DesignTokens.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: DesignTokens.surface2,
              child: Image.asset(
                selected.asset,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text(
                    '画像を読み込めませんでした',
                    style: TextStyle(color: DesignTokens.textSecondary),
                  ),
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
            for (var index = 0; index < _hexcivScreenshots.length; index++) ...[
              if (index > 0) const SizedBox(width: 10),
              Expanded(child: _productScreenshotThumbnail(index)),
            ],
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          '同じ世界（seed 42）がターンを追って発展する様子です。観戦モードでも変化を楽しめます。',
          style: TextStyle(
            color: DesignTokens.textSecondary,
            fontSize: 12,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _productScreenshotThumbnail(int index) {
    final screenshot = _hexcivScreenshots[index];
    final selected = index == _selectedProductScreenshotIndex;
    return Semantics(
      button: true,
      selected: selected,
      label: '${screenshot.labelJa}のスクリーンショットを表示',
      child: InkWell(
        onTap: () => setState(() => _selectedProductScreenshotIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: DesignTokens.surface2,
                    border: Border.all(
                      color:
                          selected ? DesignTokens.orange : DesignTokens.divider,
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    screenshot.asset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              screenshot.labelJa,
              style: TextStyle(
                color:
                    selected ? DesignTokens.orange : DesignTokens.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionArea(ShopProduct product) {
    if (_viewModel.purchased) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.purchaseResult == 'success') ...[
            const _ShopNotice(
              icon: Icons.check_circle_outline,
              color: DesignTokens.green,
              title: 'ご購入ありがとうございます',
              body: '購入後は同じアカウントから何度でも再ダウンロードできます。',
            ),
            const SizedBox(height: 16),
          ],
          _PrimaryShopButton(
            label: _viewModel.working ? '準備中…' : 'ダウンロード',
            icon: Icons.download,
            onPressed: _viewModel.working ? null : _download,
          ),
          if (_viewModel.lastTicket != null) ...[
            const SizedBox(height: 12),
            Text(
              'リンクの有効期限は約'
              '${(_viewModel.lastTicket!.expiresInSeconds / 60).round()}分です。'
              '期限が切れた場合は、もう一度ダウンロードしてください。',
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

    if (widget.purchaseResult == 'success') {
      return _ShopNotice(
        icon: Icons.hourglass_top,
        color: DesignTokens.indigo,
        title: '決済を確認しています',
        body: 'お支払いは完了しています。反映まで数秒かかることがあります。'
            '購入ボタンは再表示せず、確認後にダウンロードへ切り替えます。',
        action: TextButton(
          onPressed: _viewModel.load,
          child: const Text('再読み込み'),
        ),
      );
    }

    if (!product.isPurchasable) {
      return const _ShopNotice(
        icon: Icons.schedule,
        color: DesignTokens.textSecondary,
        title: '販売準備中です',
        body: 'Stripeの価格と配信ファイルを準備しています。受付開始までお待ちください。',
      );
    }

    if (!_viewModel.isSignedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '購入履歴とダウンロード権利をアカウントに紐づけるため、購入にはログインが必要です。',
            style: TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryShopButton(
            label: 'ログインして購入',
            icon: Icons.login,
            onPressed: () => Navigator.of(context).pushNamed('/login'),
          ),
        ],
      );
    }

    return _PrimaryShopButton(
      label: _viewModel.working ? '手続き中…' : '¥${product.priceJpy} で購入',
      icon: Icons.shopping_cart_outlined,
      onPressed: _viewModel.working ? null : _startPurchase,
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
            '商品情報',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _SpecRow(label: '種別', value: product.type.labelJa),
          _SpecRow(label: '形式', value: product.formatLabel),
          _SpecRow(label: '利用環境', value: product.requirementsJa),
          _SpecRow(label: 'バージョン', value: product.version),
          if (sizeMb != null) _SpecRow(label: '容量', value: '約 $sizeMb MB'),
          _SpecRow(label: 'ライセンス', value: product.licenseSummaryJa),
          if (product.sha256.isNotEmpty)
            _SpecRow(label: 'SHA256', value: product.sha256, monospace: true),
        ],
      ),
    );
  }
}

/// ログイン中の利用者が購入済みの商品だけを見るライブラリ。
class ShopDownloadsPage extends StatefulWidget {
  const ShopDownloadsPage({super.key, this.service, this.urlLauncher});

  final ShopGateway? service;
  final ShopUrlLauncher? urlLauncher;

  @override
  State<ShopDownloadsPage> createState() => _ShopDownloadsPageState();
}

class _ShopDownloadsPageState extends State<ShopDownloadsPage> {
  late final ShopDownloadsViewModel _viewModel = ShopDownloadsViewModel(
    gateway: widget.service ?? ShopService(),
  );
  late final ShopUrlLauncher _urlLauncher =
      widget.urlLauncher ?? _launchShopUrl;

  @override
  void initState() {
    super.initState();
    unawaited(_viewModel.load());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _download(String productId) async {
    final ticket = await _viewModel.requestDownload(productId);
    if (ticket == null) return;
    await _urlLauncher(Uri.parse(ticket.url), true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface1,
        foregroundColor: DesignTokens.textPrimary,
        title: const Text('購入済みの商品'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/shop'),
            child: const Text('ストアを見る'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (!_viewModel.isSignedIn) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _ShopNotice(
                  icon: Icons.login,
                  color: DesignTokens.indigo,
                  title: 'ログインが必要です',
                  body: '購入時と同じアカウントでログインすると、購入済み商品を再ダウンロードできます。',
                  action: TextButton(
                    onPressed: () => Navigator.of(context).pushNamed('/login'),
                    child: const Text('ログイン'),
                  ),
                ),
              ),
            );
          }
          if (_viewModel.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_viewModel.error != null) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _ShopNotice(
                  icon: Icons.error_outline,
                  color: DesignTokens.orange,
                  title: '購入済み商品を読み込めませんでした',
                  body: _viewModel.error!,
                  action: TextButton(
                    onPressed: _viewModel.load,
                    child: const Text('再試行'),
                  ),
                ),
              ),
            );
          }
          if (_viewModel.purchases.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _ShopNotice(
                  icon: Icons.inventory_2_outlined,
                  color: DesignTokens.textSecondary,
                  title: '購入済みの商品はまだありません',
                  body: 'ストアで商品を購入すると、ここから何度でも再ダウンロードできます。',
                  action: TextButton(
                    onPressed: () => Navigator.of(context).pushNamed('/shop'),
                    child: const Text('ストアを見る'),
                  ),
                ),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _viewModel.purchases.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final purchase = _viewModel.purchases[index];
                  final product = purchase.product;
                  final working = _viewModel.workingProductId == product.id;
                  return Card(
                    color: DesignTokens.surface1,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final details = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _MetaChip(
                                icon: _iconForType(product.type),
                                label: product.type.labelJa,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                product.nameJa,
                                style: const TextStyle(
                                  color: DesignTokens.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${product.formatLabel} ・ v${product.version}',
                                style: const TextStyle(
                                  color: DesignTokens.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          );
                          final button = FilledButton.icon(
                            onPressed:
                                working ? null : () => _download(product.id),
                            icon: const Icon(Icons.download),
                            label: Text(working ? '準備中…' : 'ダウンロード'),
                          );
                          if (constraints.maxWidth >= 620) {
                            return Row(
                              children: [
                                Expanded(child: details),
                                const SizedBox(width: 20),
                                button,
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              details,
                              const SizedBox(height: 16),
                              button,
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductPreview extends StatelessWidget {
  const _ProductPreview({required this.product});

  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    final previewUrl = product.previewImageUrl;
    if (previewUrl != null && previewUrl.isNotEmpty) {
      return Image.network(
        previewUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DesignTokens.indigo.withValues(alpha: 0.55),
            DesignTokens.orange.withValues(alpha: 0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _iconForType(product.type),
          size: 64,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: DesignTokens.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DesignTokens.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryShopButton extends StatelessWidget {
  const _PrimaryShopButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
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
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final valueWidget = SelectableText(
            value,
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 13,
              fontFamily: monospace ? 'monospace' : null,
              height: 1.5,
            ),
          );
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                valueWidget,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _ShopNotice extends StatelessWidget {
  const _ShopNotice({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
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
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForType(ShopProductType type) {
  return switch (type) {
    ShopProductType.image => Icons.image_outlined,
    ShopProductType.audio => Icons.graphic_eq,
    ShopProductType.video => Icons.movie_outlined,
    ShopProductType.design => Icons.palette_outlined,
    ShopProductType.writing => Icons.article_outlined,
    ShopProductType.prompt => Icons.auto_awesome_outlined,
    ShopProductType.idea => Icons.lightbulb_outline,
    ShopProductType.game => Icons.sports_esports_outlined,
    ShopProductType.application => Icons.grid_on_outlined,
    ShopProductType.template => Icons.dashboard_customize_outlined,
  };
}

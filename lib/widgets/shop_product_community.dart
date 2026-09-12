import 'dart:async';

import 'package:flutter/material.dart';

import '../models/shop_community.dart';
import '../services/shop_community_repository.dart';
import '../services/shop_service.dart';
import '../theme/design_tokens.dart';
import '../view_models/shop_community_view_model.dart';

class ShopProductCommunity extends StatefulWidget {
  const ShopProductCommunity({
    super.key,
    required this.product,
    required this.repository,
    this.historyKey,
    this.reviewsKey,
  });

  final ShopProduct product;
  final ShopCommunityRepository repository;
  final Key? historyKey;
  final Key? reviewsKey;

  @override
  State<ShopProductCommunity> createState() => _ShopProductCommunityState();
}

class _ShopProductCommunityState extends State<ShopProductCommunity> {
  late final ShopCommunityViewModel _model = ShopCommunityViewModel(
    productId: widget.product.id,
    repository: widget.repository,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_model.load());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _editReview() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReviewEditor(model: _model),
    );
  }

  Future<void> _deleteReview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自分の口コミ・評価を削除しますか？'),
        content: const Text('公開中の星評価と口コミを削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _model.delete();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _model,
        builder: (context, _) => DefaultTextStyle.merge(
          style: const TextStyle(color: DesignTokens.textPrimary, height: 1.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_model.loading) const LinearProgressIndicator(),
              _section(
                key: widget.historyKey,
                title: '更新情報・アプリケーションバージョン',
                children: [
                  Text(
                    '現在の配布版：${widget.product.version.isEmpty ? '未登録' : 'v${widget.product.version}'}',
                  ),
                  const Text(
                    'サイト上部のバージョン番号とは別の、ダウンロード商品の版です。',
                    style: TextStyle(color: DesignTokens.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (_model.releaseError != null)
                    _message(_model.releaseError!)
                  else if (!_model.loading && _model.releases.isEmpty)
                    const Text('公開済みの更新情報はまだ登録されていません。')
                  else
                    for (final release in _model.releases)
                      _releaseTile(release),
                  if (_model.releases.length >= 20)
                    const Text('直近20件の更新情報を表示しています。'),
                ],
              ),
              const SizedBox(height: 24),
              _section(
                key: widget.reviewsKey,
                title: '口コミ・評価',
                children: [
                  if (_model.reviewError != null)
                    _message(_model.reviewError!)
                  else if (_model.page != null) ...[
                    _reviewSummary(_model.page!),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _model.page!.items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: DesignTokens.divider),
                      itemBuilder: (_, index) =>
                          _reviewTile(_model.page!.items[index]),
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (_model.pageNumber > 1)
                          TextButton(
                            onPressed: _model.loading ||
                                    _model.paging ||
                                    _model.working
                                ? null
                                : _model.load,
                            child: const Text('最新の口コミへ戻る'),
                          ),
                        if (_model.page!.hasMore)
                          TextButton(
                            onPressed: _model.paging || _model.working
                                ? null
                                : _model.nextPage,
                            child: Text(_model.paging ? '読み込み中…' : '次の10件'),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ownReviewControls(),
                  if (_model.notice != null) _message(_model.notice!),
                  if (_model.actionError != null) _message(_model.actionError!),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _model.loading || _model.working || _model.paging
                      ? null
                      : _model.load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('更新情報と口コミを再読み込み'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _section({
    Key? key,
    required String title,
    required List<Widget> children,
  }) =>
      Container(
        key: key,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DesignTokens.surface1,
          border: Border.all(color: DesignTokens.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );

  Widget _message(String message) => Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(message),
        ),
      );

  Widget _releaseTile(ShopProductRelease release) {
    final current = widget.product.sha256.isNotEmpty &&
        release.sha256 == widget.product.sha256;
    return ExpansionTile(
      textColor: DesignTokens.textPrimary,
      collapsedTextColor: DesignTokens.textPrimary,
      iconColor: DesignTokens.textSecondary,
      collapsedIconColor: DesignTokens.textSecondary,
      initiallyExpanded: current,
      title: Text('v${release.version} — ${release.title}'),
      subtitle: Text(
        '${current ? '現在の配布内容 ・ ' : ''}公開日：${release.publishedAt == null ? '未記録' : _date(release.publishedAt!)}',
        style: const TextStyle(color: DesignTokens.textSecondary),
      ),
      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(release.notes),
        ),
      ],
    );
  }

  Widget _reviewSummary(ShopReviewPage page) {
    if (page.count == 0) return const Text('評価はまだありません（0件）');
    return Semantics(
      label: '平均評価 ${page.average!.toStringAsFixed(1)}、5点満点、${page.count}件',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.star, color: DesignTokens.orange),
            Text(
              '${page.average!.toStringAsFixed(1)} / 5',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text('公開評価 ${page.count}件'),
          ],
        ),
      ),
    );
  }

  Widget _reviewTile(ShopReview review) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('★ ${review.rating} / 5　購入者の口コミ'),
            if (review.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(review.body),
            ],
            const SizedBox(height: 8),
            Text(
              '${_date(review.updatedAt)}${review.postedVersion.isEmpty ? '' : ' ・ 投稿時の配布版 v${review.postedVersion}'}',
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );

  Widget _ownReviewControls() {
    if (_model.loading) return const Text('投稿状況を確認しています…');
    if (!_model.signedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('口コミ・評価の登録には、ログインと商品の購入が必要です。'),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/login'),
            child: const Text('ログイン'),
          ),
        ],
      );
    }
    if (_model.ownerError != null) return _message(_model.ownerError!);
    final own = _model.own.review;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (own != null) Text('あなたの評価：★ ${own.rating} / 5'),
        if (own != null && !own.isVisible) const Text('あなたの口コミは現在、公開されていません。'),
        if (!_model.canReview) const Text('購入が確認できたアカウントから口コミ・評価を登録できます。'),
        const Text(
          '1商品につき1件。投稿内容は公開されます。個人情報を含めないでください。',
          style: TextStyle(color: DesignTokens.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (_model.canReview)
              FilledButton.icon(
                onPressed: _model.working ? null : _editReview,
                icon: const Icon(Icons.rate_review_outlined),
                label: Text(own == null ? '口コミ・評価を書く' : '自分の口コミを編集'),
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.orange,
                  foregroundColor: DesignTokens.background,
                ),
              ),
            if (own != null)
              OutlinedButton(
                onPressed: _model.working ? null : _deleteReview,
                child: const Text('自分の口コミを削除'),
              ),
          ],
        ),
      ],
    );
  }
}

String _date(DateTime date) {
  final local = date.toLocal();
  return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
}

class _ReviewEditor extends StatefulWidget {
  const _ReviewEditor({required this.model});
  final ShopCommunityViewModel model;
  @override
  State<_ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends State<_ReviewEditor> {
  late final int _sessionRevision = widget.model.sessionRevision;
  late int _rating = widget.model.own.review?.rating ?? 0;
  late final TextEditingController _body =
      TextEditingController(text: widget.model.own.review?.body ?? '');
  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.model,
        builder: (context, _) => _sessionRevision !=
                widget.model.sessionRevision
            ? AlertDialog(
                title: const Text('ログイン状態が変わりました'),
                content: const Text(
                  '現在のアカウントで開き直してください。送信中だった場合は、再読み込みして保存状況をご確認ください。',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('閉じる'),
                  ),
                ],
              )
            : PopScope(
                canPop: !widget.model.working,
                child: AlertDialog(
                  backgroundColor: DesignTokens.surface1,
                  title: const Text(
                    '口コミ・評価を登録',
                    style: TextStyle(color: DesignTokens.textPrimary),
                  ),
                  content: SizedBox(
                    width: 480,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '星を1〜5で選んでください',
                            style: TextStyle(color: DesignTokens.textPrimary),
                          ),
                          Wrap(
                            children: [
                              for (var value = 1; value <= 5; value++)
                                IconButton(
                                  key: ValueKey('review-star-$value'),
                                  tooltip: '星$valueを選択',
                                  isSelected: _rating == value,
                                  onPressed: widget.model.working
                                      ? null
                                      : () => setState(() => _rating = value),
                                  icon: Icon(
                                    value <= _rating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: DesignTokens.orange,
                                  ),
                                ),
                            ],
                          ),
                          TextField(
                            key: const ValueKey('review-body'),
                            controller: _body,
                            enabled: !widget.model.working,
                            minLines: 3,
                            maxLines: 8,
                            maxLength: 2000,
                            style: const TextStyle(
                              color: DesignTokens.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              labelText: '口コミ（任意）',
                              labelStyle:
                                  TextStyle(color: DesignTokens.textSecondary),
                              counterStyle:
                                  TextStyle(color: DesignTokens.textSecondary),
                            ),
                          ),
                          const Text(
                            '投稿内容は公開されます。氏名・メールアドレス等の個人情報は記載しないでください。',
                            style: TextStyle(
                              color: DesignTokens.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (widget.model.actionError != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                widget.model.actionError!,
                                style: const TextStyle(
                                  color: DesignTokens.textPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: widget.model.working
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                    FilledButton(
                      onPressed: widget.model.working || _rating == 0
                          ? null
                          : () async {
                              final saved =
                                  await widget.model.save(_rating, _body.text);
                              if (saved && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignTokens.orange,
                        foregroundColor: DesignTokens.background,
                      ),
                      child: Text(widget.model.working ? '保存中…' : '公開して保存'),
                    ),
                  ],
                ),
              ),
      );
}

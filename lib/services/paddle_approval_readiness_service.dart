import 'package:flutter/material.dart';

enum PaddleApprovalSectionKind {
  refundPolicy,
  legalEntity,
  productDescription,
  checkoutReadiness,
  hiddenReviewFactors,
}

class PaddleApprovalChecklistItem {
  const PaddleApprovalChecklistItem({
    required this.label,
    required this.detail,
    this.critical = false,
    this.hiddenReviewFactor = false,
  });

  final String label;
  final String detail;
  final bool critical;
  final bool hiddenReviewFactor;
}

class PaddleApprovalSection {
  const PaddleApprovalSection({
    required this.kind,
    required this.title,
    required this.description,
    required this.items,
  });

  final PaddleApprovalSectionKind kind;
  final String title;
  final String description;
  final List<PaddleApprovalChecklistItem> items;
}

class PaddleApprovalReadinessReport {
  const PaddleApprovalReadinessReport({
    required this.sections,
    required this.totalItems,
    required this.criticalItems,
    required this.hiddenItems,
    required this.primaryActions,
    required this.regulatedDataWarning,
    required this.summary,
  });

  final List<PaddleApprovalSection> sections;
  final int totalItems;
  final int criticalItems;
  final int hiddenItems;
  final List<String> primaryActions;
  final String? regulatedDataWarning;
  final String summary;
}

class PaddleApprovalReadinessService {
  const PaddleApprovalReadinessService();

  PaddleApprovalReadinessReport buildReport({
    bool touchesRegulatedData = false,
  }) {
    const sections = <PaddleApprovalSection>[
      PaddleApprovalSection(
        kind: PaddleApprovalSectionKind.refundPolicy,
        title: '返金ポリシー',
        description:
            'Paddle は merchant of record なので、返金条件に例外や注釈が多いと審査で止まりやすいです。',
        items: [
          PaddleApprovalChecklistItem(
            label: '返金条件に例外を入れない',
            detail: 'except for や processing fee を差し引く表現は避ける。',
            critical: true,
          ),
          PaddleApprovalChecklistItem(
            label: '14日または30日の明確な返金期限',
            detail: '購入後いつまで返金可能かを数値で明示する。',
            critical: true,
          ),
          PaddleApprovalChecklistItem(
            label: '連絡先メールを本文に明記',
            detail: 'support 用メールアドレスを返金ポリシー本文に含める。',
            critical: true,
          ),
          PaddleApprovalChecklistItem(
            label: 'Paddle 標準寄りの無条件返金文言',
            detail: 'No questions asked に近い、条件なしの保証へ寄せる。',
            critical: true,
          ),
        ],
      ),
      PaddleApprovalSection(
        kind: PaddleApprovalSectionKind.legalEntity,
        title: '法的主体',
        description: 'サイト上の事業者情報と Paddle アカウント登録主体が 1 文字単位で一致している必要があります。',
        items: [
          PaddleApprovalChecklistItem(
            label: '利用規約の事業者名が Paddle 登録名と完全一致',
            detail: 'テンプレートの会社名残りや略称差異を残さない。',
            critical: true,
          ),
          PaddleApprovalChecklistItem(
            label: '事業者住所を公開',
            detail: '登録済みの事業住所をフッターや法務ページに表示する。',
            critical: true,
          ),
          PaddleApprovalChecklistItem(
            label: 'VAT ID を必要に応じて表示',
            detail: 'EU 対象なら VAT 番号が見える状態にする。',
            critical: true,
          ),
        ],
      ),
      PaddleApprovalSection(
        kind: PaddleApprovalSectionKind.productDescription,
        title: '販売対象の説明',
        description:
            '何がソフトウェアで、何が人手サービスかを曖昧にすると SaaS ではなく consulting と解釈されやすいです。',
        items: [
          PaddleApprovalChecklistItem(
            label: 'デジタル提供物と人手提供物を切り分ける',
            detail: 'AI/自動処理が主で、人手レビューが補助ならその順で書く。',
            critical: true,
          ),
          PaddleApprovalChecklistItem(
            label: '月額・年額・自動更新を明記',
            detail: 'subscription terms を料金表や checkout 前に見える化する。',
            critical: true,
          ),
          PaddleApprovalChecklistItem(
            label: '解約手順を明記',
            detail: 'self-serve でどこから解約できるかを書く。',
            critical: true,
          ),
          PaddleApprovalChecklistItem(
            label: '解約後のデータ扱いを明記',
            detail: '削除、保持期間、エクスポート可否を説明する。',
            critical: true,
          ),
        ],
      ),
      PaddleApprovalSection(
        kind: PaddleApprovalSectionKind.checkoutReadiness,
        title: 'Checkout readiness',
        description: 'コード自体より、審査時に動く checkout 導線と webhook の受け口が見えることが重要です。',
        items: [
          PaddleApprovalChecklistItem(
            label: 'Paddle.js を sandbox で通している',
            detail: '審査時に checkout の起動確認ができる状態にする。',
            critical: true,
          ),
          PaddleApprovalChecklistItem(
            label: 'Webhook endpoint が到達可能',
            detail: 'Paddle 側の疎通確認で 404 や private URL を返さない。',
            critical: true,
          ),
          PaddleApprovalChecklistItem(
            label: 'Webhook の idempotency を実装',
            detail: 'retry を前提に同一イベント再処理で壊れないようにする。',
            critical: true,
          ),
          PaddleApprovalChecklistItem(
            label: '成功時の return URL が動作する',
            detail: 'checkout 後に戻る先が壊れていないか確認する。',
            critical: true,
          ),
        ],
      ),
      PaddleApprovalSection(
        kind: PaddleApprovalSectionKind.hiddenReviewFactors,
        title: 'Docs外の審査ポイント',
        description: '記事で実際に遅延原因になった、公開面の説明不足をここで潰します。',
        items: [
          PaddleApprovalChecklistItem(
            label: '人手サービスがあるなら明示',
            detail: 'support tier か consulting かを曖昧にしない。',
            hiddenReviewFactor: true,
          ),
          PaddleApprovalChecklistItem(
            label: '割引・プロモ条件を書く',
            detail: 'promo を出すなら適用条件と終了条件を説明する。',
            hiddenReviewFactor: true,
          ),
          PaddleApprovalChecklistItem(
            label: '個人事業主ならその旨を明示',
            detail: 'company と個人名義のズレを残さない。',
            hiddenReviewFactor: true,
          ),
          PaddleApprovalChecklistItem(
            label: 'PII / 健康 / 金融データの扱いを説明',
            detail: 'regulated data に触れるプロダクトは追加審査を前提にする。',
            hiddenReviewFactor: true,
          ),
        ],
      ),
    ];

    final totalItems = sections.fold<int>(
      0,
      (sum, section) => sum + section.items.length,
    );
    final criticalItems = sections.fold<int>(
      0,
      (sum, section) =>
          sum + section.items.where((item) => item.critical).length,
    );
    final hiddenItems = sections.fold<int>(
      0,
      (sum, section) =>
          sum + section.items.where((item) => item.hiddenReviewFactor).length,
    );

    final regulatedDataWarning = touchesRegulatedData
        ? 'このプロジェクトは個人情報・健康・金融系の機能を含むため、Paddle 審査でも追加説明を求められる前提で準備した方が安全です。'
        : null;

    return PaddleApprovalReadinessReport(
      sections: sections,
      totalItems: totalItems,
      criticalItems: criticalItems,
      hiddenItems: hiddenItems,
      primaryActions: const [
        '無条件返金ポリシーを support 連絡先つきで公開する',
        '利用規約・住所・VAT を Paddle 登録主体と完全一致させる',
        'SaaS と人手サポートの境界、解約手順、解約後データを料金ページで明示する',
      ],
      regulatedDataWarning: regulatedDataWarning,
      summary:
          'Paddle 審査は webhook 実装そのものより、返金条件・法的主体・販売説明の公開面で落ちやすい、という実務知見を反映したチェックです。',
    );
  }
}

IconData paddleApprovalIconFor(PaddleApprovalSectionKind kind) {
  return switch (kind) {
    PaddleApprovalSectionKind.refundPolicy =>
      Icons.replay_circle_filled_outlined,
    PaddleApprovalSectionKind.legalEntity => Icons.business_outlined,
    PaddleApprovalSectionKind.productDescription => Icons.inventory_2_outlined,
    PaddleApprovalSectionKind.checkoutReadiness => Icons.shopping_cart_checkout,
    PaddleApprovalSectionKind.hiddenReviewFactors => Icons.visibility_outlined,
  };
}

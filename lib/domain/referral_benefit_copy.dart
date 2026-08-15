/// User-facing give-get terms shared by the referral page and share surfaces.
abstract final class ReferralBenefitCopy {
  static const headline = '招待した人も、招待された人もPro特典';

  static const detail =
      '友達のPro課金が成立すると、2人のStripe請求残高へPro月額1か月分のクレジットを付与し、次回請求に自動充当します。登録だけでは付与されません。';

  static const shareSummary =
      '招待リンクから登録してProを始めると、招待した人・された人の両方にPro月額1か月分のクレジット。';

  static String buildShareText(
    String inviteUrl, {
    bool includeHashtags = false,
  }) {
    final hashtags =
        includeHashtags ? '\n\n#buildinpublic #FlutterWeb #自分株式会社' : '';
    return '自分株式会社を一緒に試してみませんか？\n\n'
        '$shareSummary\n\n'
        '招待リンク:\n${inviteUrl.trim()}$hashtags';
  }
}

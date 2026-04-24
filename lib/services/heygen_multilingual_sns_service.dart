class HeyGenSnsVariant {
  const HeyGenSnsVariant({
    required this.localeCode,
    required this.localeLabel,
    required this.audienceHook,
    required this.videoScript,
    required this.xPost,
    required this.linkedinPost,
    required this.shortTitle,
    required this.heygenBrief,
    required this.hashtags,
  });

  final String localeCode;
  final String localeLabel;
  final String audienceHook;
  final List<String> videoScript;
  final String xPost;
  final String linkedinPost;
  final String shortTitle;
  final String heygenBrief;
  final List<String> hashtags;

  String get clipboardBundle => [
        '[$localeLabel] HeyGen brief',
        heygenBrief,
        '',
        'Video script',
        ...videoScript.map((line) => '- $line'),
        '',
        'X post',
        xPost,
        '',
        'LinkedIn post',
        linkedinPost,
      ].join('\n');
}

class HeyGenMultilingualSnsKit {
  const HeyGenMultilingualSnsKit({
    required this.templateKey,
    required this.sourceLanguage,
    required this.sourceSummary,
    required this.variants,
  });

  final String templateKey;
  final String sourceLanguage;
  final String sourceSummary;
  final List<HeyGenSnsVariant> variants;

  String get allPostsForClipboard => variants
      .map(
        (variant) => [
          '## ${variant.localeLabel}',
          variant.xPost,
          '',
          variant.heygenBrief,
        ].join('\n'),
      )
      .join('\n\n');
}

class HeyGenMultilingualSnsService {
  static const String defaultLandingUrl = 'https://my-web-app-b67f4.web.app/';

  static HeyGenMultilingualSnsKit buildKit({
    required String templateKey,
    required String sourceLanguage,
    required String caption,
    required List<String> script,
    String landingUrl = defaultLandingUrl,
  }) {
    final theme = _campaignTheme(templateKey);
    final sourceSummary = _summarizeSource(caption, script, theme);
    final variants = _localeProfiles
        .map(
          (profile) => _buildVariant(
            profile: profile,
            theme: theme,
            sourceSummary: sourceSummary,
            landingUrl: landingUrl,
          ),
        )
        .toList(growable: false);

    return HeyGenMultilingualSnsKit(
      templateKey: templateKey,
      sourceLanguage: sourceLanguage,
      sourceSummary: sourceSummary,
      variants: variants,
    );
  }

  static HeyGenSnsVariant _buildVariant({
    required _LocaleProfile profile,
    required _CampaignTheme theme,
    required String sourceSummary,
    required String landingUrl,
  }) {
    final script = profile.scriptFor(theme, sourceSummary);
    final hashtags = profile.hashtags;
    final xPost = _clipSocial(
      profile.xPostFor(theme, landingUrl, hashtags),
      maxChars: 280,
    );
    final linkedinPost = profile.linkedinPostFor(theme, landingUrl);
    return HeyGenSnsVariant(
      localeCode: profile.code,
      localeLabel: profile.label,
      audienceHook: profile.audienceHookFor(theme),
      videoScript: script,
      xPost: xPost,
      linkedinPost: linkedinPost,
      shortTitle: profile.shortTitleFor(theme),
      heygenBrief: profile.heygenBriefFor(theme, sourceSummary),
      hashtags: hashtags,
    );
  }

  static String _summarizeSource(
    String caption,
    List<String> script,
    _CampaignTheme theme,
  ) {
    final joined = [
      caption,
      ...script,
    ].where((part) => part.trim().isNotEmpty).join(' ');
    if (joined.trim().isEmpty) return theme.jaValue;
    final normalized = joined.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 120) return normalized;
    return '${normalized.substring(0, 120)}...';
  }

  static String _clipSocial(String text, {required int maxChars}) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars - 3)}...';
  }

  static _CampaignTheme _campaignTheme(String templateKey) {
    switch (templateKey) {
      case 'competitor_comparison':
        return const _CampaignTheme(
          key: 'competitor_comparison',
          jaTitle: '競合比較',
          enTitle: 'Competitor comparison',
          jaValue: '複数ツールの費用と認知コストを1つの生活OSへ統合する',
          enValue: 'Replace fragmented tools with one life-management OS',
        );
      case 'feature_highlight':
        return const _CampaignTheme(
          key: 'feature_highlight',
          jaTitle: '機能ハイライト',
          enTitle: 'Feature highlight',
          jaValue: '時間・お金・健康・集中力を一画面で守る',
          enValue: 'Protect time, money, health, and focus in one screen',
        );
      case 'user_growth':
        return const _CampaignTheme(
          key: 'user_growth',
          jaTitle: '成長ストーリー',
          enTitle: 'Builder growth story',
          jaValue: '毎日の改善を積み上げる個人開発ストーリー',
          enValue: 'A solo builder story powered by daily improvement',
        );
      case 'dark_war':
      default:
        return const _CampaignTheme(
          key: 'dark_war',
          jaTitle: 'Dark War広告',
          enTitle: 'Dark War campaign',
          jaValue: '浪費アプリに奪われる時間とお金を取り戻す',
          enValue: 'Win back time and money from wasteful app sprawl',
        );
    }
  }

  static const List<_LocaleProfile> _localeProfiles = [
    _LocaleProfile(
      code: 'ja',
      label: '日本語',
      hashtags: ['#自分株式会社', '#ライフマネジメント', '#AI活用'],
    ),
    _LocaleProfile(
      code: 'en',
      label: 'English',
      hashtags: ['#LifeManagement', '#AIProductivity', '#BuildInPublic'],
    ),
    _LocaleProfile(
      code: 'ko',
      label: '한국어',
      hashtags: ['#라이프매니지먼트', '#AI생산성', '#개인성장'],
    ),
    _LocaleProfile(
      code: 'zh',
      label: '中文',
      hashtags: ['#生活管理', '#AI效率', '#个人成长'],
    ),
    _LocaleProfile(
      code: 'es',
      label: 'Español',
      hashtags: ['#GestionPersonal', '#ProductividadAI', '#Crecimiento'],
    ),
  ];
}

class _CampaignTheme {
  const _CampaignTheme({
    required this.key,
    required this.jaTitle,
    required this.enTitle,
    required this.jaValue,
    required this.enValue,
  });

  final String key;
  final String jaTitle;
  final String enTitle;
  final String jaValue;
  final String enValue;
}

class _LocaleProfile {
  const _LocaleProfile({
    required this.code,
    required this.label,
    required this.hashtags,
  });

  final String code;
  final String label;
  final List<String> hashtags;

  String audienceHookFor(_CampaignTheme theme) {
    switch (code) {
      case 'ja':
        return '日本の個人開発者・学習者・生活改善層向け';
      case 'en':
        return 'For solo builders and people reducing tool sprawl';
      case 'ko':
        return '도구 피로를 줄이고 싶은 1인 창업자와 학습자용';
      case 'zh':
        return '面向想减少工具分散和时间浪费的个人用户';
      case 'es':
        return 'Para creadores que quieren reducir herramientas y distraccion';
      default:
        return theme.enTitle;
    }
  }

  String shortTitleFor(_CampaignTheme theme) {
    switch (code) {
      case 'ja':
        return '${theme.jaTitle} 30秒版';
      case 'en':
        return '${theme.enTitle}: 30-second cut';
      case 'ko':
        return '${theme.enTitle}: 30초 버전';
      case 'zh':
        return '${theme.enTitle}: 30秒版本';
      case 'es':
        return '${theme.enTitle}: version de 30 segundos';
      default:
        return theme.enTitle;
    }
  }

  List<String> scriptFor(_CampaignTheme theme, String sourceSummary) {
    switch (code) {
      case 'ja':
        return [
          'あなたの時間とお金を奪う分散ツールを、今日で見直す。',
          theme.jaValue,
          '自分株式会社で、浪費を減らし、伸びる行動に集中する。',
        ];
      case 'en':
        return [
          'Too many apps are draining your time, money, and attention.',
          theme.enValue,
          'Me Inc. helps you focus on the habits that actually compound.',
        ];
      case 'ko':
        return [
          '너무 많은 앱이 시간과 돈, 집중력을 빼앗고 있습니다.',
          '하나의 생활 OS로 낭비를 줄이고 중요한 행동에 집중하세요.',
          'Me Inc.와 함께 매일 더 나은 선택을 쌓아가세요.',
        ];
      case 'zh':
        return [
          '太多工具正在消耗你的时间、金钱和注意力。',
          '把生活管理集中到一个系统里，减少浪费。',
          '用 Me Inc. 把每天的行动变成长期复利。',
        ];
      case 'es':
        return [
          'Demasiadas apps consumen tu tiempo, dinero y atencion.',
          'Unifica tu gestion personal y elimina desperdicio diario.',
          'Me Inc. te ayuda a invertir energia en habitos que crecen.',
        ];
      default:
        return [sourceSummary];
    }
  }

  String xPostFor(
    _CampaignTheme theme,
    String landingUrl,
    List<String> hashtags,
  ) {
    final tagLine = hashtags.join(' ');
    switch (code) {
      case 'ja':
        return '${theme.jaValue}。\n浪費を減らすことは、自分の能力を高める訓練です。\n$landingUrl\n$tagLine';
      case 'en':
        return '${theme.enValue}.\nReducing waste is training for better judgment.\n$landingUrl\n$tagLine';
      case 'ko':
        return '시간과 돈, 집중력의 낭비를 줄이는 생활 OS.\n낭비를 줄이는 일은 판단력을 키우는 훈련입니다.\n$landingUrl\n$tagLine';
      case 'zh':
        return '减少时间、金钱和注意力浪费的生活管理系统。\n减少浪费，就是训练更好的判断力。\n$landingUrl\n$tagLine';
      case 'es':
        return 'Un sistema para reducir desperdicio de tiempo, dinero y foco.\nGastar menos energia en lo inutil tambien entrena tu criterio.\n$landingUrl\n$tagLine';
      default:
        return '${theme.enValue}\n$landingUrl\n$tagLine';
    }
  }

  String linkedinPostFor(_CampaignTheme theme, String landingUrl) {
    switch (code) {
      case 'ja':
        return '生活管理の課題は、単なる効率化ではなく、時間・お金・健康・集中力を浪費しない判断を積み上げることです。${theme.jaValue}。詳しくは $landingUrl';
      case 'en':
        return 'Life management is not only productivity. It is the discipline of protecting time, money, health, and focus. ${theme.enValue}. Learn more: $landingUrl';
      case 'ko':
        return '라이프 매니지먼트는 생산성만의 문제가 아닙니다. 시간, 돈, 건강, 집중력을 지키는 판단을 매일 쌓는 일입니다. $landingUrl';
      case 'zh':
        return '生活管理不只是效率工具，而是每天保护时间、金钱、健康和专注力的判断训练。$landingUrl';
      case 'es':
        return 'La gestion personal no es solo productividad. Es proteger tiempo, dinero, salud y foco con mejores decisiones diarias. $landingUrl';
      default:
        return '${theme.enValue}. $landingUrl';
    }
  }

  String heygenBriefFor(_CampaignTheme theme, String sourceSummary) {
    switch (code) {
      case 'ja':
        return 'HeyGenで日本語アバター動画を生成。短文で区切り、落ち着いた事業紹介トーン。参考原稿: $sourceSummary';
      case 'en':
        return 'Create an English HeyGen avatar video with natural lip sync. Tone: concise founder-led product demo. Source: $sourceSummary';
      case 'ko':
        return 'HeyGen에서 한국어 립싱크 아바타 영상으로 변환. 톤은 차분한 제품 소개. 원문 참고: $sourceSummary';
      case 'zh':
        return '用 HeyGen 生成中文口型同步头像视频。语气简洁可信，适合产品介绍。参考: $sourceSummary';
      case 'es':
        return 'Crear video avatar en HeyGen con doblaje/lip-sync en espanol. Tono claro, directo y profesional. Fuente: $sourceSummary';
      default:
        return sourceSummary;
    }
  }
}

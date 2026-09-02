enum DebtGuardCategory {
  debt,
  food,
  nightlife,
  digital,
  gambling,
  homeCare,
  substances,
  sexualBehavior,
  impulse,
}

extension DebtGuardCategoryCopy on DebtGuardCategory {
  String get label => switch (this) {
        DebtGuardCategory.debt => '借入',
        DebtGuardCategory.food => '食事・買い物',
        DebtGuardCategory.nightlife => '外飲み・夜遊び',
        DebtGuardCategory.digital => 'デジタル刺激',
        DebtGuardCategory.gambling => 'ギャンブル',
        DebtGuardCategory.homeCare => '生活維持',
        DebtGuardCategory.substances => '酒・煙草',
        DebtGuardCategory.sexualBehavior => '性的な衝動',
        DebtGuardCategory.impulse => 'その他の衝動',
      };
}

class DebtGuardRule {
  const DebtGuardRule({
    required this.id,
    required this.title,
    required this.category,
    this.detail,
    this.requiredAction,
  });

  final String id;
  final String title;
  final DebtGuardCategory category;
  final String? detail;
  final String? requiredAction;
}

/// Shared ordering and safety boundary for the payoff guard.
///
/// The guard may defer nonessential expansion, but it never defers the actions
/// needed to keep a person safe and able to continue daily life.
class DebtGuardFoundationPolicy {
  const DebtGuardFoundationPolicy._();

  static const motto = '整える → 生き抜く → 一歩進む';

  static const essentialActions = <String>[
    '睡眠',
    '食事',
    '水分補給',
    '医療',
    '衛生',
    '仕事',
    '緊急対応',
    '借金返済',
    '必要な連絡',
  ];

  static const dailyFoundationCopy = '今日を生き抜くために考え、必要なことを行い、'
      'してはいけない衝動はやり過ごします。'
      '責めるためではなく、今日の生活の土台を取り戻すための順番です。';

  static const expansionCopy = '新しい挑戦・事業拡大・必須でない買い物などは、'
      '今日の土台が整ってから最小の一歩だけ進めます。';

  static const routineCopy = '完璧を求めず、毎日すべてを確認して、'
      'その日に必要な項目を最小単位で行います。'
      '体調不良や危険があるときは、達成数より休息・食事・医療を優先します。';

  static const safetyCopy = '睡眠・食事・水分補給・医療・衛生・仕事・緊急対応・'
      '借金返済・必要な連絡は、このガードより常に優先し、'
      '決して制限しません。危険・強い痛み・体調不良がある場合は、'
      '休息・医療・支援を優先してください。';
}

enum DebtGuardFoundationCadence { daily, whenDue, recoveryAware }

extension DebtGuardFoundationCadenceCopy on DebtGuardFoundationCadence {
  String get label => switch (this) {
        DebtGuardFoundationCadence.daily => '毎日行う',
        DebtGuardFoundationCadence.whenDue => '毎日確認し、必要日に行う',
        DebtGuardFoundationCadence.recoveryAware => '体調と回復に合わせて行う',
      };
}

class DebtGuardFoundationTask {
  const DebtGuardFoundationTask({
    required this.id,
    required this.title,
    required this.cadence,
    required this.minimumAction,
  });

  final String id;
  final String title;
  final DebtGuardFoundationCadence cadence;
  final String minimumAction;
}

const debtGuardFoundationTasks = <DebtGuardFoundationTask>[
  DebtGuardFoundationTask(
    id: 'cleaning',
    title: '掃除',
    cadence: DebtGuardFoundationCadence.daily,
    minimumAction: '床・机・水回りのどれか1か所を2分だけ掃除する',
  ),
  DebtGuardFoundationTask(
    id: 'laundry',
    title: '洗濯',
    cadence: DebtGuardFoundationCadence.whenDue,
    minimumAction: '洗濯物を確認し、必要なら洗濯機を回す',
  ),
  DebtGuardFoundationTask(
    id: 'dishes',
    title: '洗い物',
    cadence: DebtGuardFoundationCadence.daily,
    minimumAction: '皿かコップを1つだけ洗う',
  ),
  DebtGuardFoundationTask(
    id: 'tidying',
    title: '整理整頓',
    cadence: DebtGuardFoundationCadence.daily,
    minimumAction: '物を1つだけ元の場所へ戻す',
  ),
  DebtGuardFoundationTask(
    id: 'bath',
    title: '風呂',
    cadence: DebtGuardFoundationCadence.daily,
    minimumAction: '体調に合わせて入浴かシャワーの準備を始める',
  ),
  DebtGuardFoundationTask(
    id: 'home_cooking',
    title: '自炊',
    cadence: DebtGuardFoundationCadence.daily,
    minimumAction: '米を炊くか、次の食事の食材を1つ準備する',
  ),
  DebtGuardFoundationTask(
    id: 'meals',
    title: '食事',
    cadence: DebtGuardFoundationCadence.daily,
    minimumAction: '食事を抜かず、必要な栄養と水分を確保する',
  ),
  DebtGuardFoundationTask(
    id: 'expiry_management',
    title: '食料品・調味料の賞味期限管理',
    cadence: DebtGuardFoundationCadence.whenDue,
    minimumAction: '食品を1つ確認し、期限が近いものを手前に置く',
  ),
  DebtGuardFoundationTask(
    id: 'discard_unused_items',
    title: '不用品の廃棄',
    cadence: DebtGuardFoundationCadence.whenDue,
    minimumAction: '不要な物を1つだけ分別する',
  ),
  DebtGuardFoundationTask(
    id: 'brush_teeth',
    title: '歯磨き',
    cadence: DebtGuardFoundationCadence.daily,
    minimumAction: '歯ブラシを手に取り、30秒だけ磨き始める',
  ),
  DebtGuardFoundationTask(
    id: 'change_clothes',
    title: '毎日着替える',
    cadence: DebtGuardFoundationCadence.daily,
    minimumAction: '清潔な服を1組用意して着替える',
  ),
  DebtGuardFoundationTask(
    id: 'shave',
    title: '髭を剃る',
    cadence: DebtGuardFoundationCadence.whenDue,
    minimumAction: '鏡で確認し、必要なら髭剃りを準備する',
  ),
  DebtGuardFoundationTask(
    id: 'haircut',
    title: '髪を切る',
    cadence: DebtGuardFoundationCadence.whenDue,
    minimumAction: '長さを確認し、必要なら予約か日程決めをする',
  ),
  DebtGuardFoundationTask(
    id: 'trim_nails',
    title: '爪を切る',
    cadence: DebtGuardFoundationCadence.whenDue,
    minimumAction: '爪を確認し、必要なら爪切りを用意する',
  ),
  DebtGuardFoundationTask(
    id: 'asset_management',
    title: '資産管理',
    cadence: DebtGuardFoundationCadence.daily,
    minimumAction: '残高・支払予定・当日の利用を1分だけ確認する',
  ),
  DebtGuardFoundationTask(
    id: 'journal',
    title: '日記をつける',
    cadence: DebtGuardFoundationCadence.daily,
    minimumAction: '今日の事実を1行だけ書く',
  ),
  DebtGuardFoundationTask(
    id: 'reading',
    title: '読書',
    cadence: DebtGuardFoundationCadence.daily,
    minimumAction: '本を開き、1ページだけ読む',
  ),
  DebtGuardFoundationTask(
    id: 'learning',
    title: '学習',
    cadence: DebtGuardFoundationCadence.daily,
    minimumAction: '教材を開き、2分だけ取り組む',
  ),
  DebtGuardFoundationTask(
    id: 'exercise',
    title: '運動',
    cadence: DebtGuardFoundationCadence.daily,
    minimumAction: '体調に合わせて歩くか、軽くストレッチする',
  ),
  DebtGuardFoundationTask(
    id: 'strength_training',
    title: '筋トレ',
    cadence: DebtGuardFoundationCadence.recoveryAware,
    minimumAction: '痛みや疲労を確認し、回復していれば1種目だけ行う',
  ),
];

/// The canonical payoff-guard catalog.
///
/// The user's duplicate gambling entries are intentionally represented by one
/// stable rule. Essential sleep and essential communication are explicitly
/// protected so that the guard cannot encourage sleep deprivation, isolation,
/// missed medical care, or missed creditor contact.
const debtGuardRules = <DebtGuardRule>[
  DebtGuardRule(
    id: 'additional_borrowing',
    title: '追加の借金',
    detail: 'リボ払い・分割払い・後払いを含む',
    category: DebtGuardCategory.debt,
  ),
  DebtGuardRule(
    id: 'eating_out',
    title: '外食',
    category: DebtGuardCategory.food,
  ),
  DebtGuardRule(
    id: 'prepared_foods',
    title: 'お惣菜',
    category: DebtGuardCategory.food,
  ),
  DebtGuardRule(
    id: 'ready_made_frozen_food',
    title: 'できあいの冷凍食品',
    category: DebtGuardCategory.food,
  ),
  DebtGuardRule(
    id: 'drinking_out',
    title: '飲み屋・外飲み',
    category: DebtGuardCategory.nightlife,
  ),
  DebtGuardRule(
    id: 'nightlife_venues',
    title: 'キャバクラ・ガールズバー・スナック・居酒屋・バー',
    category: DebtGuardCategory.nightlife,
  ),
  DebtGuardRule(
    id: 'adult_entertainment',
    title: '風俗・おっぱいパブ・ヘルス・ソープ・ピンサロ・デリヘル',
    category: DebtGuardCategory.nightlife,
  ),
  DebtGuardRule(
    id: 'social_media',
    title: 'SNS',
    category: DebtGuardCategory.digital,
  ),
  DebtGuardRule(
    id: 'short_videos',
    title: 'ショート動画',
    category: DebtGuardCategory.digital,
  ),
  DebtGuardRule(id: 'videos', title: '動画', category: DebtGuardCategory.digital),
  DebtGuardRule(
    id: 'television_radio',
    title: 'テレビ・ラジオ',
    category: DebtGuardCategory.digital,
  ),
  DebtGuardRule(id: 'games', title: 'ゲーム', category: DebtGuardCategory.digital),
  DebtGuardRule(
    id: 'nonessential_communication',
    title: '目的のないLINE・Messenger・メール・電話',
    detail: '仕事・緊急・医療・返済先や支援者との連絡は除く',
    category: DebtGuardCategory.digital,
  ),
  DebtGuardRule(
    id: 'gambling',
    title: 'ギャンブル',
    detail: '重複していた項目を1件に統合',
    category: DebtGuardCategory.gambling,
  ),
  DebtGuardRule(
    id: 'dishes_left_unwashed',
    title: '洗い物放置',
    requiredAction: '皿かコップを1つだけ洗う',
    category: DebtGuardCategory.homeCare,
  ),
  DebtGuardRule(
    id: 'laundry_left_unfinished',
    title: '洗濯放置',
    requiredAction: '洗濯機を回すか、洗濯物を1枚だけ片付ける',
    category: DebtGuardCategory.homeCare,
  ),
  DebtGuardRule(
    id: 'skip_bath',
    title: '風呂キャンセル',
    requiredAction: '浴室へ行き、シャワーを出す',
    category: DebtGuardCategory.homeCare,
  ),
  DebtGuardRule(
    id: 'skip_brushing_teeth',
    title: '歯磨きキャンセル',
    requiredAction: '歯ブラシを手に取り、30秒だけ磨き始める',
    category: DebtGuardCategory.homeCare,
  ),
  DebtGuardRule(
    id: 'sleep_before_essential_care',
    title: '必要な用事や生活ケアを放置したまま寝る',
    detail: '睡眠そのものは禁止しない。健康に必要な睡眠は毎日確保する',
    requiredAction: '残っている生活ケアを1つだけ終え、必要な睡眠を取る',
    category: DebtGuardCategory.homeCare,
  ),
  DebtGuardRule(
    id: 'skip_cleaning',
    title: '掃除キャンセル',
    requiredAction: '目についたゴミを1つだけ捨てる',
    category: DebtGuardCategory.homeCare,
  ),
  DebtGuardRule(
    id: 'ignore_expiry_dates',
    title: '賞味期限無視',
    requiredAction: '食品を1つ確認し、期限が近いものを手前に置く',
    category: DebtGuardCategory.homeCare,
  ),
  DebtGuardRule(
    id: 'alcohol',
    title: '酒',
    category: DebtGuardCategory.substances,
  ),
  DebtGuardRule(
    id: 'tobacco',
    title: '煙草',
    category: DebtGuardCategory.substances,
  ),
  DebtGuardRule(
    id: 'masturbation',
    title: 'オナニー',
    category: DebtGuardCategory.sexualBehavior,
  ),
  DebtGuardRule(
    id: 'other_impulsive_behavior',
    title: 'その他、ドーパミン不足で衝動的に行う行動',
    category: DebtGuardCategory.impulse,
  ),
];

enum DebtGuardEventType {
  checkIn,
  urgeResisted,
  requiredActionStarted,
  violation,
}

extension DebtGuardEventTypeCopy on DebtGuardEventType {
  String get wireName => switch (this) {
        DebtGuardEventType.checkIn => 'check_in',
        DebtGuardEventType.urgeResisted => 'urge_resisted',
        DebtGuardEventType.requiredActionStarted => 'required_action_started',
        DebtGuardEventType.violation => 'violation',
      };

  String get label => switch (this) {
        DebtGuardEventType.checkIn => 'ここまで守った',
        DebtGuardEventType.urgeResisted => '衝動を乗り切った',
        DebtGuardEventType.requiredActionStarted => 'すべきことに着手した',
        DebtGuardEventType.violation => '違反を記録',
      };

  static DebtGuardEventType fromWireName(String value) => switch (value) {
        'check_in' => DebtGuardEventType.checkIn,
        'urge_resisted' => DebtGuardEventType.urgeResisted,
        'required_action_started' => DebtGuardEventType.requiredActionStarted,
        'violation' => DebtGuardEventType.violation,
        _ => throw FormatException('Unknown debt guard event type: $value'),
      };
}

class DebtGuardEvent {
  const DebtGuardEvent({
    required this.id,
    required this.ruleId,
    required this.type,
    required this.eventDate,
    required this.createdAt,
    this.note,
  });

  final int id;
  final String ruleId;
  final DebtGuardEventType type;
  final DateTime eventDate;
  final DateTime createdAt;
  final String? note;
}

enum DebtGuardRuleStatus { unrecorded, kept, violated }

class DebtGuardDailySnapshot {
  DebtGuardDailySnapshot._({
    required this.rules,
    required this.events,
    required Map<String, DebtGuardRuleStatus> statuses,
  }) : statuses = Map.unmodifiable(statuses);

  factory DebtGuardDailySnapshot.fromEvents({
    required List<DebtGuardRule> rules,
    required List<DebtGuardEvent> events,
  }) {
    final statuses = <String, DebtGuardRuleStatus>{
      for (final rule in rules) rule.id: DebtGuardRuleStatus.unrecorded,
    };
    for (final event in events) {
      if (!statuses.containsKey(event.ruleId)) continue;
      if (event.type == DebtGuardEventType.violation) {
        statuses[event.ruleId] = DebtGuardRuleStatus.violated;
      } else if (statuses[event.ruleId] != DebtGuardRuleStatus.violated) {
        statuses[event.ruleId] = DebtGuardRuleStatus.kept;
      }
    }
    return DebtGuardDailySnapshot._(
      rules: List.unmodifiable(rules),
      events: List.unmodifiable(events),
      statuses: statuses,
    );
  }

  final List<DebtGuardRule> rules;
  final List<DebtGuardEvent> events;
  final Map<String, DebtGuardRuleStatus> statuses;

  DebtGuardRuleStatus statusFor(String ruleId) =>
      statuses[ruleId] ?? DebtGuardRuleStatus.unrecorded;

  int get keptCount => statuses.values
      .where((status) => status == DebtGuardRuleStatus.kept)
      .length;

  int get violatedCount => statuses.values
      .where((status) => status == DebtGuardRuleStatus.violated)
      .length;

  int get unrecordedCount => rules.length - keptCount - violatedCount;

  int get resistedUrgeCount => events
      .where((event) => event.type == DebtGuardEventType.urgeResisted)
      .length;

  int get requiredActionStartedCount => events
      .where(
        (event) => event.type == DebtGuardEventType.requiredActionStarted,
      )
      .length;

  int get bugWeakenedCount => resistedUrgeCount + requiredActionStartedCount;

  double get complianceProgress => rules.isEmpty ? 0 : keptCount / rules.length;
}

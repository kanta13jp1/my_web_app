---
title: "個人開発アプリのオンボーディング設計 — Day 0〜28 の定着率を最大化する"
tags: 個人開発,Flutter,webdev,buildinpublic
published: true
---

# 個人開発アプリのオンボーディング設計 — Day 0〜28 の定着率を最大化する

どんなに優れた機能も、ユーザーが最初の 3 分で諦めたら意味がない。自分株式会社の開発では、オンボーディングを改善するたびに Day 7 retention が 10〜15% 改善した。本記事では個人開発者が実践できる、Flutter でのオンボーディングフロー実装と、Day 0〜28 のエンゲージメントシーケンスを解説する。

## オンボーディングの 3 つの目標

1. **価値の即時体感** (Time-to-Value < 3分): ユーザーが「これは役に立つ」と感じるまでの時間を最短化
2. **Progressive Disclosure**: 全機能を一度に見せず、必要なときに必要な機能を提示
3. **空白状態 (Empty State) の解消**: データが空の状態でも使い始めやすい設計

## Empty State の設計

最初にユーザーが見るのは、データが何もないアプリだ。ここでの印象が全てを決める。

```dart
// lib/widgets/empty_state_widget.dart
import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.subtitle,
    this.illustrationPath,
    this.primaryAction,
    this.secondaryAction,
    this.sampleItems,
  });

  final String title;
  final String subtitle;
  final String? illustrationPath;
  final EmptyStateAction? primaryAction;
  final EmptyStateAction? secondaryAction;
  final List<String>? sampleItems; // サンプルデータでイメージを伝える

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (illustrationPath != null)
              Image.asset(illustrationPath!, width: 160, height: 160)
            else
              Icon(
                Icons.inbox_outlined,
                size: 80,
                color: theme.colorScheme.primary.withOpacity(0.4),
              ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),

            // サンプルアイテムでアプリの雰囲気を伝える
            if (sampleItems != null) ...[
              const SizedBox(height: 24),
              ...sampleItems!.map(
                (item) => _SampleItem(text: item),
              ),
            ],

            const SizedBox(height: 32),
            if (primaryAction != null)
              FilledButton.icon(
                onPressed: primaryAction!.onTap,
                icon: Icon(primaryAction!.icon),
                label: Text(primaryAction!.label),
              ),
            if (secondaryAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: secondaryAction!.onTap,
                child: Text(secondaryAction!.label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyStateAction {
  const EmptyStateAction({
    required this.label,
    required this.onTap,
    this.icon = Icons.add,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
}

class _SampleItem extends StatelessWidget {
  const _SampleItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(
          Icons.circle,
          size: 6,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
        ),
      ],
    ),
  );
}
```

### 使い方

```dart
// タスク一覧ページでの使用例
EmptyStateWidget(
  title: 'まだタスクがありません',
  subtitle: '今日やることを追加して、\n自分株式会社と一緒に管理しよう。',
  illustrationPath: 'assets/illustrations/empty_tasks.png',
  sampleItems: const [
    '例: 企画書の作成 (今日中)',
    '例: ジムに行く (18:00)',
    '例: メルカリの出品作業',
  ],
  primaryAction: EmptyStateAction(
    label: '最初のタスクを追加',
    onTap: () => context.push('/tasks/new'),
  ),
  secondaryAction: EmptyStateAction(
    label: 'サンプルデータで試す',
    onTap: () => _loadSampleData(),
  ),
)
```

## オンボーディング PageView の実装

初回起動時だけ表示するスライドカルーセルで価値を伝える。

```dart
// lib/pages/onboarding_page.dart
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _steps = [
    OnboardingStep(
      title: '21社分の機能を1つに',
      subtitle: 'Notion・Evernote・MoneyForward の機能が\nすべて自分株式会社に揃っています。',
      illustration: 'assets/onboarding/step1.png',
      color: Color(0xFF6C63FF),
    ),
    OnboardingStep(
      title: 'AI があなたの代わりに考える',
      subtitle: '毎日の判断をAIがサポート。\n何をすべきかを自動で提案します。',
      illustration: 'assets/onboarding/step2.png',
      color: Color(0xFF4ECDC4),
    ),
    OnboardingStep(
      title: 'まず1つだけ試してみよう',
      subtitle: '今日のタスクを1件追加するだけで\n自分株式会社の価値を実感できます。',
      illustration: 'assets/onboarding/step3.png',
      color: Color(0xFFFF6B6B),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _steps.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    // 完了フラグを SharedPreferences に保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // スキップボタン
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finishOnboarding,
                child: const Text('スキップ'),
              ),
            ),

            // スライド本体
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _steps.length,
                itemBuilder: (context, i) => _StepView(step: _steps[i]),
              ),
            ),

            // プログレスドット
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == _currentPage
                          ? _steps[i].color
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ),

            // CTA ボタン
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    _currentPage == _steps.length - 1
                        ? 'はじめる'
                        : '次へ',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Day 0〜28 エンゲージメントシーケンス

登録直後から 28 日間、適切なタイミングでユーザーに価値を届けるシーケンス。

| Day | トリガー | メッセージ | 目的 |
|-----|---------|-----------|------|
| **Day 0** | 登録完了直後 | ようこそメール + 最初の 1 タスク追加を促す | Activation |
| **Day 1** | 初回アクティビティから 24h | 「昨日追加したタスク、進捗はどうですか?」 | Habit formation |
| **Day 3** | 未使用の場合 | 「3 分で使える便利な機能 3 選」 | Feature discovery |
| **Day 7** | 1 週間経過 | 「今週の振り返り」+ AI サマリー | Value reinforcement |
| **Day 14** | 2 週間経過 | 「パワーユーザーへの道」上級機能の紹介 | Upgrade nudge |
| **Day 28** | 1 ヶ月経過 | 「1 ヶ月の成長レポート」 | Retention + social proof |

### Supabase Edge Function でメール送信

```typescript
// supabase/functions/onboarding-sequence/index.ts
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // Day 3 未使用ユーザーを取得
  const threeDaysAgo = new Date()
  threeDaysAgo.setDate(threeDaysAgo.getDate() - 3)

  const { data: users } = await supabase
    .from('profiles')
    .select('id, email, display_name')
    .lt('created_at', threeDaysAgo.toISOString())
    .eq('onboarding_email_day3_sent', false)
    .is('last_active_at', null)  // まだ一度もアクティブでない

  for (const user of users ?? []) {
    await sendEmail(user.email, 'day3_re_engagement', {
      name: user.display_name,
    })

    await supabase
      .from('profiles')
      .update({ onboarding_email_day3_sent: true })
      .eq('id', user.id)
  }

  return new Response(JSON.stringify({ sent: users?.length ?? 0 }))
})
```

## Progressive Disclosure: 機能を段階的に見せる

全機能を最初から見せることは逆効果だ。ユーザーの習熟度に合わせて機能を解放する。

```dart
// lib/services/feature_flag_service.dart
class FeatureFlagService {
  final SupabaseClient _client;
  FeatureFlagService(this._client);

  /// ユーザーの利用日数を取得
  Future<int> getDaysSinceSignup() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;

    final createdAt = DateTime.parse(user.createdAt);
    return DateTime.now().difference(createdAt).inDays;
  }

  /// 機能が表示可能かどうか
  Future<bool> isFeatureVisible(String featureKey) async {
    final days = await getDaysSinceSignup();

    return switch (featureKey) {
      'basic_tasks'     => true,          // 常時表示
      'ai_suggestions'  => days >= 1,     // Day 1 から
      'analytics'       => days >= 7,     // Day 7 から
      'export'          => days >= 14,    // Day 14 から
      'api_access'      => days >= 30,    // Day 30 から
      _                 => false,
    };
  }
}
```

## チェックリスト: オンボーディング設計の確認項目

- [ ] Empty State に「価値の説明」と「最初の行動 CTA」がある
- [ ] オンボーディングスライドは 3〜5 画面以内 (それ以上は離脱率が急増)
- [ ] スキップボタンが必ずある (強制は禁物)
- [ ] Day 0 のウェルカムメールを送信している
- [ ] Day 7 retention を計測している (Supabase Analytics / Mixpanel)
- [ ] サンプルデータで試せる機能がある
- [ ] 初回の「成功体験」が 3 分以内に得られる

## まとめ

個人開発者は機能を作ることに集中しがちだが、オンボーディングこそがユーザーが定着するかどうかを決める最重要ポイントだ。特に「Empty State の設計」と「Day 7 retention の計測」から始めるだけでプロダクトの成長速度が変わる。

自分株式会社では Day 7 retention を週次で計測し、改善を繰り返している。小さな改善でも積み重なれば大きな差になる。

---

*本記事は自分株式会社 (Flutter Web + Supabase) の実装経験をもとに執筆しました。*

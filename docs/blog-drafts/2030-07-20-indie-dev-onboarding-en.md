---
title: "Indie App Onboarding That Retains Users — Day 0 to Day 28 Engagement Design"
tags: indiedev,flutter,buildinpublic,webdev
published: true
---

# Indie App Onboarding That Retains Users — Day 0 to Day 28 Engagement Design

Every feature you've built is worthless if users quit in the first three minutes. At Jibun Inc. — a Flutter Web life management app competing with Notion, Evernote, and 19 others — improving onboarding increased Day-7 retention by 15% in a single sprint. This article covers the full onboarding stack: empty states, PageView carousels, progressive disclosure, and a Day 0–28 re-engagement sequence.

## The Three Goals of Onboarding

| Goal | Metric | Target |
|------|--------|--------|
| **Time to Value** | Minutes from sign-up to first "aha" | < 3 minutes |
| **Activation** | Users who complete core action on Day 0 | > 60% |
| **Day 7 Retention** | Users who return within 7 days | > 40% |

Getting these numbers right matters far more than shipping the next feature. Track them before you build anything else.

## 1. Empty State Design

The very first screen your user sees is an empty list with zero data. This moment makes or breaks activation.

**Bad empty state**: Just a message that says "No items yet."

**Good empty state**: Explains the value, shows what it will look like, and offers a clear next action.

```dart
// lib/widgets/empty_state_widget.dart
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.subtitle,
    this.illustrationPath,
    this.sampleItems,
    this.primaryAction,
    this.secondaryAction,
  });

  final String title;
  final String subtitle;
  final String? illustrationPath;
  final List<String>? sampleItems;     // ghost items to set expectations
  final EmptyStateAction? primaryAction;
  final EmptyStateAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (illustrationPath != null)
                Image.asset(illustrationPath!, width: 140, height: 140)
              else
                Icon(
                  Icons.inbox_outlined,
                  size: 80,
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              const SizedBox(height: 24),
              Text(title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                ),
                textAlign: TextAlign.center),

              // Ghost items — show what the list will look like
              if (sampleItems != null) ...[
                const SizedBox(height: 20),
                ...sampleItems!.map((s) => _GhostItem(text: s)),
              ],

              const SizedBox(height: 28),
              if (primaryAction != null)
                FilledButton.icon(
                  onPressed: primaryAction!.onTap,
                  icon: Icon(primaryAction!.icon),
                  label: Text(primaryAction!.label),
                ),
              if (secondaryAction != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: secondaryAction!.onTap,
                  child: Text(secondaryAction!.label),
                ),
              ],
            ],
          ),
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

class _GhostItem extends StatelessWidget {
  const _GhostItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(Icons.circle,
          size: 6,
          color: Colors.grey.withOpacity(0.4)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    ),
  );
}
```

### Practical usage

```dart
EmptyStateWidget(
  illustrationPath: 'assets/illustrations/empty_tasks.png',
  title: 'No tasks yet',
  subtitle: 'Add your first task and let AI help\nyou decide what to tackle today.',
  sampleItems: const [
    'e.g. Write the product spec (today)',
    'e.g. Reply to investor emails',
    'e.g. Ship the auth page',
  ],
  primaryAction: EmptyStateAction(
    label: 'Add your first task',
    onTap: () => context.push('/tasks/new'),
  ),
  secondaryAction: EmptyStateAction(
    label: 'Try with sample data',
    icon: Icons.science_outlined,
    onTap: _loadSampleData,
  ),
)
```

## 2. Onboarding PageView Carousel

Show a 3-slide intro carousel only on first launch. Keep it under 4 slides — engagement drops sharply beyond that.

```dart
// lib/pages/onboarding_page.dart
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _steps = [
    _Step(
      title: '21 apps in one',
      body: 'Replace Notion, Evernote, MoneyForward and 18 others\nwith a single, unified workspace.',
      icon: Icons.auto_awesome,
      color: Color(0xFF6C63FF),
    ),
    _Step(
      title: 'AI does the thinking',
      body: 'Daily AI suggestions tell you what to focus on\nso you spend time doing, not deciding.',
      icon: Icons.psychology_outlined,
      color: Color(0xFF4ECDC4),
    ),
    _Step(
      title: 'Start with one task',
      body: 'Just add a single task right now.\nThat\'s all it takes to feel the difference.',
      icon: Icons.check_circle_outline,
      color: Color(0xFFFF6B6B),
    ),
  ];

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _complete,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _steps.length,
                itemBuilder: (_, i) => _StepCard(step: _steps[i]),
              ),
            ),
            _ProgressDots(
              count: _steps.length,
              current: _page,
              activeColor: _steps[_page].color,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _page < _steps.length - 1
                      ? () => _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : _complete,
                  style: FilledButton.styleFrom(
                    backgroundColor: _steps[_page].color,
                  ),
                  child: Text(
                    _page == _steps.length - 1 ? "Let's go!" : 'Next',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.count,
    required this.current,
    required this.activeColor,
  });

  final int count, current;
  final Color activeColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(count, (i) => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: i == current ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: i == current ? activeColor : Colors.grey.shade300,
      ),
    )),
  );
}
```

## 3. Day 0–28 Engagement Sequence

After sign-up, a drip sequence keeps users coming back while they build the habit.

| Day | Trigger | Message | Goal |
|-----|---------|---------|------|
| **0** | Sign-up | Welcome email + "Add your first task" CTA | Activation |
| **1** | 24h after first action | "How did yesterday's task go?" | Habit seed |
| **3** | No activity in 3 days | "3 features you haven't tried yet" | Re-activation |
| **7** | 1-week mark | AI weekly summary of your progress | Value proof |
| **14** | 2-week mark | "Power user unlock: export, API, advanced filters" | Upsell nudge |
| **28** | 1-month mark | "Your first month in numbers" personalized report | Retention + social |

### Supabase Edge Function for the Day-3 re-engagement email

```typescript
// supabase/functions/onboarding-day3/index.ts
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async () => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // Users created 3 days ago who haven't been active since signup
  const target = new Date()
  target.setDate(target.getDate() - 3)
  const window = new Date(target)
  window.setHours(window.getHours() - 1)

  const { data: users, error } = await supabase
    .from('profiles')
    .select('id, email, display_name')
    .gte('created_at', window.toISOString())
    .lte('created_at', target.toISOString())
    .eq('day3_email_sent', false)
    .is('last_active_at', null)

  if (error) return new Response(JSON.stringify({ error }), { status: 500 })

  let sent = 0
  for (const user of users ?? []) {
    const ok = await sendReEngagementEmail(user)
    if (ok) {
      await supabase
        .from('profiles')
        .update({ day3_email_sent: true })
        .eq('id', user.id)
      sent++
    }
  }

  return new Response(JSON.stringify({ sent }))
})
```

## 4. Progressive Disclosure

Reveal advanced features only after users are comfortable with basics.

```dart
// lib/services/feature_flags.dart
class FeatureFlags {
  FeatureFlags(this._client);
  final SupabaseClient _client;

  Future<int> _daysSinceSignup() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;
    return DateTime.now().difference(DateTime.parse(user.createdAt)).inDays;
  }

  Future<bool> canSee(String feature) async {
    final days = await _daysSinceSignup();
    return switch (feature) {
      'basic_tasks'     => true,
      'ai_suggest'      => days >= 1,
      'analytics'       => days >= 7,
      'bulk_export'     => days >= 14,
      'api_access'      => days >= 30,
      _                 => false,
    };
  }
}

// In a widget:
FutureBuilder<bool>(
  future: featureFlags.canSee('analytics'),
  builder: (context, snap) {
    if (snap.data != true) return const SizedBox.shrink();
    return const AnalyticsNavItem();
  },
)
```

## Onboarding Checklist

- [ ] Every empty state has a value explanation + single primary CTA
- [ ] Onboarding slides are 3–4 max (5+ kills completion rate)
- [ ] A "Skip" button is always visible
- [ ] Welcome email is sent on Day 0 (test it yourself after sign-up)
- [ ] Day 7 retention is being measured (Supabase Analytics or Mixpanel)
- [ ] Sample data is available so users can explore without committing
- [ ] First "win" is achievable in under 3 minutes

## Summary

For indie developers, onboarding is often the highest-ROI place to invest time. A single well-designed empty state outperforms three new features in terms of retention impact. Start by measuring Day-7 retention, then work backwards: what needs to happen on Day 0 for users to come back on Day 7?

At Jibun Inc., we run a weekly retrospective on this single metric. Small, compounding improvements here beat big feature releases in long-term growth.

---

*Based on real implementation at Jibun Inc. (Flutter Web + Supabase, competing with 21 apps).*

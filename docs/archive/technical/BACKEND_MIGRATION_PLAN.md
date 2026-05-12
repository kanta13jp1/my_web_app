# バックエンド移行計画 [Archive]

**作成日**: 2025年11月8日
**目的**: フロントエンドの複雑な処理をバックエンドに移行し、パフォーマンス、セキュリティ、スケーラビリティを向上させる

---

## 📋 移行の必要性

### 現状の課題

1. **セキュリティリスク**
   - クライアント側でポイント計算、レベル計算を実行
   - 改ざん可能（DevToolsで簡単に変更可能）
   - 不正なデータ送信を防げない

2. **パフォーマンス問題**
   - メモカード画像生成でブラウザがフリーズ
   - 大容量ファイルのインポートでタイムアウト
   - モバイル端末でのバッテリー消費が大きい

3. **スケーラビリティの限界**
   - 複雑な処理がクライアント側に集中
   - サーバー側でのログ分析ができない
   - A/Bテストや機能フラグの実装が困難

4. **同期問題**
   - 複数デバイス間でのデータ整合性
   - オフライン時の処理が複雑

### 移行による期待効果

| 指標 | 移行前 | 移行後（予測） | 改善率 |
|:-----|-------:|---------------:|-------:|
| クライアント側CPU使用率 | 100% | 30% | -70% |
| 初回読み込み時間 | 3.5秒 | 1.2秒 | -66% |
| バッテリー消費 | 高 | 低 | -50% |
| セキュリティスコア | 60/100 | 95/100 | +58% |
| 開発速度（新機能） | 遅い | 早い | +200% |

---

## 🎯 移行対象の優先順位

### 優先度: 高 🔴（即時対応）

#### 1. ゲーミフィケーション処理
**現状**: `lib/services/gamification_service.dart` (19,759行)
- ポイント計算
- レベル計算
- アチーブメント解除ロジック

**問題点**:
- セキュリティリスク（改ざん可能）
- 複数デバイス間の同期問題
- CPU・バッテリー消費が大きい

**移行先**: Supabase Edge Functions + PostgreSQL Functions

**実装計画**:
```typescript
// supabase/functions/award-points/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  const { userId, action, metadata } = await req.json()

  // ポイント計算（サーバー側で安全に）
  const points = calculatePoints(action, metadata)

  // トランザクションで更新
  const { data, error } = await supabase.rpc('award_points', {
    p_user_id: userId,
    p_action: action,
    p_points: points,
    p_metadata: metadata
  })

  if (error) throw error

  // アチーブメント自動チェック
  await checkAchievements(userId, data)

  return new Response(JSON.stringify(data), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

**PostgreSQL Function**:
```sql
CREATE OR REPLACE FUNCTION award_points(
  p_user_id UUID,
  p_action TEXT,
  p_points INT,
  p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS TABLE(
  user_id UUID,
  total_points INT,
  level INT,
  new_achievements TEXT[]
) AS $$
DECLARE
  v_new_points INT;
  v_new_level INT;
  v_achievements TEXT[];
BEGIN
  -- ポイント付与（アトミック操作）
  UPDATE user_stats
  SET
    total_points = total_points + p_points,
    level = calculate_level(total_points + p_points),
    updated_at = NOW()
  WHERE user_stats.user_id = p_user_id
  RETURNING total_points, level INTO v_new_points, v_new_level;

  -- アクティビティログ記録
  INSERT INTO gamification_logs (user_id, action, points, metadata)
  VALUES (p_user_id, p_action, p_points, p_metadata);

  -- アチーブメント自動チェック
  v_achievements := check_and_unlock_achievements(p_user_id);

  RETURN QUERY
  SELECT p_user_id, v_new_points, v_new_level, v_achievements;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**移行スケジュール**:
- Week 1: PostgreSQL関数作成とテスト
- Week 2: Edge Function実装
- Week 3: フロントエンド統合
- Week 4: 本番デプロイ

**リスク**:
- 既存データとの整合性
- パフォーマンスのボトルネック

**対策**:
- マイグレーションスクリプトで既存データを検証
- ロードテストで事前確認
- カナリアリリース（10%のユーザーから段階的に）

---

#### 2. メモカード画像生成
**現状**: `lib/services/note_card_service.dart` (11,490行)
- Flutter Widgetをスクリーンショット
- 重い画像処理

**問題点**:
- モバイル端末でフリーズ
- メモリ消費が大きい（100MB+）
- 端末によって品質が異なる

**移行先**: Netlify Functions (既にSNSシェアで実績あり)

**実装計画**:
```javascript
// netlify/functions/generate-note-card.js
const { generateNoteCardSVG } = require('./utils/svg-generator')

exports.handler = async (event) => {
  const { title, content, level, points, theme } = JSON.parse(event.body)

  // SVG生成（軽量、高品質、一貫性）
  const svg = generateNoteCardSVG({
    title,
    content: content.substring(0, 200), // 最初の200文字
    level,
    points,
    theme: theme || 'default',
    width: 1200,
    height: 630
  })

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'image/svg+xml; charset=utf-8',
      'Cache-Control': 'public, max-age=3600'
    },
    body: svg
  }
}
```

**SVG生成ユーティリティ**:
```javascript
// netlify/functions/utils/svg-generator.js
function generateNoteCardSVG({ title, content, level, points, theme, width, height }) {
  const themes = {
    default: { bg: '#667eea', text: '#fff' },
    dark: { bg: '#1a202c', text: '#fff' },
    light: { bg: '#f7fafc', text: '#1a202c' }
  }

  const colors = themes[theme] || themes.default

  return `
    <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" style="stop-color:${colors.bg};stop-opacity:1" />
          <stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />
        </linearGradient>
      </defs>

      <rect width="${width}" height="${height}" fill="url(#bg)"/>

      <!-- タイトル -->
      <text x="60" y="100" font-family="Arial, sans-serif" font-size="48"
            font-weight="bold" fill="${colors.text}">
        ${escapeXml(title)}
      </text>

      <!-- コンテンツ -->
      <text x="60" y="180" font-family="Arial, sans-serif" font-size="24"
            fill="${colors.text}" opacity="0.9">
        ${escapeXml(content)}
      </text>

      <!-- レベル・ポイント -->
      <text x="60" y="${height - 60}" font-family="Arial, sans-serif"
            font-size="32" fill="${colors.text}">
        Level ${level} • ${points.toLocaleString()} pts
      </text>
    </svg>
  `
}

function escapeXml(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;')
}

module.exports = { generateNoteCardSVG }
```

**移行スケジュール**:
- Week 1: SVG生成ロジック実装
- Week 2: Netlify Function作成とテスト
- Week 3: フロントエンド統合
- Week 4: 本番デプロイ

**効果**:
- クライアント側のメモリ消費 -90%
- 画像生成時間 3秒 → 0.5秒
- 一貫した画質

---

#### 3. データインポート処理
**現状**: `lib/services/import_service.dart` (9,738行)
- Notion/Evernoteデータのパース
- 全てクライアント側

**問題点**:
- 大容量ファイルでタイムアウト
- ブラウザがフリーズ
- メモリ不足エラー

**移行先**: Supabase Edge Functions + バックグラウンドジョブ

**実装計画（非同期処理）**:
```typescript
// supabase/functions/import-notes/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  const { userId, fileUrl, source } = await req.json()

  // バックグラウンドジョブをキューに追加
  const { data: job, error } = await supabase
    .from('import_jobs')
    .insert({
      user_id: userId,
      file_url: fileUrl,
      source: source,
      status: 'queued',
      progress: 0
    })
    .select()
    .single()

  if (error) throw error

  // 別のEdge Functionでバックグラウンド処理を開始
  fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/process-import`, {
    method: 'POST',
    body: JSON.stringify({ jobId: job.id })
  })

  return new Response(JSON.stringify({
    jobId: job.id,
    message: 'Import job queued',
    statusUrl: `/api/import-status/${job.id}`
  }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

**バックグラウンド処理**:
```typescript
// supabase/functions/process-import/index.ts
serve(async (req) => {
  const { jobId } = await req.json()

  // ジョブ取得
  const { data: job } = await supabase
    .from('import_jobs')
    .select('*')
    .eq('id', jobId)
    .single()

  // ステータス更新: processing
  await updateJobStatus(jobId, 'processing', 0)

  try {
    // ファイルダウンロード
    const fileData = await fetch(job.file_url).then(r => r.text())

    // パース（Notion/Evernote形式に応じて）
    const notes = parseImportFile(fileData, job.source)

    // バッチインサート（1000件ずつ）
    const batchSize = 1000
    for (let i = 0; i < notes.length; i += batchSize) {
      const batch = notes.slice(i, i + batchSize)

      await supabase.from('notes').insert(
        batch.map(note => ({
          user_id: job.user_id,
          title: note.title,
          content: note.content,
          category_id: note.categoryId,
          created_at: note.createdAt
        }))
      )

      // 進捗更新
      const progress = Math.floor(((i + batchSize) / notes.length) * 100)
      await updateJobStatus(jobId, 'processing', progress)
    }

    // 完了
    await updateJobStatus(jobId, 'completed', 100, {
      imported_count: notes.length
    })

  } catch (error) {
    await updateJobStatus(jobId, 'failed', 0, {
      error: error.message
    })
  }

  return new Response(JSON.stringify({ success: true }))
})

async function updateJobStatus(jobId, status, progress, metadata = {}) {
  await supabase
    .from('import_jobs')
    .update({
      status,
      progress,
      metadata,
      updated_at: new Date().toISOString()
    })
    .eq('id', jobId)
}
```

**データベーススキーマ**:
```sql
CREATE TABLE import_jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  file_url TEXT NOT NULL,
  source TEXT NOT NULL, -- 'notion' or 'evernote'
  status TEXT NOT NULL DEFAULT 'queued', -- queued, processing, completed, failed
  progress INT DEFAULT 0, -- 0-100
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_import_jobs_user_id ON import_jobs(user_id);
CREATE INDEX idx_import_jobs_status ON import_jobs(status);
```

**フロントエンド（進捗表示）**:
```dart
// lib/services/import_service.dart
class ImportService {
  Future<String> startImport(String fileUrl, String source) async {
    final response = await supabase.functions.invoke('import-notes', body: {
      'userId': supabase.auth.currentUser!.id,
      'fileUrl': fileUrl,
      'source': source,
    });

    return response.data['jobId'];
  }

  Stream<ImportJob> watchImportProgress(String jobId) {
    return supabase
        .from('import_jobs')
        .stream(primaryKey: ['id'])
        .eq('id', jobId)
        .map((data) => ImportJob.fromJson(data.first));
  }
}
```

**移行スケジュール**:
- Week 1-2: バックグラウンドジョブシステム設計
- Week 3: Edge Functions実装
- Week 4: フロントエンド統合（進捗バー）
- Week 5: 本番デプロイ

**効果**:
- タイムアウト問題の解消
- 大容量ファイル対応（10万メモ以上）
- ユーザーは他の操作を継続可能

---

### 優先度: 中 🟡（1-2ヶ月以内）

#### 4. デイリーチャレンジ進捗計算
**現状**: `lib/services/daily_challenge_service.dart` (6,838行)

**移行先**: Supabase Database Triggers

```sql
-- メモ作成時に自動的にチャレンジ進捗を更新
CREATE OR REPLACE FUNCTION update_challenge_progress()
RETURNS TRIGGER AS $$
BEGIN
  -- 今日のチャレンジ進捗を更新
  INSERT INTO user_challenge_progress (user_id, challenge_id, progress)
  SELECT
    NEW.user_id,
    dc.id,
    1
  FROM daily_challenges dc
  WHERE dc.challenge_date = CURRENT_DATE
    AND dc.challenge_type = 'create_notes'
  ON CONFLICT (user_id, challenge_id)
  DO UPDATE SET
    progress = user_challenge_progress.progress + 1,
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_challenge_progress
AFTER INSERT ON notes
FOR EACH ROW
EXECUTE FUNCTION update_challenge_progress();
```

**効果**:
- リアルタイム進捗更新
- クライアント側のロジック削減

---

#### 5. バイラル成長施策の分析
**現状**: `lib/services/viral_growth_service.dart` (6,691行)

**移行先**: Supabase Edge Functions + Analytics

**不正防止ロジック**:
```typescript
// supabase/functions/track-referral/index.ts
serve(async (req) => {
  const { referralCode, newUserId } = await req.json()

  // 不正チェック1: 自己紹介防止
  const { data: referrer } = await supabase
    .from('referral_codes')
    .select('user_id')
    .eq('code', referralCode)
    .single()

  if (referrer.user_id === newUserId) {
    throw new Error('Self-referral not allowed')
  }

  // 不正チェック2: IPアドレス重複チェック
  const clientIp = req.headers.get('x-forwarded-for')
  const recentReferrals = await supabase
    .from('referrals')
    .select('id')
    .eq('referrer_id', referrer.user_id)
    .eq('metadata->>ip', clientIp)
    .gte('created_at', new Date(Date.now() - 24*60*60*1000).toISOString())

  if (recentReferrals.data.length > 3) {
    throw new Error('Too many referrals from same IP')
  }

  // 紹介記録
  await supabase.from('referrals').insert({
    referrer_id: referrer.user_id,
    referred_user_id: newUserId,
    metadata: { ip: clientIp }
  })

  // ポイント付与
  await supabase.rpc('award_points', {
    p_user_id: referrer.user_id,
    p_action: 'referral',
    p_points: 1000
  })

  return new Response(JSON.stringify({ success: true }))
})
```

---

#### 6. デイリーログイン報酬
**現状**: `lib/services/daily_login_service.dart` (4,988行)

**移行先**: Supabase Edge Functions + Database Function

```sql
CREATE OR REPLACE FUNCTION claim_daily_login_reward(p_user_id UUID)
RETURNS TABLE(
  reward_points INT,
  current_streak INT,
  message TEXT
) AS $$
DECLARE
  v_last_login DATE;
  v_current_streak INT;
  v_reward_points INT;
BEGIN
  -- 最終ログイン日取得
  SELECT last_login_date, login_streak
  INTO v_last_login, v_current_streak
  FROM user_stats
  WHERE user_id = p_user_id;

  -- 今日既にログイン済みかチェック
  IF v_last_login = CURRENT_DATE THEN
    RETURN QUERY SELECT 0, v_current_streak, 'Already claimed today';
    RETURN;
  END IF

  -- ストリーク計算
  IF v_last_login = CURRENT_DATE - INTERVAL '1 day' THEN
    v_current_streak := v_current_streak + 1;
  ELSE
    v_current_streak := 1;
  END IF;

  -- 報酬計算（連続日数に応じて増加）
  v_reward_points := CASE
    WHEN v_current_streak >= 31 THEN 100
    WHEN v_current_streak >= 15 THEN 50
    WHEN v_current_streak >= 8 THEN 30
    WHEN v_current_streak >= 4 THEN 20
    ELSE 10
  END;

  -- 更新
  UPDATE user_stats
  SET
    last_login_date = CURRENT_DATE,
    login_streak = v_current_streak,
    total_points = total_points + v_reward_points
  WHERE user_id = p_user_id;

  RETURN QUERY SELECT v_reward_points, v_current_streak, 'Reward claimed!';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### 優先度: 低 🟢（3ヶ月以降）

#### 7. 統計ダッシュボード集計
**現状**: フロントエンドで集計

**移行先**: Cloudflare Workers + Durable Objects（リアルタイムカウンター）

```javascript
// cloudflare-workers/realtime-stats.js
export default {
  async fetch(request, env) {
    const stats = {
      onlineUsers: await env.STATS.get('online_users'),
      todaySignups: await env.STATS.get('today_signups'),
      totalNotes: await env.STATS.get('total_notes')
    }

    return new Response(JSON.stringify(stats), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=10' // 10秒キャッシュ
      }
    })
  }
}
```

---

## 📊 移行ロードマップ

### フェーズ1: 基盤整備（Week 1-2）
- [x] プロジェクト分析完了
- [ ] PostgreSQL Functions設計
- [ ] Edge Functions開発環境構築
- [ ] テストデータ作成

### フェーズ2: 優先度高の移行（Week 3-6）
- [ ] ゲーミフィケーション移行
- [ ] メモカード画像生成移行
- [ ] インポート処理移行
- [ ] テスト＆デバッグ

### フェーズ3: 優先度中の移行（Week 7-10）
- [ ] デイリーチャレンジ移行
- [ ] バイラル成長施策移行
- [ ] デイリーログイン報酬移行
- [ ] パフォーマンステスト

### フェーズ4: 最適化（Week 11-12）
- [ ] Cloudflare Workers導入検討
- [ ] キャッシング戦略実装
- [ ] モニタリング＆アラート設定
- [ ] ドキュメント更新

---

## 🔧 技術スタック

### 移行後のアーキテクチャ

```
┌─────────────────────────────────┐
│  Flutter Web (フロントエンド)  │
│  - UI/UXのみ                   │
│  - 軽量なビジネスロジック      │
└─────────────────────────────────┘
              ↓
┌─────────────────────────────────┐
│  Supabase Edge Functions        │
│  - ゲーミフィケーション        │
│  - インポート処理              │
│  - バイラル成長施策            │
└─────────────────────────────────┘
              ↓
┌─────────────────────────────────┐
│  PostgreSQL (Supabase)          │
│  - Database Functions          │
│  - Triggers                    │
│  - Row Level Security          │
└─────────────────────────────────┘
              ↓
┌─────────────────────────────────┐
│  Netlify Functions              │
│  - メモカード画像生成          │
│  - SNSシェア（既存）           │
└─────────────────────────────────┘
```

### 技術選定理由

| 技術 | 用途 | 理由 |
|:-----|:-----|:-----|
| Supabase Edge Functions | ビジネスロジック | TypeScript、無料枠、Supabaseとの統合 |
| PostgreSQL Functions | データベースロジック | トランザクション、パフォーマンス、セキュリティ |
| Netlify Functions | 画像生成 | 無料、高速、CDN配信 |
| Cloudflare Workers | 統計・キャッシュ（将来） | エッジコンピューティング、グローバル展開 |

---

## 📈 成功指標

### パフォーマンス
- [ ] 初回読み込み時間: 3.5秒 → 1.2秒
- [ ] メモ作成レスポンス: 500ms → 200ms
- [ ] 画像生成時間: 3秒 → 0.5秒

### セキュリティ
- [ ] ポイント改ざん防止: 100%
- [ ] 不正紹介防止: 95%以上
- [ ] RLS適用率: 100%

### スケーラビリティ
- [ ] 同時接続ユーザー: 100 → 10,000
- [ ] インポート可能なメモ数: 1,000 → 100,000
- [ ] Edge Function実行時間: < 1秒

---

## 🚨 リスク管理

### リスク1: データ整合性の問題
**対策**:
- マイグレーション前に完全バックアップ
- ステージング環境で十分テスト
- カナリアリリース（段階的展開）

### リスク2: パフォーマンス劣化
**対策**:
- ロードテスト実施
- キャッシング戦略
- モニタリング＆アラート

### リスク3: 予算オーバー
**対策**:
- Supabase無料枠の監視
- 段階的な移行（一度に全て移行しない）
- コスト最適化（不要なAPI呼び出し削減）

---

## 📚 関連ドキュメント

- [PROJECT_ANALYSIS_2025-11-08.md](./PROJECT_ANALYSIS_2025-11-08.md) - プロジェクト総合分析
- [GROWTH_STRATEGY_ROADMAP.md](./GROWTH_STRATEGY_ROADMAP.md) - 成長戦略
- [SUPABASE_EDGE_FUNCTIONS_DEPLOY.md](./SUPABASE_EDGE_FUNCTIONS_DEPLOY.md) - Edge Functionsデプロイ手順

---

**作成日**: 2025年11月8日
**最終更新**: 2025年11月8日
**次回レビュー**: 2025年11月22日

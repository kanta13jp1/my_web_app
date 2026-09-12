import 'package:flutter/material.dart';

import 'asset_management_page.dart';

/// MoneyForward 連携案内ページ
///
/// MoneyForward は個人利用者向けの公開 OAuth API を提供していないため、
/// アプリ側からの自動連携（口座同期）は実施できない。旧実装はダミーの
/// 「接続する」ボタンと常に空の口座・取引一覧を表示しており、実際には
/// 一度も接続状態にならない死んだ画面だった（トークンを書き込む経路が
/// どこにも存在しないため）。ここでは実際に動く代替手段（CSV エクスポート
/// → インポート画面での取り込み）へ誘導する。
class MoneyForwardPage extends StatelessWidget {
  const MoneyForwardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MoneyForward 連携'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: '資産管理へ',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/asset-management'),
                  builder: (_) => const AssetManagementPage(
                    initialFocus: AssetManagementInitialFocus.assets,
                    entryLabel: 'MoneyForward連携',
                    entryDescription:
                        '口座・証券・家計の確認は資産管理に統合しました。資産残高、収支、固定費、借金ロックダウン、浪費抑制AIを一つの画面で見られます。',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 8),
          const Center(
            child: Icon(
              Icons.sync_problem_outlined,
              size: 72,
              color: Color(0xFF00B900),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              '自動連携（OAuth）は現在ご利用いただけません',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'MoneyForward は個人向けの公開連携 API を提供していないため、'
              'ワンクリックでの口座自動同期は現時点で実装できません。\n'
              '下記の方法で CSV エクスポートを取り込めば、今すぐ収支データを反映できます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Card(
            color: Color(0xFFF0FDF4),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.checklist_outlined,
                        color: Color(0xFF16A34A),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'CSV インポートの手順',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  _StepItem(
                    text: 'MoneyForward ME にログイン（moneyforward.com）',
                  ),
                  _StepItem(
                    text: '「家計簿」→「明細」タブ →「エクスポート」→「CSVダウンロード」',
                  ),
                  _StepItem(text: '期間を指定してダウンロード'),
                  _StepItem(
                    text: 'この下の「CSVをインポートする」からダウンロードした CSV を選択',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/import'),
            icon: const Icon(Icons.upload_file),
            label: const Text('CSVをインポートする'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B900),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              textStyle: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/user-manual'),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('マニュアルで詳しい手順を見る'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              textStyle: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: Color(0xFF16A34A), height: 1.5),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

export function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value.trim());
}

/// service role だけが、定期投稿ログを実ユーザー所有へ束ねられる。
/// 通常ユーザーからの ownerUserId 偽装は常に無視する。
export function resolveXLogOwnerUserId(
  actorUserId: string,
  requestedOwnerUserId: string,
): string {
  if (actorUserId === "service_role" && isUuid(requestedOwnerUserId)) {
    return requestedOwnerUserId.trim();
  }
  return actorUserId;
}

/// x.post の x_post_log 所有者を決める(読み取りスコープと対称化する)。
///
/// 実バグ: xReadScopeUserId は X operator を "service_role" スコープへマップして
/// performance_context / metrics cron を読むのに、書き込み(x_post_log 所有者)は
/// resolveXLogOwnerUserId が operator の UUID のままにしていた。結果、人間 operator
/// が投稿する系列(選挙集計 tally / 両党地力差 gap / AIツール / 選挙 delta =
/// admin panel or 選挙ページ経由)は operator UUID で記録され、"service_role" を
/// 走査する metrics cron から漏れ、Archetype lift / variant ranking に永久に
/// 入らなかった(計測ループが該当系列を黙って取りこぼす)。
///
/// 対称化: X operator の投稿は共有グロースアカウント(= "service_role" スコープ)へ
/// 束ねる。ただし service_role actor が per-user consent(家計トラッカー)で明示
/// ownerUserId を渡す経路は従来どおり実ユーザー所有を尊重する。通常ユーザーが
/// 自分のページを共有する経路は自分のスコープのまま(対称)。
export function resolveXPostLogOwner(
  actorUserId: string,
  requestedOwnerUserId: string,
  actorIsOperator: boolean,
): string {
  // service_role cron: 家計トラッカー等の per-user 所有束ねを尊重する。
  if (actorUserId === "service_role") {
    return resolveXLogOwnerUserId(actorUserId, requestedOwnerUserId);
  }
  // 人間 X operator: 共有グロースアカウントのスコープへ(読み取りと対称)。
  if (actorIsOperator) {
    return "service_role";
  }
  // 通常ユーザー: 自分のページ共有は自分のスコープのまま。
  return resolveXLogOwnerUserId(actorUserId, requestedOwnerUserId);
}

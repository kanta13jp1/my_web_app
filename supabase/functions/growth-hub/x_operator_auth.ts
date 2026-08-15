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

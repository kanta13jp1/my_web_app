export type VideoCreditPack = {
  key: "starter" | "creator" | "studio";
  name: string;
  description: string;
  credits: number;
  amountJpy: number;
};

export const VIDEO_CREDIT_PACKS: readonly VideoCreditPack[] = [
  {
    key: "starter",
    name: "スターター",
    description: "まず1本を試すための500クレジット",
    credits: 500,
    amountJpy: 500,
  },
  {
    key: "creator",
    name: "クリエイター",
    description: "継続制作向けの1,200クレジット",
    credits: 1200,
    amountJpy: 1000,
  },
  {
    key: "studio",
    name: "スタジオ",
    description: "まとめて制作するための3,000クレジット",
    credits: 3000,
    amountJpy: 2400,
  },
] as const;

export function videoCreditPack(value: unknown): VideoCreditPack | null {
  const key = typeof value === "string" ? value.trim().toLowerCase() : "";
  return VIDEO_CREDIT_PACKS.find((pack) => pack.key === key) ?? null;
}

export function videoCreditPackMetadata(
  userId: string,
  pack: VideoCreditPack,
): Record<string, string> {
  return {
    offer: "video_credit_pack",
    user_id: userId,
    video_credit_pack_key: pack.key,
    video_credits: String(pack.credits),
    amount_jpy: String(pack.amountJpy),
  };
}

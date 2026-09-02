import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  videoCreditPack,
  videoCreditPackMetadata,
} from "./video_credit_packs.ts";

Deno.test("video credit packs are fixed server-side", () => {
  assertEquals(videoCreditPack("creator"), {
    key: "creator",
    name: "クリエイター",
    description: "継続制作向けの1,200クレジット",
    credits: 1200,
    amountJpy: 1000,
  });
  assertEquals(videoCreditPack("client-defined"), null);
});

Deno.test("Stripe metadata is derived from the selected server pack", () => {
  const pack = videoCreditPack("starter")!;
  assertEquals(videoCreditPackMetadata("user-1", pack), {
    offer: "video_credit_pack",
    user_id: "user-1",
    video_credit_pack_key: "starter",
    video_credits: "500",
    amount_jpy: "500",
  });
});

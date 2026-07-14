import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  isUuid,
  resolveXLogOwnerUserId,
  resolveXPostLogOwner,
} from "./x_operator_auth.ts";

const OWNER = "123e4567-e89b-42d3-a456-426614174000";

Deno.test("only service role may bind an X log to an owner", () => {
  assertEquals(resolveXLogOwnerUserId("service_role", OWNER), OWNER);
  assertEquals(
    resolveXLogOwnerUserId("user-a", OWNER),
    "user-a",
  );
  assertEquals(
    resolveXLogOwnerUserId("service_role", "../../spoof"),
    "service_role",
  );
});

Deno.test("operator owner IDs use strict UUID syntax", () => {
  assertEquals(isUuid(OWNER), true);
  assertEquals(isUuid(""), false);
  assertEquals(isUuid("service_role"), false);
});

Deno.test("x.post log owner is symmetric with the read scope", () => {
  // 人間 operator の投稿は共有グロースアカウント(service_role)へ束ねる。
  // これが無いと tally/gap/ai_tool/delta 系列が metrics cron から漏れる。
  assertEquals(resolveXPostLogOwner(OWNER, "", true), "service_role");
  // operator が ownerUserId を偽装しても共有スコープへ束ねる(実ユーザー所有に
  // 逃がさない = 読み取りと対称)。
  assertEquals(
    resolveXPostLogOwner(OWNER, OWNER, true),
    "service_role",
  );
  // service_role cron: per-user consent(家計トラッカー)の束ねは尊重する。
  assertEquals(
    resolveXPostLogOwner("service_role", OWNER, true),
    OWNER,
  );
  // service_role cron で owner 未指定なら service_role スコープ。
  assertEquals(
    resolveXPostLogOwner("service_role", "", true),
    "service_role",
  );
  // 通常ユーザー(非 operator)は自分のスコープのまま(対称)。
  const other = "223e4567-e89b-42d3-a456-426614174000";
  assertEquals(resolveXPostLogOwner(other, "", false), other);
});

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ACCESS_TIER_LABELS,
  AdaptiveGeoRbacGuard,
  extractCountryCode,
} from "./adaptive_geo_rbac.ts";

Deno.test(
  "extractCountryCode reads cf-ipcountry or x-country-code safely",
  () => {
    const h1 = new Headers({ "cf-ipcountry": "jp" });
    const h2 = new Headers({ "x-country-code": "de" });
    const h3 = new Headers({ "cf-ipcountry": "XX" });
    assertEquals(extractCountryCode(h1), "JP");
    assertEquals(extractCountryCode(h2), "DE");
    assertEquals(extractCountryCode(h3), "UNKNOWN");
    assertEquals(ACCESS_TIER_LABELS.step_up_challenge, "Step-Up Challenge");
  },
);

Deno.test(
  "secondary burst escalates progressively without affecting primary region",
  () => {
    const guard = new AdaptiveGeoRbacGuard({
      primaryRegions: ["JP"],
      windowMs: 60_000,
      primaryLimit: 100,
      secondaryElevatedThreshold: 3,
      secondaryChallengeThreshold: 5,
    });

    const extHeaders = new Headers({ "cf-ipcountry": "US" });
    const jpHeaders = new Headers({ "cf-ipcountry": "JP" });

    assertEquals(guard.evaluate(extHeaders, "bot-1", 1000).tier, "normal");
    assertEquals(guard.evaluate(extHeaders, "bot-1", 1100).tier, "normal");
    assertEquals(
      guard.evaluate(extHeaders, "bot-1", 1200).tier,
      "elevated_rate_limit",
    );
    assertEquals(
      guard.evaluate(extHeaders, "bot-1", 1300).tier,
      "elevated_rate_limit",
    );

    const challenged = guard.evaluate(extHeaders, "bot-1", 1400);
    assertEquals(challenged.tier, "step_up_challenge");
    assertEquals(challenged.requiresStepUp, true);

    // Primary region client remains fast and unaffected.
    const domestic = guard.evaluate(jpHeaders, "user-jp", 1450);
    assertEquals(domestic.tier, "normal");
    assertEquals(domestic.isPrimaryRegion, true);
    assertEquals(domestic.requiresStepUp, false);
  },
);

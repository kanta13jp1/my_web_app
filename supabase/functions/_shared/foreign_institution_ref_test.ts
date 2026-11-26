import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ForeignInstitutionRefRegistry,
  INSTITUTION_CATEGORY_LABELS,
  validateOfficialUrl,
} from "./foreign_institution_ref.ts";

Deno.test(
  "validateOfficialUrl accepts http(s) and rejects invalid schemes",
  () => {
    assertEquals(
      validateOfficialUrl("https://ndlsearch.ndl.go.jp/example"),
      "https://ndlsearch.ndl.go.jp/example",
    );
    assertThrows(() => validateOfficialUrl(""));
    assertThrows(() => validateOfficialUrl("javascript:alert(1)"));
    assertThrows(() => validateOfficialUrl("not-a-url"));
  },
);

Deno.test(
  "registry filters by country and supports speech ID reverse lookup",
  () => {
    const registry = new ForeignInstitutionRefRegistry();
    registry.registerEntry({
      id: "de-1",
      countryCode: "de",
      countryName: "Germany",
      category: "oversight",
      title: "Basic Law Art. 115a",
      summary: "State of defense joint committee oversight rules.",
      officialUrl: "https://www.gesetze-im-internet.de/englisch_gg/",
      citedSpeechIds: ["speech-101", "speech-205"],
    });
    registry.registerEntry({
      id: "gb-1",
      countryCode: "GB",
      countryName: "United Kingdom",
      category: "emergency_decree",
      title: "Civil Contingencies Act 2004",
      summary: "Temporary emergency regulations require parliamentary vote.",
      officialUrl: "https://www.legislation.gov.uk/ukpga/2004/36/contents",
      citedSpeechIds: ["speech-205"],
    });

    assertEquals(registry.filterByCountry("DE").length, 1);
    assertEquals(registry.filterByCountry().length, 2);
    assertEquals(registry.findBySpeechId("speech-205").length, 2);
    assertEquals(registry.findBySpeechId("speech-101")[0].id, "de-1");
    assertEquals(INSTITUTION_CATEGORY_LABELS.term_extension, "Term Extension");
  },
);

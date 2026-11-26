import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { classifyPostArchetype } from "../growth-hub/x_post_archetype.ts";
import type {
  HubDataRow,
  JsonRecord,
  LocalElectionHubStore,
} from "./snapshot_history.ts";
import {
  parseReiwaMemberPageHtml,
  persistReiwaSnapshot,
  REIWA_DATASET,
  REIWA_MEMBER_PAGE_URL,
  type ReiwaMemberSnapshot,
  REIWA_TRACKER_VARIANT,
} from "./reiwa_tracker.ts";

// Real HTML captured verbatim from https://reiwa-shinsengumi.com/member/ (2026-11-23)
// Covers 衆議院議員..顧問 including 49 incumbents (with honokasuzuki sibling-<p> caption & non-/member/ URLs).
const REAL_REIWA_MEMBER_CORE_HTML = `
<h2 class="wp-block-heading has-white-color has-text-color has-background" id="衆議院議員" style="background-color:#e4007f">衆議院議員</h2>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/san2025_georgeyamamoto/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2026/02/jouji-yamamoto-1024x576.jpg" alt="" class="wp-image-27676" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2026/02/jouji-yamamoto-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/02/jouji-yamamoto-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/02/jouji-yamamoto-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/02/jouji-yamamoto-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/02/jouji-yamamoto-2048x1152.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">衆議院議員 山本ジョージ（代表 / 選挙対策委員長）</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<h2 class="wp-block-heading has-white-color has-text-color has-background" id="参議院議員" style="background-color:#e4007f">参議院議員</h2>



<div class="wp-block-columns has-2-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/san2025_kenjiisezaki/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2026/05/isezaki_kenji2026-01（new）-1024x576.png" alt="" class="wp-image-28371" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2026/05/isezaki_kenji2026-01（new）-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/05/isezaki_kenji2026-01（new）-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/05/isezaki_kenji2026-01（new）-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/05/isezaki_kenji2026-01（new）.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">参議院議員 伊勢崎賢治（副代表 / 政策審議会長 / 国会対策委員長 / 参議院国会対策委員長）</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/san2025_fumiyookuda/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/07/okudda_20250729-1024x576.jpg" alt="" class="wp-image-25511" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/07/okudda_20250729-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/07/okudda_20250729-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/07/okudda_20250729-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/07/okudda_20250729-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/07/okudda_20250729-2048x1152.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">参議院議員 奥田ふみよ（副代表）</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/daisuketenbata20220617/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2022/07/tenbata20220726-1024x576.jpg" alt="" class="wp-image-12581" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2022/07/tenbata20220726-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2022/07/tenbata20220726-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2022/07/tenbata20220726-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2022/07/tenbata20220726-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2022/07/tenbata20220726-2048x1152.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">参議院議員 天畠大輔（共同代表）</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/kusuooshima/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/01/ooshima_kusuo-04-1024x576.png" alt="" class="wp-image-14330" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/01/ooshima_kusuo-04-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/01/ooshima_kusuo-04-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/01/ooshima_kusuo-04-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/01/ooshima_kusuo-04-1536x864.png 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/01/ooshima_kusuo-04-2048x1152.png 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">参議院議員 大島九州男</figcaption></figure>



<div style="height:31px" aria-hidden="true" class="wp-block-spacer"></div>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/eikokimura/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/05/kimura_eiko_202505-1024x576.png" alt="" class="wp-image-24046" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/05/kimura_eiko_202505-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/05/kimura_eiko_202505-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/05/kimura_eiko_202505-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/05/kimura_eiko_202505.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">参議院議員 木村英子</figcaption></figure>
</div>
</div>











<div class="wp-block-group"><div class="wp-block-group__inner-container is-layout-flow wp-block-group-is-layout-flow">
<h2 class="wp-block-heading has-white-color has-text-color has-background" id="自治体議員" style="background-color:#e4007f">れいわの自治体議員</h2>



<div class="wp-block-buttons is-layout-flex wp-block-buttons-is-layout-flex">
<div class="wp-block-button"><a class="wp-block-button__link has-background wp-element-button" href="#北海道" style="background-color:#e4007f">北海道</a></div>



<div class="wp-block-button"><a class="wp-block-button__link has-background wp-element-button" href="#東北" style="background-color:#e4007f">東北</a></div>



<div class="wp-block-button"><a class="wp-block-button__link has-white-color has-text-color has-background wp-element-button" href="#北陸信越" style="background-color:#e4007f">北陸信越</a></div>



<div class="wp-block-button"><a class="wp-block-button__link has-background wp-element-button" href="#北関東" style="background-color:#e4007f">北関東</a></div>



<div class="wp-block-button"><a class="wp-block-button__link has-background wp-element-button" href="#東京" style="background-color:#e4007f">東京</a></div>



<div class="wp-block-button"><a class="wp-block-button__link has-background wp-element-button" href="#南関東" style="background-color:#e4007f">南関東</a></div>



<div class="wp-block-button"><a class="wp-block-button__link has-background wp-element-button" href="#東海" style="background-color:#e4007f">東海</a></div>



<div class="wp-block-button"><a class="wp-block-button__link has-background wp-element-button" href="#近畿" style="background-color:#e4007f">近畿</a></div>



<div class="wp-block-button"><a class="wp-block-button__link has-background wp-element-button" href="#中国" style="background-color:#e4007f">中国</a></div>



<div class="wp-block-button"><a class="wp-block-button__link has-background wp-element-button" href="#四国" style="background-color:#e4007f">四国</a></div>



<div class="wp-block-button"><a class="wp-block-button__link has-background wp-element-button" href="#九州沖縄" style="background-color:#e4007f">九州・沖縄</a></div>
</div>



<h2 class="wp-block-heading" id="北海道">北海道</h2>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai20236_kazuosasaki/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/06/jichitai202306f-3-1024x576.jpg" alt="" class="wp-image-17706" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/06/jichitai202306f-3-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/06/jichitai202306f-3-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/06/jichitai202306f-3-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/06/jichitai202306f-3.jpg 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">北海道・深川市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<h2 class="wp-block-heading" id="東北">東北</h2>



<p><strong>岩手県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai20234_toyokonawate/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/12/nawate_toyoko2025NEW-1024x576.png" alt="" class="wp-image-26797" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/12/nawate_toyoko2025NEW-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/12/nawate_toyoko2025NEW-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/12/nawate_toyoko2025NEW-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/12/nawate_toyoko2025NEW.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">岩手県・盛岡市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<h2 class="wp-block-heading" id="北陸信越">北陸信越</h2>



<p><strong>長野県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_kannatakemoto/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaitakemoto-1024x576.jpg" alt="" class="wp-image-17364" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaitakemoto-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaitakemoto-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaitakemoto-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaitakemoto.jpg 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">長野県・下諏訪町議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<h2 class="wp-block-heading" id="北関東">北関東</h2>



<p><strong>埼玉県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_makotokoizumi/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-25-1024x576.jpg" alt="" class="wp-image-17085" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-25-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-25-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-25-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-25-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-25.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">埼玉県・深谷市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<p><strong>茨城県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://amishinbun.jimdofree.com/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2022/06/umino-01-1024x576.jpg" alt="" class="wp-image-12404" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2022/06/umino-01-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2022/06/umino-01-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2022/06/umino-01-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2022/06/umino-01-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2022/06/umino-01-2048x1152.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">茨城県・阿見町議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_daiidesawa/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/04/jichitaigiin20230430-4-1024x576.jpg" alt="" class="wp-image-17037" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/04/jichitaigiin20230430-4-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/04/jichitaigiin20230430-4-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/04/jichitaigiin20230430-4-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/04/jichitaigiin20230430-4-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/04/jichitaigiin20230430-4.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">茨城県・牛久市議会議員</figcaption></figure>
</div>
</div>



<h2 class="wp-block-heading" id="東京">東京</h2>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_reikoishii/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-6-1024x576.jpg" alt="" class="wp-image-17066" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-6-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-6-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-6-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-6-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-6.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・三鷹市議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_kazutomoterada/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-8-1024x576.jpg" alt="" class="wp-image-17068" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-8-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-8-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-8-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-8-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-8.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・大田区議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_tsukasasato/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-13-1024x576.jpg" alt="" class="wp-image-17073" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-13-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-13-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-13-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-13-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-13.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・北区議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_genjiiseki/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-15-1024x576.jpg" alt="" class="wp-image-17075" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-15-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-15-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-15-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-15-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-15.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・中野区議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_shigekazunakakura/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/06/jichitai2023kodaira-1024x576.jpg" alt="" class="wp-image-17943" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/06/jichitai2023kodaira-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/06/jichitai2023kodaira-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/06/jichitai2023kodaira-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/06/jichitai2023kodaira.jpg 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・小平市議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_megumisawai/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-22-1024x576.jpg" alt="" class="wp-image-17082" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-22-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-22-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-22-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-22-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-22.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・新宿区議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_mayumitakahashi/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/takahashi_mayumi-20250820-1-1024x576.png" alt="" class="wp-image-25764" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/takahashi_mayumi-20250820-1-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/takahashi_mayumi-20250820-1-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/takahashi_mayumi-20250820-1-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/takahashi_mayumi-20250820-1.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・足立区議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_honokasuzuki/"><img decoding="async" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/06/jichitai2023042301-1-1024x576.jpg" alt=""/></a></figure>



<p>東京都・調布市議会議員</p>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_keijiroumori/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-7-1024x576.jpg" alt="" class="wp-image-17067" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-7-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-7-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-7-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-7-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-7.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・港区議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_kanakoyamana/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-9-1024x576.jpg" alt="" class="wp-image-17069" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-9-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-9-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-9-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-9-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-9.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・杉並区議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_fumiotakano/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-14-1024x576.jpg" alt="" class="wp-image-17074" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-14-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-14-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-14-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-14-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-14.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・国分寺市議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_satoshiyanagisawa/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-16-1024x576.jpg" alt="" class="wp-image-17076" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-16-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-16-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-16-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-16-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-16.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・品川区議会議員</figcaption></figure>



<figure class="wp-block-image size-large is-resized is-style-default"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_junkofusawa/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-18-1024x576.jpg" alt="" class="wp-image-17078" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-18-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-18-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-18-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-18-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-18.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・台東区議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_fumihitonakao/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2026/06/nakao_fumihito_20260619-1-1024x576.png" alt="" class="wp-image-28943" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2026/06/nakao_fumihito_20260619-1-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/06/nakao_fumihito_20260619-1-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/06/nakao_fumihito_20260619-1-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/06/nakao_fumihito_20260619-1.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・昭島市議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_akikoyamaguchi/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitai2023042301-2-1-1024x576.jpg" alt="" class="wp-image-17453" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitai2023042301-2-1-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitai2023042301-2-1-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitai2023042301-2-1-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitai2023042301-2-1-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitai2023042301-2-1.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・練馬区議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2024_yousukemurakami/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/04/murakami_yousuke20250405b-1024x576.png" alt="" class="wp-image-23690" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/04/murakami_yousuke20250405b-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/04/murakami_yousuke20250405b-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/04/murakami_yousuke20250405b-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/04/murakami_yousuke20250405b.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">東京都・小金井市議会議員</figcaption></figure>
</div>
</div>



<h2 class="wp-block-heading" id="南関東">南関東</h2>



<p><strong>千葉県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_keikomiyake/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-11-1024x576.jpg" alt="" class="wp-image-17071" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-11-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-11-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-11-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-11-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-11.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">千葉県・船橋市議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_tomohirowakasa/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/02/wakasa_tomohiro-7new-07-1024x576.png" alt="" class="wp-image-23176" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/02/wakasa_tomohiro-7new-07-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/02/wakasa_tomohiro-7new-07-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/02/wakasa_tomohiro-7new-07-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/02/wakasa_tomohiro-7new-07.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">千葉県・柏市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_naotokadota/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230502-4-1024x576.jpg" alt="" class="wp-image-17121" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230502-4-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230502-4-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230502-4-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230502-4-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230502-4.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">千葉県・市川市議会議員</figcaption></figure>
</div>
</div>



<p><strong>山梨県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2025_tetsuyaogihara/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/11/ogihara_tetsuya_2025-04-1024x576.png" alt="" class="wp-image-26535" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/11/ogihara_tetsuya_2025-04-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/11/ogihara_tetsuya_2025-04-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/11/ogihara_tetsuya_2025-04-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/11/ogihara_tetsuya_2025-04.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">山梨県・甲州市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<h2 class="wp-block-heading" id="東海">東海</h2>



<p><strong>愛知県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_hisayonishida/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/04/jichitaigiin20230430-2-1024x576.jpg" alt="" class="wp-image-17034" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/04/jichitaigiin20230430-2-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/04/jichitaigiin20230430-2-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/04/jichitaigiin20230430-2-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/04/jichitaigiin20230430-2-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/04/jichitaigiin20230430-2.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">愛知県・豊田市議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_ryusugaya/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-21-1024x576.jpg" alt="" class="wp-image-17081" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-21-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-21-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-21-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-21-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-21.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">愛知県・豊橋市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_masakohayashi/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-2-1024x576.jpg" alt="" class="wp-image-17061" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-2-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-2-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-2-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-2-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-2.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">愛知県・豊川市議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2025_shihoyamaichi/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/06/yamaichi_shiho-20250625-1024x576.png" alt="" class="wp-image-25054" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/06/yamaichi_shiho-20250625-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/06/yamaichi_shiho-20250625-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/06/yamaichi_shiho-20250625-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/06/yamaichi_shiho-20250625.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">愛知県・西尾市議会議員</figcaption></figure>
</div>
</div>



<p><strong>岐阜県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_takashikani/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230502-2-1024x576.jpg" alt="" class="wp-image-17118" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230502-2-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230502-2-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230502-2-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230502-2-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230502-2.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">岐阜県・岐阜市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<p><strong>静岡県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_konoriinukai/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/10/inukai_konori_20251020-1024x576.png" alt="" class="wp-image-26313" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/10/inukai_konori_20251020-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/10/inukai_konori_20251020-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/10/inukai_konori_20251020-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/10/inukai_konori_20251020.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">静岡県・伊東市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<h2 class="wp-block-heading" id="近畿">近畿</h2>



<p><strong>大阪府</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2024_kaorumaki/"><img decoding="async" src="https://reiwa-shinsengumi.com/wp-content/uploads/2024/08/maki_kaoru-20240829-1024x576.png" alt=""/></a><figcaption class="wp-element-caption">大阪府・箕面市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<p><strong>兵庫県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_hiromisano/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-12-1024x576.jpg" alt="" class="wp-image-17072" style="object-fit:cover" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-12-1024x576.jpg 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-12-300x169.jpg 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-12-768x432.jpg 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-12-1536x864.jpg 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-12.jpg 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">兵庫県・西宮市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_umigoto/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/09/gotou_umi-04-1024x576.png" alt="" class="wp-image-18973" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/09/gotou_umi-04-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/09/gotou_umi-04-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/09/gotou_umi-04-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/09/gotou_umi-04.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">兵庫県・市川町議会議員</figcaption></figure>
</div>
</div>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2024_okanyahata/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/06/yahata_okan20250627-1024x576.png" alt="" class="wp-image-25106" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/06/yahata_okan20250627-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/06/yahata_okan20250627-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/06/yahata_okan20250627-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/06/yahata_okan20250627.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">兵庫県・尼崎市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<p><strong>滋賀県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2025_masayukiteramoto/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/11/teramoto_masayuki_20251101-1024x576.png" alt="" class="wp-image-26470" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/11/teramoto_masayuki_20251101-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/11/teramoto_masayuki_20251101-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/11/teramoto_masayuki_20251101-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/11/teramoto_masayuki_20251101.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">滋賀県・湖南市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<h2 class="wp-block-heading" id="中国">中国</h2>



<p><strong>山口県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_katsushitakemura/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/02/takemura_katsushi-09-1024x576.png" alt="" class="wp-image-14728" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2023/02/takemura_katsushi-09-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/02/takemura_katsushi-09-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/02/takemura_katsushi-09-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/02/takemura_katsushi-09-1536x864.png 1536w, https://reiwa-shinsengumi.com/wp-content/uploads/2023/02/takemura_katsushi-09-2048x1152.png 2048w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">山口県・下関市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<p><strong>広島県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2024_yumiyamada/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2024/04/yamada_yumi-20240501-1024x576.png" alt="" class="wp-image-20372" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2024/04/yamada_yumi-20240501-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2024/04/yamada_yumi-20240501-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2024/04/yamada_yumi-20240501-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2024/04/yamada_yumi-20240501.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">広島県・福山市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<p><strong>島根県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2025_kazutakanagashima/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/04/nagashima_kazutaka-0417-1024x576.png" alt="" class="wp-image-23805" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/04/nagashima_kazutaka-0417-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/04/nagashima_kazutaka-0417-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/04/nagashima_kazutaka-0417-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/04/nagashima_kazutaka-0417.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">島根県・出雲市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<h2 class="wp-block-heading" id="四国">四国</h2>



<p><strong>愛媛県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2024_toshifumiwatanabe/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/02/watanabe_toshifumi-20250224-1024x576.png" alt="" class="wp-image-23210" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/02/watanabe_toshifumi-20250224-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/02/watanabe_toshifumi-20250224-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/02/watanabe_toshifumi-20250224-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/02/watanabe_toshifumi-20250224.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">愛媛県・西条市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<h2 class="wp-block-heading" id="九州沖縄">九州・沖縄</h2>



<p><strong>福岡県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2023_hiroshiarimura-2/"><img decoding="async" src="https://reiwa-shinsengumi.com/wp-content/uploads/2023/05/jichitaigiin20230501-3-1024x576.jpg" alt=""/></a><figcaption class="wp-element-caption">福岡県・春日市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/jichitai2025_chikamarukawaguchi/"><img decoding="async" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/12/kawaguchi_chikamaru20251214g-1024x576.png" alt=""/></a><figcaption class="wp-element-caption">福岡県・太宰府市議会議員</figcaption></figure>
</div>
</div>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<p><strong>熊本県</strong></p>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2024_chiharumizuta/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/09/mizuta_chiharu_20250904-1-1024x576.png" alt="" class="wp-image-25881" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/09/mizuta_chiharu_20250904-1-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/09/mizuta_chiharu_20250904-1-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/09/mizuta_chiharu_20250904-1-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/09/mizuta_chiharu_20250904-1.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">熊本県・八代市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<p><strong>宮崎県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2026_ryukikawasaki/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2026/02/kawasaki_ryuki-04-2-1024x576.png" alt="" class="wp-image-27628" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2026/02/kawasaki_ryuki-04-2-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/02/kawasaki_ryuki-04-2-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/02/kawasaki_ryuki-04-2-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/02/kawasaki_ryuki-04-2.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">宮崎県・都城市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow"></div>
</div>



<p><strong>沖縄県</strong></p>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2025_moritsuguooyama/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/moritsugu_ooyama-20250804-1024x576.png" alt="" class="wp-image-25617" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/moritsugu_ooyama-20250804-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/moritsugu_ooyama-20250804-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/moritsugu_ooyama-20250804-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/moritsugu_ooyama-20250804.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">沖縄県・那覇市議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2025_tetsurotamaki/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/12/tamaki_tetsuro-20251203-1024x576.png" alt="" class="wp-image-26786" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/12/tamaki_tetsuro-20251203-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/12/tamaki_tetsuro-20251203-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/12/tamaki_tetsuro-20251203-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/12/tamaki_tetsuro-20251203.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">沖縄県・糸満市議会議員</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2025_tifanyizumi/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/izumi_tifany-20250804-1024x576.png" alt="" class="wp-image-25615" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/izumi_tifany-20250804-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/izumi_tifany-20250804-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/izumi_tifany-20250804-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/izumi_tifany-20250804.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">沖縄県・那覇市議会議員</figcaption></figure>



<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2025_yujimurakami/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/murakami_yuji-20250804-1024x576.png" alt="" class="wp-image-25616" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/murakami_yuji-20250804-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/murakami_yuji-20250804-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/murakami_yuji-20250804-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2025/08/murakami_yuji-20250804.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">沖縄県・那覇市議会議員</figcaption></figure>
</div>
</div>
</div></div>



<h2 class="wp-block-heading has-white-color has-text-color has-background" id="自治体議員選挙公認候補予定者" style="background-color:#e4007f">自治体議員選挙 公認候補予定者</h2>



<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow" style="flex-basis:100%">
<div class="wp-block-columns is-layout-flex wp-container-core-columns-is-layout-9d6595d7 wp-block-columns-is-layout-flex">
<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2026_mietawarayama/"><img loading="lazy" decoding="async" width="1024" height="576" src="https://reiwa-shinsengumi.com/wp-content/uploads/2026/06/tawarayama_mie-01-1024x576.png" alt="" class="wp-image-28878" srcset="https://reiwa-shinsengumi.com/wp-content/uploads/2026/06/tawarayama_mie-01-1024x576.png 1024w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/06/tawarayama_mie-01-300x169.png 300w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/06/tawarayama_mie-01-768x432.png 768w, https://reiwa-shinsengumi.com/wp-content/uploads/2026/06/tawarayama_mie-01.png 1334w" sizes="auto, (max-width: 1024px) 100vw, 1024px" /></a><figcaption class="wp-element-caption">沖縄県石垣市議会議員選挙 2026年9月6日告示/9月13日投票</figcaption></figure>
</div>



<div class="wp-block-column is-layout-flow wp-block-column-is-layout-flow">
<figure class="wp-block-image size-large"><a href="https://reiwa-shinsengumi.com/member/jichitai2026_nozomukakitani/"><img decoding="async" src="https://reiwa-shinsengumi.com/wp-content/uploads/2026/04/kakitani_nozomu-01-1024x576.png" alt=""/></a><figcaption class="wp-element-caption">高知県須崎市議会議員選挙 2026年10月25日告示/11月1日投票</figcaption></figure>
</div>
</div>
</div>
</div>



<h2 class="wp-block-heading has-white-color has-text-color has-background" id="顧問" style="background-color:#e4007f">顧問</h2>
`;

const PARTIAL_BROKEN_HTML = `
<h2>れいわの自治体議員</h2>
<h2>北海道</h2>
<figure><a href="https://reiwa-shinsengumi.com/member/x/"></a><figcaption>北海道・深川市議会議員</figcaption></figure>
<h2>自治体議員選挙 公認候補予定者</h2>
`;

function createMemoryStore(): {
  store: LocalElectionHubStore;
  snapshots: HubDataRow[];
  candidates: HubDataRow[];
} {
  const snapshots: HubDataRow[] = [];
  const candidates: HubDataRow[] = [];
  let seq = 0;

  const store: LocalElectionHubStore = {
    getLatestSnapshot(dataset: string): Promise<HubDataRow | null> {
      const filtered = snapshots.filter((row) =>
        row.metadata.dataset === dataset
      );
      return Promise.resolve(
        filtered.length > 0 ? filtered[filtered.length - 1] : null,
      );
    },
    findSnapshotById(id: string): Promise<HubDataRow | null> {
      return Promise.resolve(snapshots.find((row) => row.id === id) ?? null);
    },
    listRecentSnapshots(): Promise<HubDataRow[]> {
      return Promise.resolve([...snapshots]);
    },
    insertSnapshot(metadata: JsonRecord) {
      const existing = snapshots.find((row) =>
        row.metadata.dataset === metadata.dataset &&
        row.metadata.snapshot_hash === metadata.snapshot_hash
      );
      if (existing) {
        return Promise.resolve({ row: existing, created: false });
      }
      seq += 1;
      const row: HubDataRow = {
        id: `snap-${seq}`,
        source: "local_election_dataset_snapshot",
        metadata: structuredClone(metadata),
        created_at: String(metadata.observed_at ?? "2026-11-23T10:00:00.000Z"),
      };
      snapshots.push(row);
      return Promise.resolve({ row, created: true });
    },
    insertPostCandidate(metadata: JsonRecord) {
      const existing = candidates.find((row) =>
        row.metadata.candidate_key === metadata.candidate_key
      );
      if (existing) {
        return Promise.resolve({ row: existing, created: false });
      }
      seq += 1;
      const row: HubDataRow = {
        id: `cand-${seq}`,
        source: "x_post_candidate",
        metadata: structuredClone(metadata),
        created_at: String(metadata.generated_at ?? "2026-11-23T10:00:00.000Z"),
      };
      candidates.push(row);
      return Promise.resolve({ row, created: true });
    },
  };

  return { store, snapshots, candidates };
}

Deno.test(
  "parseReiwaMemberPageHtml parses exact captured HTML including sibling-<p> caption and external links",
  () => {
    const snapshot = parseReiwaMemberPageHtml(
      REAL_REIWA_MEMBER_CORE_HTML,
      REIWA_MEMBER_PAGE_URL,
    );
    assertEquals(snapshot !== null, true);
    const s = snapshot as ReiwaMemberSnapshot;
    assertEquals(s.localMembers, 49);
    assertEquals(s.activePrefectureCount, 22);
    assertEquals(s.scheduledCandidates, 2);
    assertEquals(s.houseOfRepresentatives, 1);
    assertEquals(s.houseOfCouncillors, 5);

    const chofu = s.members.find((m) =>
      m.slug === "jichitai2023_honokasuzuki"
    );
    assertEquals(chofu?.prefecture, "東京都");
    assertEquals(chofu?.assemblyLabel, "東京都・調布市議会議員");

    const ami = s.members.find((m) => m.profileUrl.includes("amishinbun"));
    assertEquals(ami?.prefecture, "茨城県");
    const dazaifu = s.members.find((m) =>
      m.slug === "jichitai2025_chikamarukawaguchi"
    );
    assertEquals(dazaifu?.prefecture, "福岡県");
  },
);

Deno.test(
  "parseReiwaMemberPageHtml fails closed on missing headings or thin member counts",
  () => {
    assertEquals(parseReiwaMemberPageHtml("<html><body>empty</body></html>"), null);
    assertEquals(parseReiwaMemberPageHtml(PARTIAL_BROKEN_HTML), null);
  },
);

Deno.test(
  "persistReiwaSnapshot creates baseline with zero candidates and deduplicates retries",
  async () => {
    const { store, snapshots, candidates } = createMemoryStore();
    const baseline = parseReiwaMemberPageHtml(
      REAL_REIWA_MEMBER_CORE_HTML,
    ) as ReiwaMemberSnapshot;

    const first = await persistReiwaSnapshot(
      store,
      baseline,
      "2026-11-23T10:30:00.000Z",
    );
    assertEquals(first.dataset, REIWA_DATASET);
    assertEquals(first.baselineCreated, true);
    assertEquals(first.snapshotCreated, true);
    assertEquals(first.deduplicated, false);
    assertEquals(first.candidateCount, 0);
    assertEquals(snapshots.length, 1);
    assertEquals(candidates.length, 0);

    const retry = await persistReiwaSnapshot(
      store,
      baseline,
      "2026-11-24T10:30:00.000Z",
    );
    assertEquals(retry.baselineCreated, false);
    assertEquals(retry.snapshotCreated, false);
    assertEquals(retry.deduplicated, true);
    assertEquals(retry.hasChanges, false);
    assertEquals(retry.candidateCount, 0);
    assertEquals(snapshots.length, 1);
    assertEquals(candidates.length, 0);
  },
);

Deno.test(
  "persistReiwaSnapshot queues HITL data_report candidate when member count changes",
  async () => {
    const { store, candidates } = createMemoryStore();
    const baseline = parseReiwaMemberPageHtml(
      REAL_REIWA_MEMBER_CORE_HTML,
    ) as ReiwaMemberSnapshot;
    const updated: ReiwaMemberSnapshot = {
      ...baseline,
      localMembers: baseline.localMembers + 1,
      prefectures: baseline.prefectures.map((p) =>
        p.prefecture === "東京都" ? { ...p, count: p.count + 1 } : p
      ),
      members: [
        ...baseline.members,
        {
          profileUrl: "https://reiwa-shinsengumi.com/member/jichitai2026_testmember/",
          slug: "jichitai2026_testmember",
          prefecture: "東京都",
          block: "東京",
          assemblyLabel: "東京都・杉並区議会議員",
        },
      ],
    };

    await persistReiwaSnapshot(store, baseline, "2026-11-23T10:30:00.000Z");
    const next = await persistReiwaSnapshot(
      store,
      updated,
      "2026-11-24T10:30:00.000Z",
    );

    assertEquals(next.hasChanges, true);
    assertEquals(next.candidateCount, 1);
    assertEquals(next.candidatesCreated, 1);
    assertEquals(candidates.length, 1);

    const meta = candidates[0].metadata;
    assertEquals(meta.status, "pending_approval");
    assertEquals(meta.requires_human_approval, true);
    assertEquals(meta.auto_publish, false);
    assertEquals(meta.variant, REIWA_TRACKER_VARIANT);
    assertEquals(meta.content_archetype, "data_report");
    assertEquals((meta.post_payload as JsonRecord).linkInReply, true);

    const lead = String(meta.text ?? "");
    const replies = (meta.reply_texts ?? []) as string[];
    assertStringIncludes(lead, "れいわ新選組 地方議員データ集計");
    assertStringIncludes(lead, "49→50人 (+1)");
    assertStringIncludes(replies[0] ?? "", "東京都・杉並区議会議員");
    assertStringIncludes(replies[1] ?? "", "https://reiwa-shinsengumi.com/member/");
    assertEquals(classifyPostArchetype(lead), "data_report");
  },
);

Deno.test(
  "persistReiwaSnapshot suppresses HITL candidate when only member label changes with zero count or roster delta",
  async () => {
    const { store, candidates } = createMemoryStore();
    const baseline = parseReiwaMemberPageHtml(
      REAL_REIWA_MEMBER_CORE_HTML,
    ) as ReiwaMemberSnapshot;
    const target = baseline.members[0];
    const updated: ReiwaMemberSnapshot = {
      ...baseline,
      members: baseline.members.map((m) =>
        m.profileUrl === target.profileUrl
          ? { ...m, assemblyLabel: `${m.assemblyLabel}（表記更新）` }
          : m
      ),
    };

    await persistReiwaSnapshot(store, baseline, "2026-11-25T10:30:00.000Z");
    const next = await persistReiwaSnapshot(
      store,
      updated,
      "2026-11-26T10:30:00.000Z",
    );

    assertEquals(next.snapshotCreated, true);
    assertEquals(next.hasChanges, false);
    assertEquals(next.candidateCount, 0);
    assertEquals(next.candidatesCreated, 0);
    assertEquals(candidates.length, 0);
  },
);

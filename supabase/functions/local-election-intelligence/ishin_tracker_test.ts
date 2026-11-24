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
  buildIshinMemberSnapshot,
  ISHIN_DATASET,
  type IshinMemberSnapshot,
  type IshinPrefecturePageResult,
  ISHIN_TRACKER_VARIANT,
  parseIshinPrefectureDirectory,
  parseIshinPrefecturePage,
  persistIshinSnapshot,
} from "./ishin_tracker.ts";

// Real <dl class="search03"> captured verbatim from https://o-ishin.jp/member/ (2026-11-23)
const REAL_ISHIN_INDEX_SELECT_HTML = `
<dl class="search03">
			    <dt><img src="https://o-ishin.jp/common/img/icon_map.png" alt="">都道府県から探す</dt>
			    <dd class="member-search__box__select">
			    	<div class="member-search__box__select__box">
				    	<select name="prefecture" id="seach18">
					    <option value="">選択してください</option>
						
							<option value="https://o-ishin.jp/member/01_hokkaido/">北海道</option>
						
							<option value="https://o-ishin.jp/member/02_aomori/">青森県</option>
						
							<option value="https://o-ishin.jp/member/03_iwate/">岩手県</option>
						
							<option value="https://o-ishin.jp/member/04_miyagi/">宮城県</option>
						
							<option value="https://o-ishin.jp/member/05_akita/">秋田県</option>
						
							<option value="https://o-ishin.jp/member/06_yamagata/">山形県</option>
						
							<option value="https://o-ishin.jp/member/07_fukushima/">福島県</option>
						
							<option value="https://o-ishin.jp/member/08_ibaraki/">茨城県</option>
						
							<option value="https://o-ishin.jp/member/09_tochigi/">栃木県</option>
						
							<option value="https://o-ishin.jp/member/10_gunma/">群馬県</option>
						
							<option value="https://o-ishin.jp/member/11_saitama/">埼玉県</option>
						
							<option value="https://o-ishin.jp/member/12_chiba/">千葉県</option>
						
							<option value="https://o-ishin.jp/member/13_tokyo/">東京都</option>
						
							<option value="https://o-ishin.jp/member/14_kanagawa/">神奈川県</option>
						
							<option value="https://o-ishin.jp/member/15_nigata/">新潟県</option>
						
							<option value="https://o-ishin.jp/member/16_toyama/">富山県</option>
						
							<option value="https://o-ishin.jp/member/17_ishikawa/">石川県</option>
						
							<option value="https://o-ishin.jp/member/18_fukui/">福井県</option>
						
							<option value="https://o-ishin.jp/member/19_yamanashi/">山梨県</option>
						
							<option value="https://o-ishin.jp/member/20_nagano/">長野県</option>
						
							<option value="https://o-ishin.jp/member/21_gifu/">岐阜県</option>
						
							<option value="https://o-ishin.jp/member/22_shizuoka/">静岡県</option>
						
							<option value="https://o-ishin.jp/member/23_aichi/">愛知県</option>
						
							<option value="https://o-ishin.jp/member/24_mie/">三重県</option>
						
							<option value="https://o-ishin.jp/member/25_shiga/">滋賀県</option>
						
							<option value="https://o-ishin.jp/member/26_kyoto/">京都府</option>
						
							<option value="https://o-ishin.jp/member/27_osaka/">大阪府</option>
						
							<option value="https://o-ishin.jp/member/28_hyougo/">兵庫県</option>
						
							<option value="https://o-ishin.jp/member/29_nara/">奈良県</option>
						
							<option value="https://o-ishin.jp/member/30_wakayama/">和歌山県</option>
						
							<option value="https://o-ishin.jp/member/31_shimane/">島根県</option>
						
							<option value="https://o-ishin.jp/member/32_tottori/">鳥取県</option>
						
							<option value="https://o-ishin.jp/member/33_okayama/">岡山県</option>
						
							<option value="https://o-ishin.jp/member/34_hiroshima/">広島県</option>
						
							<option value="https://o-ishin.jp/member/35_yamaguchi/">山口県</option>
						
							<option value="https://o-ishin.jp/member/36_tokushima/">徳島県</option>
						
							<option value="https://o-ishin.jp/member/37_kagawa/">香川県</option>
						
							<option value="https://o-ishin.jp/member/38_ehime/">愛媛県</option>
						
							<option value="https://o-ishin.jp/member/39_kochi/">高知県</option>
						
							<option value="https://o-ishin.jp/member/40_fukuoka/">福岡県</option>
						
							<option value="https://o-ishin.jp/member/41_saga/">佐賀県</option>
						
							<option value="https://o-ishin.jp/member/42_nagasaki/">長崎県</option>
						
							<option value="https://o-ishin.jp/member/43_kumamoto/">熊本県</option>
						
							<option value="https://o-ishin.jp/member/44_ooita/">大分県</option>
						
							<option value="https://o-ishin.jp/member/45_miyazaki/">宮崎県</option>
						
							<option value="https://o-ishin.jp/member/46_kagoshima/">鹿児島県</option>
						
							<option value="https://o-ishin.jp/member/47_okinawa/">沖縄県</option>
						
							<option value="https://o-ishin.jp/member/99_hirei/">比例区</option>
						
					    </select>
					</div>
			    </dd>
			    </dl>
`;

// Real 鳥取県 (4 local members) captured verbatim from https://o-ishin.jp/member/32_tottori/ (2026-11-23)
const REAL_ISHIN_TOTTORI_HTML = `
<h4 class="h4title">鳥取県</h4>
				<section class="search_member01">


            
						
              
                
              
                
                  
                  
                
              
								<div>
									
										<img src="https://o-ishin.jp/member/images/member/post_1461.jpg" />
									
									<dl>
										<dt>岸本　雄司<span>きしもと　ゆうじ</span></dt>
										<dd>
											<ul>
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											<li class="member_label04">鳥取市</li>
											
										</ul>
										</dd>
									</dl>
									<a href="https://o-ishin.jp/member/detail/post_1461.html"></a>
								</div>
					
						
              
                
              
                
                  
                  
                
              
								<div>
									
										<img src="https://o-ishin.jp/member/images/member/post_1462.jpg" />
									
									<dl>
										<dt>木村　風海<span>きむら　かざみ</span></dt>
										<dd>
											<ul>
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											<li class="member_label04">鳥取市</li>
											
										</ul>
										</dd>
									</dl>
									<a href="https://o-ishin.jp/member/detail/post_1462.html"></a>
								</div>
					
						
              
                
              
                
              
                
                  
                  
                
              
								<div>
									
										<img src="https://o-ishin.jp/member/images/member/post_262.jpg" />
									
									<dl>
										<dt>玉木　ゆういち<span>たまき　ゆういち</span></dt>
										<dd>
											<ul>
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											<li class="member_label04">鳥取市</li>
											
										</ul>
										</dd>
									</dl>
									<a href="https://o-ishin.jp/member/detail/post_262.html"></a>
								</div>
					
						
              
                
              
                
                  
                  
                
              
								<div>
									
										<img src="https://o-ishin.jp/member/images/member/post_1530.jpg" />
									
									<dl>
										<dt>西村　祐美<span>にしむら　ゆみ</span></dt>
										<dd>
											<ul>
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											<li class="member_label04">倉吉市</li>
											
										</ul>
										</dd>
									</dl>
									<a href="https://o-ishin.jp/member/detail/post_1530.html"></a>
								</div>
					

		        
                
				</section>
`;

// Representative 大阪府 cards captured verbatim from https://o-ishin.jp/member/27_osaka/ (2026-11-23)
const REAL_ISHIN_OSAKA_SAMPLE_HTML = `
<h4 class="h4title">大阪府</h4>
<section class="search_member01">
<div>
									
										<img src="https://o-ishin.jp/member/images/member/post_124.jpg" />
									
									<dl>
										<dt>あおやぎ　仁士<span>あおやぎ　ひとし</span></dt>
										<dd>
											<ul>
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											<li class="member_label02">衆議院議員</li>
											
											
											
											
											
											<li class="member_label04">大阪14区</li>
											
										</ul>
										</dd>
									</dl>
									<a href="https://o-ishin.jp/member/detail/post_124.html"></a>
								</div>
<div>
									
										<img src="https://o-ishin.jp/member/images/member/post_546.jpg" />
									
									<dl>
										<dt>安黒　よしお <span>あぐろ よしお</span></dt>
										<dd>
											<ul>
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											<li class="member_label04">池田市</li>
											
										</ul>
										</dd>
									</dl>
									<a href="https://o-ishin.jp/member/detail/post_546.html"></a>
								</div>
<div>
									
										<img src="https://o-ishin.jp/member/images/member/asada_hitoshi.jpg" />
									
									<dl>
										<dt>浅田　均<span>あさだ　ひとし</span></dt>
										<dd>
											<ul>
											
											
											
											
											
											
											
											
											
											
											
											
											<li class="member_label03">参議院議員</li>
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											<li class="member_label04">大阪府</li>
											<li class="block">維新政治塾<br>名誉塾長</li>
										</ul>
										</dd>
									</dl>
									<a href="https://o-ishin.jp/member/detail/asada_hitoshi.html"></a>
								</div>
<div>
									
										<img src="https://o-ishin.jp/member/images/member/post_501.jpg" />
									
									<dl>
										<dt>出雲　てるひで<span>いずも てるひで</span></dt>
										<dd>
											<ul>
											
											<li class="member_label01">大阪市会議員</li>
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											<li class="member_label04">大阪市大正区</li>
											
										</ul>
										</dd>
									</dl>
									<a href="https://o-ishin.jp/member/detail/post_501.html"></a>
								</div>
<div>
									
										<img src="https://o-ishin.jp/member/images/member/post_548.jpg" />
									
									<dl>
										<dt>市来 ハヤト<span>いちき はやと</span></dt>
										<dd>
											<ul>
											
											<li class="member_label01">大阪府議会議員</li>
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											<li class="member_label04">高槻市及び三島郡</li>
											
										</ul>
										</dd>
									</dl>
									<a href="https://o-ishin.jp/member/detail/post_548.html"></a>
								</div>
<div>
									
										<img src="https://o-ishin.jp/member/images/member/post_776.jpg" />
									
									<dl>
										<dt>上浦　のぼる<span>うえうら　のぼる</span></dt>
										<dd>
											<ul>
											
											<li class="member_label01">首長</li>
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											
											<li class="member_label04">豊能町</li>
											
										</ul>
										</dd>
									</dl>
									<a href="https://o-ishin.jp/member/detail/post_776.html"></a>
								</div>
</section>
`;

const REAL_ISHIN_SIBUCHO_CARD_HTML = `
<h4 class="h4title">北海道</h4>
<section class="search_member01">
<div>
  <dl>
    <dt>山崎　まこ<span>やまざき　まこ</span></dt>
    <dd><ul>
      <li class="member_label02">衆議院</li>
      <li class="member_label04">北海道2区</li>
      <li class="block">選挙区支部長</li>
    </ul></dd>
  </dl>
  <a href="https://o-ishin.jp/member/detail/post_100.html"></a>
</div>
</section>
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
        created_at: String(metadata.observed_at ?? "2026-11-23T09:00:00.000Z"),
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
        created_at: String(metadata.generated_at ?? "2026-11-23T09:00:00.000Z"),
      };
      candidates.push(row);
      return Promise.resolve({ row, created: true });
    },
  };

  return { store, snapshots, candidates };
}

function make47PagesFixture(
  osakaCount = 303,
  extraTottoriMember = false,
): IshinPrefecturePageResult[] {
  const directory = parseIshinPrefectureDirectory(REAL_ISHIN_INDEX_SELECT_HTML);
  const tottoriBase = parseIshinPrefecturePage(
    REAL_ISHIN_TOTTORI_HTML,
    "鳥取県",
    "https://o-ishin.jp/member/32_tottori/",
  );
  return directory.map((entry) => {
    if (entry.prefecture === "鳥取県") {
      const extra = extraTottoriMember
        ? [{
          detailUrl: "https://o-ishin.jp/member/detail/post_extra_tottori.html",
          name: "新田 太郎",
          prefecture: "鳥取県",
          category: "local_assembly" as const,
          roleLabel: "地方議員",
          areaLabel: "米子市",
        }]
        : [];
      return {
        ...tottoriBase,
        localMembers: [...tottoriBase.localMembers, ...extra],
      };
    }
    if (entry.prefecture === "大阪府") {
      const localMembers = Array.from({ length: osakaCount }, (_, idx) => ({
        detailUrl: `https://o-ishin.jp/member/detail/osaka_local_${idx + 1}.html`,
        name: `大阪議員${idx + 1}`,
        prefecture: "大阪府",
        category: "local_assembly" as const,
        roleLabel: idx % 3 === 0 ? "大阪府議会議員" : "大阪市会議員",
        areaLabel: "大阪市",
      }));
      localMembers.push({
        detailUrl: "https://o-ishin.jp/member/detail/osaka_mayor_1.html",
        name: "上浦 のぼる",
        prefecture: "大阪府",
        category: "governor_mayor" as const,
        roleLabel: "首長",
        areaLabel: "豊能町",
      });
      return {
        prefecture: entry.prefecture,
        sourceUrl: entry.sourceUrl,
        rawCards: localMembers.length,
        excludedDietOrBranchCount: 0,
        localMembers,
      };
    }
    if (entry.prefecture === "兵庫県") {
      const hyogo = Array.from({ length: 100 }, (_, idx) => ({
        detailUrl: `https://o-ishin.jp/member/detail/hyogo_local_${idx + 1}.html`,
        name: `兵庫議員${idx + 1}`,
        prefecture: "兵庫県",
        category: "local_assembly" as const,
        roleLabel: "兵庫県議会議員",
        areaLabel: "神戸市",
      }));
      return {
        prefecture: entry.prefecture,
        sourceUrl: entry.sourceUrl,
        rawCards: hyogo.length,
        excludedDietOrBranchCount: 0,
        localMembers: hyogo,
      };
    }
    return {
      prefecture: entry.prefecture,
      sourceUrl: entry.sourceUrl,
      rawCards: 0,
      excludedDietOrBranchCount: 0,
      localMembers: [],
    };
  });
}

Deno.test(
  "parseIshinPrefectureDirectory & parseIshinPrefecturePage exclude Diet/99_hirei/支部長 and separate 首長",
  () => {
    const directory = parseIshinPrefectureDirectory(REAL_ISHIN_INDEX_SELECT_HTML);
    assertEquals(directory.length, 47);
    assertEquals(
      directory.some((item) => item.sourceUrl.includes("99_hirei")),
      false,
    );

    const tottori = parseIshinPrefecturePage(
      REAL_ISHIN_TOTTORI_HTML,
      "鳥取県",
      "https://o-ishin.jp/member/32_tottori/",
    );
    assertEquals(tottori.rawCards, 4);
    assertEquals(tottori.excludedDietOrBranchCount, 0);
    assertEquals(tottori.localMembers.length, 4);
    assertEquals(tottori.localMembers[0].name, "岸本 雄司");
    assertEquals(tottori.localMembers[0].areaLabel, "鳥取市");

    const osaka = parseIshinPrefecturePage(
      REAL_ISHIN_OSAKA_SAMPLE_HTML,
      "大阪府",
      "https://o-ishin.jp/member/27_osaka/",
    );
    assertEquals(osaka.rawCards, 6);
    assertEquals(osaka.excludedDietOrBranchCount, 2);
    assertEquals(osaka.localMembers.length, 4);
    assertEquals(
      osaka.localMembers.filter((m) => m.category === "governor_mayor").length,
      1,
    );
    assertEquals(
      osaka.localMembers.filter((m) => m.category === "local_assembly").length,
      3,
    );

    const hokkaidoSibucho = parseIshinPrefecturePage(
      REAL_ISHIN_SIBUCHO_CARD_HTML,
      "北海道",
      "https://o-ishin.jp/member/01_hokkaido/",
      new Set(["https://o-ishin.jp/member/detail/post_100.html"]),
    );
    assertEquals(hokkaidoSibucho.excludedDietOrBranchCount, 1);
    assertEquals(hokkaidoSibucho.localMembers.length, 0);
  },
);

Deno.test(
  "buildIshinMemberSnapshot fails closed on incomplete prefectures or thin member counts",
  () => {
    const partial = make47PagesFixture().slice(0, 46);
    assertEquals(buildIshinMemberSnapshot(partial), null);

    const thin = make47PagesFixture(100);
    assertEquals(buildIshinMemberSnapshot(thin), null);

    const valid = buildIshinMemberSnapshot(make47PagesFixture());
    assertEquals(valid !== null, true);
    assertEquals((valid as IshinMemberSnapshot).localAssemblyMembers, 407);
    assertEquals((valid as IshinMemberSnapshot).governorsAndMayors, 1);
    assertEquals((valid as IshinMemberSnapshot).activePrefectureCount, 3);
    assertEquals((valid as IshinMemberSnapshot).blankPrefectures.length, 44);
  },
);

Deno.test(
  "persistIshinSnapshot creates baseline with zero candidates and deduplicates retries",
  async () => {
    const { store, snapshots, candidates } = createMemoryStore();
    const baseline = buildIshinMemberSnapshot(
      make47PagesFixture(),
    ) as IshinMemberSnapshot;

    const first = await persistIshinSnapshot(
      store,
      baseline,
      "2026-11-23T09:00:00.000Z",
    );
    assertEquals(first.dataset, ISHIN_DATASET);
    assertEquals(first.baselineCreated, true);
    assertEquals(first.snapshotCreated, true);
    assertEquals(first.deduplicated, false);
    assertEquals(first.candidateCount, 0);
    assertEquals(snapshots.length, 1);
    assertEquals(candidates.length, 0);

    const retry = await persistIshinSnapshot(
      store,
      baseline,
      "2026-11-24T09:00:00.000Z",
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
  "persistIshinSnapshot queues HITL data_report candidate when local members change",
  async () => {
    const { store, candidates } = createMemoryStore();
    const baseline = buildIshinMemberSnapshot(
      make47PagesFixture(303, false),
    ) as IshinMemberSnapshot;
    const updated = buildIshinMemberSnapshot(
      make47PagesFixture(304, true),
    ) as IshinMemberSnapshot;

    await persistIshinSnapshot(store, baseline, "2026-11-23T09:00:00.000Z");
    const next = await persistIshinSnapshot(
      store,
      updated,
      "2026-11-24T09:00:00.000Z",
    );

    assertEquals(next.hasChanges, true);
    assertEquals(next.candidateCount, 1);
    assertEquals(next.candidatesCreated, 1);
    assertEquals(candidates.length, 1);

    const meta = candidates[0].metadata;
    assertEquals(meta.status, "pending_approval");
    assertEquals(meta.requires_human_approval, true);
    assertEquals(meta.auto_publish, false);
    assertEquals(meta.variant, ISHIN_TRACKER_VARIANT);
    assertEquals(meta.content_archetype, "data_report");
    assertEquals((meta.post_payload as JsonRecord).linkInReply, true);

    const lead = String(meta.text ?? "");
    const replies = (meta.reply_texts ?? []) as string[];
    assertStringIncludes(lead, "日本維新の会 地方議員データ集計");
    assertStringIncludes(lead, "407→409人 (+2)");
    assertStringIncludes(replies[0] ?? "", "新田 太郎");
    assertStringIncludes(replies[1] ?? "", "https://o-ishin.jp/member/");
    assertEquals(classifyPostArchetype(lead), "data_report");
  },
);

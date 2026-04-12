#!/usr/bin/env python3
"""Move horseracing.* actions before auth check in tools-hub/index.ts"""

path = 'supabase/functions/tools-hub/index.ts'
with open(path, encoding='utf-8') as f:
    content = f.read()

# The horseracing block in the switch (including the comment header)
OLD_IN_SWITCH = """      // ── Horse Racing 自動化パイプライン ─────────────────────────────────────
      case "horseracing.today": {
        const targetDate = String(body.date ?? new Date().toISOString().split("T")[0]);
        const { data: races, error: re } = await admin
          .from("horse_races")
          .select("*, horse_entries(*), horse_predictions(*), horse_results(*)")
          .eq("race_date", targetDate)
          .order("post_time", { ascending: true });
        if (re) throw new Error(re.message);
        return json({ success: true, races: races ?? [], date: targetDate });
      }
      case "horseracing.list_races": {
        const { data: races, error: re } = await admin
          .from("horse_races")
          .select("*, horse_predictions(id,first_pick,second_pick,third_pick,confidence), horse_results(first_place,second_place,third_place,is_prediction_correct,trifecta_paid)")
          .order("race_date", { ascending: false })
          .limit(50);
        if (re) throw new Error(re.message);
        return json({ success: true, races: races ?? [] });
      }
      case "horseracing.predict_all": {"""

NEW_IN_SWITCH = """      case "horseracing.predict_all": {"""

# The stateless section anchor
STATELESS_ANCHOR = '    // ── Authenticated CRUD operations ────────────────────────────────────────\n    const userId = await getUserId(req);'

# New stateless horseracing block to insert before auth check
NEW_STATELESS = '''    // ── Horse Racing 自動化パイプライン (auth不要 — GitHub Actions対応) ─────────
    if (action.startsWith("horseracing.")) {
      switch (action) {
        case "horseracing.today": {
          const targetDate = String(body.date ?? new Date().toISOString().split("T")[0]);
          const { data: races, error: re } = await admin
            .from("horse_races")
            .select("*, horse_entries(*), horse_predictions(*), horse_results(*)")
            .eq("race_date", targetDate)
            .order("post_time", { ascending: true });
          if (re) throw new Error(re.message);
          return json({ success: true, races: races ?? [], date: targetDate });
        }
        case "horseracing.list_races": {
          const { data: races, error: re } = await admin
            .from("horse_races")
            .select("*, horse_predictions(id,first_pick,second_pick,third_pick,confidence), horse_results(first_place,second_place,third_place,is_prediction_correct,trifecta_paid)")
            .order("race_date", { ascending: false })
            .limit(50);
          if (re) throw new Error(re.message);
          return json({ success: true, races: races ?? [] });
        }
        case "horseracing.predict_all": {
          const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
          if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
          const targetDate = String(body.date ?? new Date().toISOString().split("T")[0]);
          const { data: races } = await admin.from("horse_races")
            .select("*, horse_entries(*), horse_predictions(id)")
            .eq("race_date", targetDate).eq("status", "scheduled");
          if (!races || races.length === 0) return json({ success: true, predictions: [], message: "本日のレースなし" });
          // deno-lint-ignore no-explicit-any
          const unpredicted = races.filter((r: any) => !r.horse_predictions || r.horse_predictions.length === 0);
          if (unpredicted.length === 0) return json({ success: true, predictions: [], message: "全レース予想済" });
          const results = [];
          for (const race of unpredicted) {
            // deno-lint-ignore no-explicit-any
            const entries = (race.horse_entries as any[]) ?? [];
            if (entries.length < 3) continue;
            const entryText = entries.map((e) =>
              `馬番${e.horse_number} ${e.horse_name} (騎手:${e.jockey ?? "不明"}, 単勝${e.win_odds ?? "?"}倍, ${e.popularity ?? "?"}番人気)`
            ).join("\\n");
            const prompt = `競馬レース「${race.race_name}」(${race.venue ?? ""}/${race.course_type ?? "芝"}${race.distance ?? ""}m/${race.grade ?? ""}) の3連単予想をしてください。\\n出走馬:\\n${entryText}\\n\\nJSON形式で回答: {"first":"予想馬名1","second":"予想馬名2","third":"予想馬名3","confidence":0.0,"reasoning":"根拠"}`;
            try {
              const res = await fetch(
                `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
                { method: "POST", headers: { "Content-Type": "application/json" },
                  body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }) }
              );
              const aiData = await res.json() as { candidates?: [{ content: { parts: [{ text: string }] } }] };
              const text = aiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
              const pred = JSON.parse(text.replace(/```json\\n?|\\n?```/g, "").trim());
              const { error: ie } = await admin.from("horse_predictions").upsert({
                race_id: race.id, first_pick: pred.first ?? entries[0].horse_name,
                second_pick: pred.second ?? entries[1].horse_name,
                third_pick: pred.third ?? entries[2].horse_name,
                confidence: pred.confidence ?? 0.5, ai_reasoning: pred.reasoning ?? "",
                ai_model: "gemini-2.5-flash",
              }, { onConflict: "race_id" });
              if (!ie) results.push({ race_id: race.id, race_name: race.race_name, ...pred });
            } catch { /* ignore per-race errors */ }
          }
          return json({ success: true, predictions: results, count: results.length });
        }
        case "horseracing.predictions": {
          const { data: preds, error: pe } = await admin.from("horse_predictions")
            .select("*, horse_races(race_name,race_date,venue,grade,course_type,distance)")
            .order("created_at", { ascending: false }).limit(Number(body.limit ?? 50));
          if (pe) throw new Error(pe.message);
          const raceIds = (preds ?? []).map((p: Record<string, unknown>) => p.race_id as string).filter(Boolean);
          const resultsMap: Record<string, unknown> = {};
          if (raceIds.length > 0) {
            const { data: hrs } = await admin.from("horse_results")
              .select("race_id,first_place,second_place,third_place,trifecta_paid,is_prediction_correct")
              .in("race_id", raceIds);
            (hrs ?? []).forEach((r: Record<string, unknown>) => { resultsMap[r.race_id as string] = r; });
          }
          const enriched = (preds ?? []).map((p: Record<string, unknown>) => ({
            ...p, horse_results: resultsMap[p.race_id as string] ?? null,
          }));
          return json({ success: true, predictions: enriched });
        }
        case "horseracing.store_results": {
          const raceId = String(body.race_id ?? "");
          if (!raceId) return json({ error: "race_id required" }, 400);
          const pred = await admin.from("horse_predictions").select("first_pick,second_pick,third_pick").eq("race_id", raceId).maybeSingle();
          const isCorrect = pred.data
            ? (pred.data.first_pick === body.first_place && pred.data.second_pick === body.second_place && pred.data.third_pick === body.third_place)
            : null;
          const { error: re } = await admin.from("horse_results").upsert({
            race_id: raceId, first_place: body.first_place, second_place: body.second_place,
            third_place: body.third_place, trifecta_paid: body.trifecta_paid ?? null,
            winner_odds: body.winner_odds ?? null, is_prediction_correct: isCorrect,
          }, { onConflict: "race_id" });
          await admin.from("horse_races").update({ status: "completed" }).eq("id", raceId);
          if (re) throw new Error(re.message);
          return json({ success: true, is_correct: isCorrect });
        }
        case "horseracing.accuracy": {
          const { data: stats } = await admin.from("horse_accuracy_stats").select("*").maybeSingle();
          const { data: recentHits } = await admin.from("horse_results")
            .select("race_id, is_prediction_correct, trifecta_paid, horse_races(race_name, race_date)")
            .eq("is_prediction_correct", true).order("fetched_at", { ascending: false }).limit(5);
          return json({ success: true, stats: stats ?? {}, recent_hits: recentHits ?? [] });
        }
        case "horseracing.register_race": {
          const { data: r, error: re } = await admin.from("horse_races").insert({
            source: "manual", race_name: String(body.name ?? ""),
            race_date: String(body.date ?? new Date().toISOString().split("T")[0]),
            venue: body.venue ?? null, course_type: body.race_type ?? "芝",
            grade: body.grade ?? "未勝利", distance: body.distance ?? null, status: "scheduled",
          }).select("id").single();
          if (re) throw new Error(re.message);
          return json({ success: true, race_id: r?.id });
        }
        case "horseracing.stats": {
          const { data: stats } = await admin.from("horse_accuracy_stats").select("*").maybeSingle();
          return json({ success: true, stats: {
            totalBets: stats?.total_predictions ?? 0, wins: stats?.correct_count ?? 0,
            winRate: stats?.hit_rate_pct ?? 0, totalPayout: stats?.total_payout ?? 0,
            maxPayout: stats?.max_payout ?? 0,
          }});
        }
        default:
          return json({ error: `Unknown horseracing action: ${action}` }, 400);
      }
    }

    '''

# Remove the horseracing block from the switch statement
# Find the exact range to remove
START_MARK = '      // ── Horse Racing 自動化パイプライン ─────────────────────────────────────'
END_MARK = '      case "horseracing.stats": {\n        const { data: stats } = await admin.from("horse_accuracy_stats").select("*").maybeSingle();\n        return json({ success: true, stats: {\n          totalBets: stats?.total_predictions ?? 0, wins: stats?.correct_count ?? 0,\n          winRate: stats?.hit_rate_pct ?? 0, totalPayout: stats?.total_payout ?? 0,\n          maxPayout: stats?.max_payout ?? 0,\n        }});\n      }'

assert START_MARK in content, "START_MARK not found"
assert END_MARK in content, "END_MARK not found"

# Remove the old horseracing block from switch
start_idx = content.index(START_MARK)
end_idx = content.index(END_MARK) + len(END_MARK)
content = content[:start_idx] + content[end_idx:]

# Insert new stateless block before auth check
assert STATELESS_ANCHOR in content, "STATELESS_ANCHOR not found"
content = content.replace(STATELESS_ANCHOR, NEW_STATELESS + STATELESS_ANCHOR, 1)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Done.")

#!/usr/bin/env python3
"""Replace old horse racing section in tools-hub with new automated pipeline."""
import sys

f = "supabase/functions/tools-hub/index.ts"
content = open(f, encoding="utf-8").read()

start_marker = "      // \u2500\u2500 Horse Racing Predictor"
end_before = "\n      default:"
start_idx = content.find(start_marker)
end_idx = content.find(end_before, start_idx)

if start_idx == -1 or end_idx == -1:
    # Check if already replaced
    if "horseracing.today" in content:
        print("ALREADY_REPLACED")
        sys.exit(0)
    print(f"ERROR markers not found. start={start_idx} end={end_idx}")
    sys.exit(1)

new_section = (
    "      // \u2500\u2500 Horse Racing \u81ea\u52d5\u5316\u30d1\u30a4\u30d7\u30e9\u30a4\u30f3"
    " \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    '      case "horseracing.today": {\n'
    "        const targetDate = String(body.date ?? new Date().toISOString().split(\"T\")[0]);\n"
    "        const { data: races, error: re } = await admin\n"
    '          .from("horse_races")\n'
    '          .select("*, horse_entries(*), horse_predictions(*), horse_results(*)")\n'
    '          .eq("race_date", targetDate)\n'
    '          .order("post_time", { ascending: true });\n'
    "        if (re) throw new Error(re.message);\n"
    "        return json({ success: true, races: races ?? [], date: targetDate });\n"
    "      }\n"
    '      case "horseracing.list_races": {\n'
    "        const { data: races, error: re } = await admin\n"
    '          .from("horse_races")\n'
    '          .select("*, horse_predictions(id,first_pick,second_pick,third_pick,confidence), horse_results(first_place,second_place,third_place,is_prediction_correct,trifecta_paid)")\n'
    '          .order("race_date", { ascending: false })\n'
    "          .limit(50);\n"
    "        if (re) throw new Error(re.message);\n"
    "        return json({ success: true, races: races ?? [] });\n"
    "      }\n"
    '      case "horseracing.predict_all": {\n'
    '        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";\n'
    '        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);\n'
    "        const targetDate = String(body.date ?? new Date().toISOString().split(\"T\")[0]);\n"
    "        const { data: races } = await admin.from(\"horse_races\")\n"
    '          .select("*, horse_entries(*), horse_predictions(id)")\n'
    '          .eq("race_date", targetDate).eq("status", "scheduled");\n'
    "        if (!races || races.length === 0) return json({ success: true, predictions: [], message: \"\u672c\u65e5\u306e\u30ec\u30fc\u30b9\u306a\u3057\" });\n"
    "        // deno-lint-ignore no-explicit-any\n"
    "        const unpredicted = races.filter((r: any) => !r.horse_predictions || r.horse_predictions.length === 0);\n"
    "        if (unpredicted.length === 0) return json({ success: true, predictions: [], message: \"\u5168\u30ec\u30fc\u30b9\u4e88\u60f3\u6e08\" });\n"
    "        const results = [];\n"
    "        for (const race of unpredicted) {\n"
    "          // deno-lint-ignore no-explicit-any\n"
    "          const entries = (race.horse_entries as any[]) ?? [];\n"
    "          if (entries.length < 3) continue;\n"
    "          const entryText = entries.map((e) =>\n"
    "            `\u99ac\u756a${e.horse_number} ${e.horse_name} (\u9a0e\u624b:${e.jockey ?? \"\u4e0d\u660e\"}, \u5358\u52dd${e.win_odds ?? \"?\"}\u500d, ${e.popularity ?? \"?\"}\u756a\u4eba\u6c17)`\n"
    "          ).join(\"\\n\");\n"
    "          const prompt = `\u7af6\u99ac\u30ec\u30fc\u30b9\u300c${race.race_name}\u300d(${race.venue ?? \"\"}/${race.course_type ?? \"\u82dd\"}${race.distance ?? \"\"}m/${race.grade ?? \"\"}) \u306e3\u9023\u5358\u4e88\u60f3\u3092\u3057\u3066\u304f\u3060\u3055\u3044\u3002\\n\u51fa\u8d70\u99ac:\\n${entryText}\\n\\nJSON\u5f62\u5f0f\u3067\u56de\u7b54: {\"first\":\"\u4e88\u60f3\u99ac\u540d1\",\"second\":\"\u4e88\u60f3\u99ac\u540d2\",\"third\":\"\u4e88\u60f3\u99ac\u540d3\",\"confidence\":0.0,\"reasoning\":\"\u6839\u62e0\"}`;\n"
    "          try {\n"
    "            const res = await fetch(\n"
    "              `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,\n"
    "              { method: \"POST\", headers: { \"Content-Type\": \"application/json\" },\n"
    "                body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }) }\n"
    "            );\n"
    "            const aiData = await res.json() as { candidates?: [{ content: { parts: [{ text: string }] } }] };\n"
    "            const text = aiData.candidates?.[0]?.content?.parts?.[0]?.text ?? \"\";\n"
    "            const pred = JSON.parse(text.replace(/```json\\n?|\\n?```/g, \"\").trim());\n"
    "            const { error: ie } = await admin.from(\"horse_predictions\").upsert({\n"
    "              race_id: race.id, first_pick: pred.first ?? entries[0].horse_name,\n"
    "              second_pick: pred.second ?? entries[1].horse_name,\n"
    "              third_pick: pred.third ?? entries[2].horse_name,\n"
    "              confidence: pred.confidence ?? 0.5, ai_reasoning: pred.reasoning ?? \"\",\n"
    "              ai_model: \"gemini-2.5-flash\",\n"
    "            }, { onConflict: \"race_id\" });\n"
    "            if (!ie) results.push({ race_id: race.id, race_name: race.race_name, ...pred });\n"
    "          } catch { /* ignore per-race errors */ }\n"
    "        }\n"
    "        return json({ success: true, predictions: results, count: results.length });\n"
    "      }\n"
    '      case "horseracing.predictions": {\n'
    "        const { data: preds, error: pe } = await admin.from(\"horse_predictions\")\n"
    "          .select(\"*, horse_races(race_name,race_date,venue,grade,course_type,distance), horse_results(first_place,second_place,third_place,trifecta_paid,is_prediction_correct)\")\n"
    "          .order(\"created_at\", { ascending: false }).limit(Number(body.limit ?? 50));\n"
    "        if (pe) throw new Error(pe.message);\n"
    "        return json({ success: true, predictions: preds ?? [] });\n"
    "      }\n"
    '      case "horseracing.store_results": {\n'
    "        const raceId = String(body.race_id ?? \"\");\n"
    "        if (!raceId) return json({ error: \"race_id required\" }, 400);\n"
    "        const pred = await admin.from(\"horse_predictions\").select(\"first_pick,second_pick,third_pick\").eq(\"race_id\", raceId).maybeSingle();\n"
    "        const isCorrect = pred.data\n"
    "          ? (pred.data.first_pick === body.first_place && pred.data.second_pick === body.second_place && pred.data.third_pick === body.third_place)\n"
    "          : null;\n"
    "        const { error: re } = await admin.from(\"horse_results\").upsert({\n"
    "          race_id: raceId, first_place: body.first_place, second_place: body.second_place,\n"
    "          third_place: body.third_place, trifecta_paid: body.trifecta_paid ?? null,\n"
    "          winner_odds: body.winner_odds ?? null, is_prediction_correct: isCorrect,\n"
    "        }, { onConflict: \"race_id\" });\n"
    "        await admin.from(\"horse_races\").update({ status: \"completed\" }).eq(\"id\", raceId);\n"
    "        if (re) throw new Error(re.message);\n"
    "        return json({ success: true, is_correct: isCorrect });\n"
    "      }\n"
    '      case "horseracing.accuracy": {\n'
    "        const { data: stats } = await admin.from(\"horse_accuracy_stats\").select(\"*\").maybeSingle();\n"
    "        const { data: recentHits } = await admin.from(\"horse_results\")\n"
    "          .select(\"race_id, is_prediction_correct, trifecta_paid, horse_races(race_name, race_date)\")\n"
    "          .eq(\"is_prediction_correct\", true).order(\"fetched_at\", { ascending: false }).limit(5);\n"
    "        return json({ success: true, stats: stats ?? {}, recent_hits: recentHits ?? [] });\n"
    "      }\n"
    '      case "horseracing.register_race": {\n'
    "        const { data: r, error: re } = await admin.from(\"horse_races\").insert({\n"
    "          source: \"manual\", race_name: String(body.name ?? \"\"),\n"
    "          race_date: String(body.date ?? new Date().toISOString().split(\"T\")[0]),\n"
    "          venue: body.venue ?? null, course_type: body.race_type ?? \"\u82dd\",\n"
    "          grade: body.grade ?? \"\u672a\u52dd\u5229\", distance: body.distance ?? null, status: \"scheduled\",\n"
    "        }).select(\"id\").single();\n"
    "        if (re) throw new Error(re.message);\n"
    "        return json({ success: true, race_id: r?.id });\n"
    "      }\n"
    '      case "horseracing.stats": {\n'
    "        const { data: stats } = await admin.from(\"horse_accuracy_stats\").select(\"*\").maybeSingle();\n"
    "        return json({ success: true, stats: {\n"
    "          totalBets: stats?.total_predictions ?? 0, wins: stats?.correct_count ?? 0,\n"
    "          winRate: stats?.hit_rate_pct ?? 0, totalPayout: stats?.total_payout ?? 0,\n"
    "          maxPayout: stats?.max_payout ?? 0,\n"
    "        }});\n"
    "      }"
)

content = content[:start_idx] + new_section + content[end_idx:]
old_actions = (
    '            "horseracing.list_races", "horseracing.register_race",\n'
    '            "horseracing.list_predictions", "horseracing.predict", "horseracing.stats",'
)
new_actions = (
    '            "horseracing.today", "horseracing.list_races", "horseracing.predict_all",\n'
    '            "horseracing.predictions", "horseracing.store_results", "horseracing.accuracy",\n'
    '            "horseracing.register_race", "horseracing.stats",'
)
content = content.replace(old_actions, new_actions, 1)
open(f, "w", encoding="utf-8").write(content)
print("SUCCESS")

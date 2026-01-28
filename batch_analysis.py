import os
import json
import time
import random
import re
from datetime import datetime, timezone
from google import genai
from google.genai import types
from supabase import create_client, Client

# 環境変数
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

if SUPABASE_URL and not SUPABASE_URL.startswith("http"):
    SUPABASE_URL = f"https://{SUPABASE_URL}"

if not SUPABASE_URL or not SUPABASE_KEY or not GEMINI_API_KEY:
    print("Error: 環境変数が不足しています。")
    exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# ★モデルの優先順位リスト (指定順)
# 上から順に試行し、エラーや制限なら次へ進みます
MODEL_CASCADE = [
    'gemini-pro-latest',
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
    'gemini-3-pro-preview',
    'gemini-3-flash-preview',
    'gemini-2.5-pro',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemma-3-27b-it',
    'gemma-3-12b-it',
    'gemma-3-4b-it',
    'gemma-3-1b-it',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite'
]


def log_result(status, message, count=0):
    try:
        supabase.table("batch_logs").insert({
            "status": status,
            "message": message,
            "records_processed": count,
            "created_at": datetime.now(timezone.utc).isoformat()
        }).execute()
        print(f"[{status}] {message}")
    except Exception as e:
        print(f"Log Error: {e}")


def clean_json_text(text):
    """Markdownコードブロックを除去"""
    pattern = r"```(?:json)?\s*([\s\S]*?)\s*```"
    match = re.search(pattern, text)
    if match:
        return match.group(1)
    return text.strip()


def extract_json(text):
    """JSON抽出"""
    try:
        text = re.sub(r'```(?:json)?', '', text).strip()
        text = text.replace('```', '')
        start = text.find('{')
        end = text.rfind('}')
        if start != -1 and end != -1:
            json_str = text[start:end + 1]
            return json.loads(json_str)
        return json.loads(text)
    except Exception:
        return None


def analyze_candidates_cascade():
    print("🚀 バッチ処理開始 (Custom Cascade Mode)")
    # 上位5つだけ表示
    print(f"📋 Priority: {', '.join(MODEL_CASCADE[:5])} ... and more")
    
    processed_count = 0
    client = genai.Client(api_key=GEMINI_API_KEY)

    try:
        # ID順に全候補者を取得
        response = supabase.table("candidates").select("*").order("id").execute()
        candidates = response.data
        
        if not candidates:
            log_result("WARNING", "候補者データが0件です", 0)
            return

        for i, candidate in enumerate(candidates):
            district = candidate['district']
            current_name = candidate['name']
            
            print(f"\nProcessing ({i+1}/{len(candidates)}): {district}...")

            # --- 変数 ---
            new_name = current_name
            prob = 50
            comment = ""
            success_model = None
            is_simulated = False

            # --- プロンプト作成 ---
            prompt = f"""
            選挙区: {district}
            政党: 国民民主党
            タスク:
            1. Google検索で候補者(総支部長)の実名を特定 (不明なら「{current_name}」)。
            2. 2026年当選確率予測(0-100)。
            3. 30文字以内のコメント。
            
            JSON出力: {{ "real_name": "氏名", "probability": 50, "comment": "..." }}
            """

            # --- モデル・カスケード実行 ---
            for model_name in MODEL_CASCADE:
                try:
                    # モデル切り替え時の待機（短めに）
                    if i > 0: time.sleep(1)

                    print(f"  Trying {model_name}...", end=" ")
                    
                    # Gemma系など検索非対応モデルへの対策:
                    # 検索ツールを指定してエラーが出たら、ツールなしで再トライするロジックも内包
                    try:
                        # まず検索ありでトライ
                        response = client.models.generate_content(
                            model=model_name,
                            contents=prompt,
                            config=types.GenerateContentConfig(
                                tools=[types.Tool(google_search=types.GoogleSearch())]
                            )
                        )
                    except Exception as tool_error:
                        # ツール非対応(Gemma等)の場合はツールなしでリトライ
                        if "Showcase" not in str(tool_error) and ("not supported" in str(tool_error) or "INVALID_ARGUMENT" in str(tool_error)):
                             # print("(Search N/A)", end=" ")
                             response = client.models.generate_content(
                                model=model_name,
                                contents=prompt
                            )
                        else:
                            raise tool_error

                    if response and response.text:
                        result = extract_json(response.text)
                        if result:
                            new_name = result.get('real_name', current_name)
                            prob = result.get('probability', 50)
                            comment = result.get('comment', '分析完了')
                            success_model = model_name
                            print("✅ OK")
                            break  # 成功！ループを抜ける
                        else:
                            print("❌ JSON Error")
                    else:
                        print("❌ Empty")

                except Exception as e:
                    # エラーハンドリング
                    error_msg = str(e)
                    if "429" in error_msg or "RESOURCE_EXHAUSTED" in error_msg:
                        print(f"⚠️ Limit")
                    elif "404" in error_msg or "NOT_FOUND" in error_msg:
                         print(f"❌ Not Found")
                    else:
                        print(f"❌ Error: {error_msg[:20]}...")
                    # 次のモデルへ

            # --- 全滅時 ---
            if success_model is None:
                print("  🚨 All models failed. Using SIMULATION.")
                is_simulated = True
                base_prob = candidate.get('win_probability', 50)
                change = random.randint(-5, 5)
                prob = max(0, min(100, base_prob + change))
                comment = "※全AIモデル制限のため推定値を表示"

            # --- DB更新 ---
            try:
                if new_name != current_name:
                    print(f"  ✨ Name Updated: {current_name} -> {new_name}")
                
                supabase.table("candidates").update({
                    "name": new_name,
                    "win_probability": prob,
                    "ai_analysis": comment,
                    "updated_at": datetime.now(timezone.utc).isoformat()
                }).eq("id", candidate['id']).execute()
                
                status_icon = "🤖" if not is_simulated else "🎲"
                model_info = f"({success_model})" if success_model else "(Sim)"
                print(f"  -> Success {status_icon} {model_info}: {prob}%")
                if not is_simulated: processed_count += 1

            except Exception as e:
                print(f"  ❌ DB Error: {e}")

        log_result("SUCCESS", f"{len(candidates)}件処理完了 (AI成功: {processed_count}件)", processed_count)

    except Exception as e:
        print(f"Fatal Error: {e}")
        log_result("ERROR", str(e), 0)
        exit(1)


if __name__ == "__main__":
    analyze_candidates_cascade()

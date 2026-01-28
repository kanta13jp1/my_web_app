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

# ★ ここを変更しました
MODEL_NAME = 'gemini-2.5-flash-lite-preview-09-2025'


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
    """Markdownコードブロックを除去してJSON文字列のみ抽出"""
    pattern = r"```(?:json)?\s*([\s\S]*?)\s*```"
    match = re.search(pattern, text)
    if match:
        return match.group(1)
    return text.strip()


def analyze_candidates_lite():
    print(f"🚀 バッチ処理開始 (Model: {MODEL_NAME})")
    processed_count = 0
    
    # 連続エラー回数カウント
    api_failure_count = 0
    FORCE_SIMULATION_MODE = False

    try:
        # 候補者データ取得 (ID順)
        response = supabase.table("candidates").select("*").order("id").execute()
        candidates = response.data
        
        if not candidates:
            log_result("WARNING", "候補者データが0件でした", 0)
            return

        client = genai.Client(api_key=GEMINI_API_KEY)

        for i, candidate in enumerate(candidates):
            district = candidate['district']
            current_name = candidate['name']
            
            print(f"\nProcessing ({i+1}/{len(candidates)}): {district}...")

            # --- 変数の初期化 ---
            new_name = current_name
            prob = 50
            comment = ""
            is_simulated = False

            # --- 1. AI分析トライ ---
            if not FORCE_SIMULATION_MODE:
                # Liteモデルでも念のため少し待機
                if i > 0:
                    time.sleep(5) 

                prompt = f"""
                選挙区: {district}
                政党: 国民民主党
                タスク: 
                1. Google検索を使用し、この選挙区の「国民民主党」の候補者(総支部長)の実名を特定。
                   (不明な場合は「{current_name}」を使用)
                2. 2026年当選確率予測(0-100)。
                3. 30文字以内のコメント作成。
                
                出力JSONキー: real_name, probability, comment
                """
                
                try:
                    # モデル呼び出し (検索ツール付き)
                    response = client.models.generate_content(
                        model=MODEL_NAME,
                        contents=prompt,
                        config=types.GenerateContentConfig(
                            tools=[types.Tool(google_search=types.GoogleSearch())]
                        )
                    )
                    
                    if response and response.text:
                        json_text = clean_json_text(response.text)
                        result = json.loads(json_text)
                        new_name = result.get('real_name', current_name)
                        prob = result.get('probability', 50)
                        comment = result.get('comment', '分析完了')
                        # 成功したらエラーカウントリセット
                        api_failure_count = 0
                    else:
                        raise Exception("Empty response or Search failed")

                except Exception as e:
                    print(f"  ⚠️ AI Failed ({e})")
                    api_failure_count += 1
                    
                    # 連続失敗したらシミュレーションモードへ
                    if api_failure_count >= 3:
                        print("  🚨 API error/limit reached. Switching to SIMULATION mode.")
                        FORCE_SIMULATION_MODE = True
                    
                    is_simulated = True
            else:
                is_simulated = True

            # --- 2. シミュレーションデータ生成 (AI失敗時) ---
            if is_simulated:
                base_prob = candidate.get('win_probability', 50)
                change = random.randint(-5, 5)
                prob = max(0, min(100, base_prob + change))
                
                if FORCE_SIMULATION_MODE:
                    comment = f"※API制限中のためシミュレーション値 (前日比 {change:+d}%)"
                else:
                    comment = "データ取得エラーにより推定値を表示"
                
                print(f"  Using Simulation Data: {prob}%")

            # --- 3. データベース更新 ---
            try:
                if new_name != current_name:
                    print(f"  ✨ Name Updated: {current_name} -> {new_name}")

                update_res = supabase.table("candidates").update({
                    "name": new_name,
                    "win_probability": prob,
                    "ai_analysis": comment,
                    "updated_at": datetime.now(timezone.utc).isoformat()
                }).eq("id", candidate['id']).execute()
                
                if len(update_res.data) > 0:
                    processed_count += 1
                    status_icon = "🤖" if not is_simulated else "🎲"
                    print(f"  -> Update Success {status_icon}: {prob}%")
                
            except Exception as e:
                print(f"  ❌ DB Update Error: {e}")

        # 最終ログ
        final_status = "SUCCESS" if not FORCE_SIMULATION_MODE else "WARNING"
        log_msg = f"{processed_count}件更新完了"
        if FORCE_SIMULATION_MODE:
            log_msg += " (一部シミュレーション)"
            
        log_result(final_status, log_msg, processed_count)

    except Exception as e:
        print(f"Fatal Error: {e}")
        log_result("ERROR", str(e), 0)
        exit(1)


if __name__ == "__main__":
    analyze_candidates_lite()

import os
import json
import time
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


def analyze_candidates_with_search():
    print("🚀 バッチ処理開始 (Google Search Grounding Mode)")
    processed_count = 0
    
    try:
        # 候補者データ取得
        response = supabase.table("candidates").select("*").execute()
        candidates = response.data
        
        if not candidates:
            log_result("WARNING", "候補者データが0件でした", 0)
            return

        client = genai.Client(api_key=GEMINI_API_KEY)

        for i, candidate in enumerate(candidates):
            district = candidate['district']
            current_name = candidate['name']
            
            print(f"\n🔍 Searching info for: {district} (Current: {current_name})...")
            
            # API制限対策 (検索は重いので30秒待機推奨)
            if i > 0:
                print("  Waiting 30s for Search API rate limit...")
                time.sleep(30)

            # Google検索を有効にしたプロンプト
            prompt = f"""
            Google検索を使って、次の選挙区の最新情報を調査してください。
            選挙区: {district}
            政党: 国民民主党 (Democratic Party for the People)
            
            タスク:
            1. この選挙区の国民民主党の「総支部長」または「立候補予定者」の実名を特定してください。
               (もし現職がいる場合はその名前。決まっていない場合は「擁立調整中」としてください)
            2. その候補者の、2026年時点での予想当選確率(0-100)を、競合相手(自民・立憲など)の強さを踏まえて算出してください。
            3. 短い分析コメントを書いてください。
            
            出力形式(JSON):
            {{
                "real_name": "氏名(フルネーム)",
                "probability": 0〜100の整数,
                "comment": "30文字以内の分析"
            }}
            """
            
            try:
                # ツール設定で GoogleSearch を有効化
                response = client.models.generate_content(
                    model='gemini-flash-latest',  # ★指定のモデル
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        tools=[types.Tool(google_search=types.GoogleSearch())],
                        response_mime_type='application/json'
                    )
                )
                
                result = json.loads(response.text)
                
                new_name = result.get('real_name', current_name)
                prob = result.get('probability', 50)
                comment = result.get('comment', '情報取得失敗')

                # 名前が更新される場合のみログ出力
                if new_name != current_name:
                    print(f"  ✨ Name Updated: {current_name} -> {new_name}")
                
                now_iso = datetime.now(timezone.utc).isoformat()

                # DB更新: 名前(name)も更新する
                update_res = supabase.table("candidates").update({
                    "name": new_name,
                    "win_probability": prob,
                    "ai_analysis": comment,
                    "updated_at": now_iso
                }).eq("id", candidate['id']).execute()
                
                if len(update_res.data) > 0:
                    processed_count += 1
                    print(f"  -> Analyzed: {prob}% {comment}")
                else:
                    print(f"  -> DB Update Failed")
                
            except Exception as e:
                # エラー時はスキップして次へ
                print(f"  ❌ Error on {district}: {e}")

        log_result("SUCCESS", f"{processed_count}選挙区の最新情報をWebから取得・更新しました", processed_count)

    except Exception as e:
        print(f"Fatal Error: {e}")
        log_result("ERROR", str(e), 0)
        exit(1)


if __name__ == "__main__":
    analyze_candidates_with_search()

import os
import json
import random
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


def analyze_candidates():
    print("🚀 バッチ処理開始 (Gemini 2.0 Flash + Rate Limit Safe Mode)")
    processed_count = 0
    
    try:
        response = supabase.table("candidates").select("*").execute()
        candidates = response.data
        
        if not candidates:
            log_result("WARNING", "候補者データが0件でした", 0)
            return

        client = genai.Client(api_key=GEMINI_API_KEY)

        for i, candidate in enumerate(candidates):
            print(f"Analyzing ({i+1}/{len(candidates)}): {candidate['name']}...")
            
            # ★レート制限対策: 最初の1件以外は5秒待機
            if i > 0:
                print("  Waiting 5s for API rate limit...")
                time.sleep(5)

            # 動作確認用デバッグ値
            debug_prob = random.randint(30, 90)
            
            prompt = f"""
            選挙区「{candidate['district']}」の候補者「{candidate['name']}」について。
            現在の当選確率を {debug_prob}% 前後と仮定して、その理由となる短い分析コメントを作成してください。
            
            出力形式(JSON):
            {{
                "comment": "30文字以内のコメント"
            }}
            """
            
            try:
                # リストに存在することを確認済みのモデルを指定
                response = client.models.generate_content(
                    model='gemini-2.0-flash',
                    contents=prompt,
                    config=types.GenerateContentConfig(response_mime_type='application/json')
                )
                
                result = json.loads(response.text)
                comment = result.get('comment', '分析完了')

                now_iso = datetime.now(timezone.utc).isoformat()

                # 更新実行
                update_res = supabase.table("candidates").update({
                    "win_probability": debug_prob,
                    "ai_analysis": comment,
                    "updated_at": now_iso
                }).eq("id", candidate['id']).execute()
                
                if len(update_res.data) > 0:
                    processed_count += 1
                    print(f"  -> Success: {debug_prob}%")
                else:
                    print(f"  -> Failed: No rows updated.")
                
            except Exception as e:
                print(f"Error on {candidate['name']}: {e}")
                # APIエラーが出ても止まらず次へ進む

        if processed_count == 0:
             log_result("ERROR", "更新成功数0件。APIエラーまたは権限を確認してください。", 0)
        else:
             log_result("SUCCESS", f"{processed_count}人の分析を更新しました", processed_count)

    except Exception as e:
        print(f"Fatal Error: {e}")
        log_result("ERROR", str(e), 0)
        exit(1)


if __name__ == "__main__":
    analyze_candidates()

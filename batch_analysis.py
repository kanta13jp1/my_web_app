import os
import json
from google import genai
from google.genai import types # 型定義用
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
    """実行結果をログテーブルに保存"""
    try:
        supabase.table("batch_logs").insert({
            "status": status,
            "message": message,
            "records_processed": count,
            "created_at": "now()"
        }).execute()
        print(f"[{status}] {message}")
    except Exception as e:
        print(f"Log Error: {e}")

def analyze_candidates():
    print("🚀 バッチ処理開始")
    processed_count = 0
    
    try:
        # 1. 候補者リスト取得
        response = supabase.table("candidates").select("*").execute()
        candidates = response.data
        
        if not candidates:
            log_result("WARNING", "候補者データが0件でした", 0)
            return

        client = genai.Client(api_key=GEMINI_API_KEY)

        for candidate in candidates:
            print(f"Analyzing: {candidate['name']}...")
            
            # プロンプト: JSON出力を強制
            prompt = f"""
            選挙区「{candidate['district']}」の候補者「{candidate['name']}」について、
            2026年現在の架空の選挙情勢をシミュレーションしてください。
            前回の値（勝率{candidate.get('win_probability')}%）から少し変化させてください。
            
            以下のJSON形式のみを出力してください:
            {{
                "probability": 0〜100の整数,
                "comment": "分析コメント(30文字以内)"
            }}
            """
            
            try:
                # JSONモードでリクエスト
                response = client.models.generate_content(
                    model='gemini-2.0-flash',
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        response_mime_type='application/json'
                    )
                )
                
                # JSONパース
                result = json.loads(response.text)
                prob = result.get('probability', 50)
                comment = result.get('comment', '分析不能')

                # 3. Supabase更新 (エラーがあれば例外発生)
                update_res = supabase.table("candidates").update({
                    "win_probability": prob,
                    "ai_analysis": comment,
                    "updated_at": "now()"
                }).eq("id", candidate['id']).execute()
                
                # 更新確認
                if len(update_res.data) > 0:
                    processed_count += 1
                    print(f"  -> Updated: {prob}% {comment}")
                else:
                    print(f"  -> Update failed (No rows affected)")
                
            except Exception as e:
                print(f"Error on {candidate['name']}: {e}")

        log_result("SUCCESS", f"{processed_count}人の分析を更新しました", processed_count)

    except Exception as e:
        print(f"Fatal Error: {e}")
        log_result("ERROR", str(e), processed_count)
        exit(1)

if __name__ == "__main__":
    analyze_candidates()
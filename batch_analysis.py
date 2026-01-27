import os
import datetime
from google import genai
from supabase import create_client, Client

# 環境変数
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

# URL補完
if SUPABASE_URL and not SUPABASE_URL.startswith("http"):
    SUPABASE_URL = f"https://{SUPABASE_URL}"

if not SUPABASE_URL or not SUPABASE_KEY or not GEMINI_API_KEY:
    print("Error: 環境変数が不足しています。")
    exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def log_result(status, message, count=0):
    """結果をSupabaseに保存する"""
    try:
        supabase.table("batch_logs").insert({
            "status": status,
            "message": message,
            "records_processed": count,
            "created_at": "now()"
        }).execute()
        print(f"Log saved: {status} - {message}")
    except Exception as e:
        print(f"Failed to save log: {e}")

def analyze_candidates():
    print("🚀 バッチ処理開始")
    processed_count = 0
    
    try:
        response = supabase.table("candidates").select("*").execute()
        candidates = response.data
        
        if not candidates:
            log_result("WARNING", "候補者データがありませんでした", 0)
            return

        client = genai.Client(api_key=GEMINI_API_KEY)

        for candidate in candidates:
            print(f"Analyzing: {candidate['name']}...")
            
            prompt = f"""
            選挙コンサルタントとして、候補者「{candidate['name']}」（{candidate['district']}）の
            2026年の当選確率(0-100)と短い分析コメントを出力してください。
            出力形式: Probability: 数値 Comment: 文字列
            """
            
            try:
                res = client.models.generate_content(model='gemini-2.0-flash', contents=prompt)
                text = res.text
                
                # 簡易パース
                prob = 50
                comment = "AI分析中"
                import re
                prob_match = re.search(r"Probability:\s*(\d+)", text)
                if prob_match: prob = int(prob_match.group(1))
                comm_match = re.search(r"Comment:\s*(.*)", text)
                if comm_match: comment = comm_match.group(1).strip()

                supabase.table("candidates").update({
                    "win_probability": prob,
                    "ai_analysis": comment,
                    "updated_at": "now()"
                }).eq("id", candidate['id']).execute()
                
                processed_count += 1
                
            except Exception as e:
                print(f"Error on {candidate['name']}: {e}")
                # 個別のエラーはログに残しつつ続行

        # 成功ログ
        log_result("SUCCESS", "全候補者の分析が完了しました", processed_count)

    except Exception as e:
        # 全体エラーログ
        print(f"Fatal Error: {e}")
        log_result("ERROR", str(e), processed_count)
        exit(1)

if __name__ == "__main__":
    analyze_candidates()
import os
import json
import time
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
    """
    Markdownのコードブロック (```json ... ```) を除去して
    純粋なJSON文字列を取り出すヘルパー関数
    """
    # ```json ... ``` または ``` ... ``` を削除
    pattern = r"```(?:json)?\s*([\s\S]*?)\s*```"
    match = re.search(pattern, text)
    if match:
        return match.group(1)
    return text.strip()


def analyze_candidates_with_search():
    print("🚀 バッチ処理開始 (Search Grounding + Text Parsing Mode)")
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
            
            # API制限対策 (検索は重いので30秒待機)
            if i > 0:
                print("  Waiting 30s for Search API rate limit...")
                time.sleep(30)

            # プロンプト: JSON形式のテキスト出力を強く指示
            prompt = f"""
            Google検索を使って、次の選挙区の最新情報を調査してください。
            選挙区: {district}
            政党: 国民民主党 (Democratic Party for the People)
            
            タスク:
            1. この選挙区の国民民主党の「総支部長」または「立候補予定者」の実名を特定してください。
               (現職がいる場合はその名前。未定の場合は「擁立調整中」)
            2. 2026年時点での予想当選確率(0-100)を、競合相手の強さを踏まえて算出してください。
            3. 30文字以内の短い分析コメントを書いてください。
            
            【重要】
            回答は以下のJSON形式の文字列のみを出力してください。余計な説明は不要です。
            
            ```json
            {{
                "real_name": "氏名",
                "probability": 50,
                "comment": "分析コメント"
            }}
            ```
            """
            
            try:
                # ツール設定: Search有効化 + JSONモード無効化(デフォルト)
                response = client.models.generate_content(
                    model='gemini-flash-latest',
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        tools=[types.Tool(google_search=types.GoogleSearch())],
                        # response_mime_type='application/json' は指定しない！
                    )
                )
                
                raw_text = response.text
                if not raw_text:
                    print("  ❌ Empty response from AI")
                    continue
                    
                # テキストからJSON部分を抽出・パース
                json_text = clean_json_text(raw_text)
                result = json.loads(json_text)
                
                new_name = result.get('real_name', current_name)
                prob = result.get('probability', 50)
                comment = result.get('comment', '情報取得失敗')

                if new_name != current_name:
                    print(f"  ✨ Name Updated: {current_name} -> {new_name}")
                
                now_iso = datetime.now(timezone.utc).isoformat()

                # DB更新
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
                print(f"  ❌ Error on {district}: {e}")

        log_result("SUCCESS", f"{processed_count}選挙区の最新情報をWebから取得・更新しました", processed_count)

    except Exception as e:
        print(f"Fatal Error: {e}")
        log_result("ERROR", str(e), 0)
        exit(1)


if __name__ == "__main__":
    analyze_candidates_with_search()

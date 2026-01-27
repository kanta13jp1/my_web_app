import os
from google import genai
from supabase import create_client, Client

# 環境変数から設定を読み込む
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

# URLの簡易チェック (https:// がない場合に付与する安全策)
if SUPABASE_URL and not SUPABASE_URL.startswith("http"):
    SUPABASE_URL = f"https://{SUPABASE_URL}"

if not SUPABASE_URL or not SUPABASE_KEY or not GEMINI_API_KEY:
    print("Error: 必要な環境変数が設定されていません。")
    exit(1)

# Supabaseクライアントの初期化
try:
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
except Exception as e:
    print(f"Error initializing Supabase client: {e}")
    print(f"DEBUG: URL length: {len(SUPABASE_URL) if SUPABASE_URL else 0}")
    exit(1)


def analyze_candidates():
    print("🚀 バッチ処理開始: 選挙区情勢分析")
    
    try:
        # 1. 候補者リスト取得
        response = supabase.table("candidates").select("*").execute()
        candidates = response.data
        
        if not candidates:
            print("候補者データがありません。処理を終了します。")
            return

        # Geminiクライアントの初期化 (新SDK)
        client = genai.Client(api_key=GEMINI_API_KEY)

        for candidate in candidates:
            print(f"Analyzing: {candidate['name']} ({candidate['district']})...")
            
            # 2. AIによる情勢分析
            prompt = f"""
            あなたは選挙コンサルタントです。
            候補者「{candidate['name']}」（選挙区：{candidate['district']}）について、
            2026年現在の架空の情勢をシミュレーションし、当選確率(0-100)と短い分析コメントを出力してください。
            
            出力形式:
            Probability: 80
            Comment: 若年層の支持が急増しており優勢。
            """
            
            try:
                # 新しいメソッド generate_content
                response = client.models.generate_content(
                    model='gemini-2.0-flash',
                    contents=prompt
                )
                text = response.text
                
                # 簡易パース
                prob = 50
                comment = "分析中"
                
                import re
                prob_match = re.search(r"Probability:\s*(\d+)", text)
                if prob_match:
                    prob = int(prob_match.group(1))
                
                comment_match = re.search(r"Comment:\s*(.*)", text)
                if comment_match:
                    comment = comment_match.group(1).strip()

                # 3. Supabase更新
                supabase.table("candidates").update({
                    "win_probability": prob,
                    "ai_analysis": comment,
                    "updated_at": "now()"
                }).eq("id", candidate['id']).execute()
                
            except Exception as e:
                print(f"Error analyzing {candidate['name']}: {e}")

        print("✅ バッチ処理完了: 全データの更新終了")
        
    except Exception as e:
        print(f"Fatal Error: {e}")
        exit(1)


if __name__ == "__main__":
    analyze_candidates()

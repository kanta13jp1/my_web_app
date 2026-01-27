import os
import google.generativeai as genai
from supabase import create_client, Client

# 環境変数から設定を読み込む
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

if not SUPABASE_URL or not SUPABASE_KEY or not GEMINI_API_KEY:
    print("Error: 必要な環境変数が設定されていません。")
    exit(1)

genai.configure(api_key=GEMINI_API_KEY)
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def analyze_candidates():
    print("🚀 バッチ処理開始: 選挙区情勢分析")
    
    try:
        # 1. 候補者リスト取得
        response = supabase.table("candidates").select("*").execute()
        candidates = response.data
        
        if not candidates:
            print("候補者データがありません。処理を終了します。")
            return

        model = genai.GenerativeModel('gemini-2.0-flash')

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
                res = model.generate_content(prompt)
                text = res.text
                
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
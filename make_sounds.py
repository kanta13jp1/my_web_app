from gtts import gTTS
import os

# 保存先ディレクトリ
output_dir = "web/assets/sounds"
os.makedirs(output_dir, exist_ok=True)

# 難易度別の音声テキスト
sounds = {
    "success_easy.mp3": "Good job!",
    "success.mp3": "Success!",
    "success_hard.mp3": "Congratulations! You are amazing!"
}

for filename, text in sounds.items():
    speech = gTTS(text=text, lang='en', slow=False)
    file_path = os.path.join(output_dir, filename)
    speech.save(file_path)
    print(f"{file_path} を作成しました！")

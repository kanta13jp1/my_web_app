from gtts import gTTS
import os

# 設定
text = "Success!" # 喋らせたい言葉
language = 'en'   # 英語: 'en', 日本語: 'ja'

# 保存先ディレクトリ (pubspec.yamlの設定に合わせる)
output_dir = "web/assets/sounds"
# フォルダが存在しない場合は作成
os.makedirs(output_dir, exist_ok=True)

# 音声生成
speech = gTTS(text=text, lang=language, slow=False)

# 保存
file_name = os.path.join(output_dir, "success.mp3")
speech.save(file_name)

print(f"{file_name} を作成しました！")

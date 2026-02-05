import 'package:google_generative_ai/google_generative_ai.dart';

class AIModelService {
  static AIModelService _instance = AIModelService();

  static AIModelService get instance => _instance;

  // For testing purposes
  static void setInstance(AIModelService instance) {
    _instance = instance;
  }

  Future<String?> generateContent({
    required String model,
    required String apiKey,
    required String prompt,
  }) async {
    final genModel = GenerativeModel(model: model, apiKey: apiKey);
    final content = [Content.text(prompt)];
    final response = await genModel.generateContent(content);
    return response.text;
  }

  Future<String?> generateMindMap({
    required String model,
    required String apiKey,
    required String topic,
  }) {
    const promptTemplate = '''
You are an expert mind map generator. Your task is to take a central topic and generate a hierarchical structure of related ideas, concepts, and sub-topics. The output must be a valid JSON object.

The JSON object should have a single root key representing the central topic. The value should be an object where each key is a child idea. This can be nested recursively for sub-ideas.

**Example Input:** "時間管理術" (Time Management Techniques)

**Example Output:**
```json
{
  "時間管理術": {
    "目標設定": {
      "SMARTの法則": {},
      "短期・長期目標": {}
    },
    "タスクの優先順位付け": {
      "アイゼンハワー・マトリクス": {},
      "ABCDEメソッド": {}
    },
    "テクニック": {
      "ポモドーロ・テクニック": {},
      "2分ルール": {}
    },
    "ツール": {
      "カレンダーアプリ": {},
      "タスク管理ツール": {}
    }
  }
}
```

**Your Task:**

Generate a mind map for the following topic: **"{topic}"**
''';
    final prompt = promptTemplate.replaceFirst('{topic}', topic);
    return generateContent(model: model, apiKey: apiKey, prompt: prompt);
  }
}

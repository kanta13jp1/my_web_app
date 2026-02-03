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
}

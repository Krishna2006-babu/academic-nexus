import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../models/academic_models.dart';
import 'dart:async';

class AIService {
  late final String _apiKey;
  List<Map<String, dynamic>> _messageHistory = [];

  AIService() {
    // 1. Pointing to the new Sarvam key in your .env
    final key = dotenv.env['SARVAM_API_KEY'];
    if (key == null) throw Exception('No Sarvam API key found in .env file!');
    _apiKey = key;
  }

  void startChatWithContext(List<Subject> currentSubjects, {List<Map<String, dynamic>>? previousHistory}) {
    String academicContext = "You are an elite Academic Tutor and Strategy Advisor for the 'Academic Nexus' app. "
        "CRITICAL RULE: You HAVE advanced vision capabilities. You CAN see images. NEVER claim that you cannot see an image. "
        "If a user uploads an image, analyze it directly, read the text on it, and explain the concepts within it confidently.\n\n"
        "Here is the student's current course load:\n";

    for (var sub in currentSubjects) {
      academicContext += "- ${sub.name} (Target: ${sub.requiredPercentage}%, Current: ${sub.attendancePercentage(DateTime.now()).toStringAsFixed(1)}%)\n";
    }

    academicContext += "\nCRITICAL BEHAVIOR RULES:\n"
        "1. NEVER give generic advice like 'study hard', 'review notes', or 'attend classes'.\n"
        "2. When asked about passing or studying a subject, act like an interactive mentor.\n"
        "3. First, PROACTIVELY ASK the student what specific chapters, units, or modules they are currently learning.\n"
        "4. Once they reply, break down the actual academic material. Explain complex topics using real-world analogies, step-by-step logic, or technical breakdowns.\n"
        "5. Teach one core concept at a time and ask if they understand before moving on.\n"
        "6. Do not mention their attendance unless it drops below their target.";

    if (previousHistory != null && previousHistory.isNotEmpty) {
      _messageHistory = List.from(previousHistory);
    } else {
      _messageHistory = <Map<String, dynamic>>[
        {"role": "system", "content": academicContext}
      ];
    }
    
    debugPrint("Sarvam AI System Prompt Loaded Successfully.");
  }
  
  List<Map<String, dynamic>> get currentMemory => _messageHistory;

  Future<String> sendMessage(String userMessage, {String? base64Image}) async {
    if (_messageHistory.isEmpty) {
      return "Error: Chat session was not initialized with student data.";
    }

    String textToSave = userMessage.isEmpty ? "Analyzed an uploaded image." : userMessage;
    _messageHistory.add({"role": "user", "content": textToSave});

    List<Map<String, dynamic>> apiPayload = List.from(_messageHistory);

    if (base64Image != null) {
      apiPayload.last = {
        "role": "user",
        "content": [
          {"type": "text", "text": textToSave},
          {
            "type": "image_url",
            // Sarvam's open-source vision endpoint accepts strictly Base64 data URIs
            "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
          }
        ]
      };
    }

    // 2. Dynamic Routing: Sarvam-105b is on /v1. Vision models are on /v2.
    final String apiUrl = base64Image != null 
        ? "https://api.sarvam.ai/v2/chat/completions" 
        : "https://api.sarvam.ai/v1/chat/completions";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          // 3. Sarvam uses an explicit subscription key header
          "api-subscription-key": _apiKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          // 4. Using the flagship 105B for text, and Gemma4 for image analysis
          "model": base64Image != null ? "gemma4" : "sarvam-105b", 
          "messages": apiPayload,
          "temperature": 0.5,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String aiText = data['choices'][0]['message']['content'];
        
        _messageHistory.add({"role": "assistant", "content": aiText});
        return aiText;
      } else {
        _messageHistory.removeLast();
        debugPrint("Sarvam API Error: ${response.statusCode} - ${response.body}");
        return "The AI server is experiencing an issue. Code: ${response.statusCode}";
      }
    } catch (e) {
      _messageHistory.removeLast();
      debugPrint("Network Error reaching Sarvam: $e");
      return "Connection Error: Failed to reach the AI server. Check your connection.";
    }
  }
}
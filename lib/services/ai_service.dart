
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

import '../models/academic_models.dart';

class AIService {
  late final String _apiKey;

  List<Map<String, dynamic>> _messageHistory = [];
  List<Subject> _currentSubjects = [];

  // Keeps requests small: system prompt + last N messages.
  static const int _maxHistoryMessages = 30;

  AIService() {
    final key = dotenv.env['SARVAM_API_KEY'];

    if (key == null || key.isEmpty) {
      throw Exception('No Sarvam API key found in .env file!');
    }

    _apiKey = key;
  }

  // ==========================================
  // CURRENT DATE AND TIME
  // ==========================================

  String _getCurrentDateTime() {
    final now = DateTime.now();

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absoluteMinutes = offset.inMinutes.abs();

    final timezoneOffset =
        'UTC$sign${twoDigits(absoluteMinutes ~/ 60)}:${twoDigits(absoluteMinutes % 60)}';

    return '${weekdays[now.weekday - 1]}, '
        '${now.day} ${months[now.month - 1]} ${now.year}, '
        '${twoDigits(now.hour)}:${twoDigits(now.minute)}:${twoDigits(now.second)} '
        '($timezoneOffset, ${now.timeZoneName})';
  }

  // ==========================================
  // SYSTEM PROMPT
  // ==========================================

  String _buildSystemPrompt(List<Subject> currentSubjects) {
    final buffer = StringBuffer();

    // IMPORTANT: Dynamic date context.
    buffer.writeln('CURRENT DATE AND TIME (AUTHORITATIVE):');

    buffer.writeln(
      '- ${_getCurrentDateTime()}',
    );

    buffer.writeln(
      '- This is the actual current local date and time of the user.',
    );

    buffer.writeln(
      '- Always use this date when answering questions involving today, tomorrow, yesterday, weekdays or upcoming dates.',
    );

    buffer.writeln(
      '- NEVER assume a different current date based on your training data.',
    );

    buffer.writeln(
      '- NEVER invent a date or claim that today is a different day.',
    );

    buffer.writeln(
      '- For local festivals and celebrations, ask for the city or region when necessary.',
    );

    buffer.writeln(
      '- Do not invent current events or festivals. If live information is needed and no live search source is available, be transparent that you cannot verify it.',
    );

    buffer.writeln(
      "\nYou are Nexus, the built-in AI companion of the 'Academic Nexus' app. "
      "You talk like a smart, friendly person, not like a teacher, textbook or customer-support bot.",
    );

    // PERSONALITY
    buffer.writeln('\nPERSONALITY & STYLE:');

    buffer.writeln(
      "- Be casual, warm, curious and a little witty. Mirror the user's tone, language and energy (if they write in Hinglish, reply in Hinglish; if they're brief, be brief).",
    );

    buffer.writeln(
      '- Keep replies short and conversational by default (1-4 sentences). Go longer ONLY when the user asks for a detailed explanation.',
    );

    buffer.writeln(
      "- Sound like a real chat: react to what they said, use natural phrasing, occasional light humor, and an emoji now and then (not every message).",
    );

    buffer.writeln(
      "- Ask at most ONE follow-up question, and only when it genuinely moves the conversation forward. Don't end every message with a question.",
    );

    buffer.writeln(
      "- Never use stiff openers like 'Certainly!', 'Great question!' or 'As an AI...'. Avoid bullet-point lectures unless asked.",
    );

    buffer.writeln(
      "- You can chat about anything: life, ideas, tech, movies, stress, random thoughts, not just studies.",
    );

    // TOPIC RULES
    buffer.writeln('\nCRITICAL TOPIC RULES:');

    buffer.writeln(
      "- NEVER bring up the user's subjects, courses, attendance, targets or percentages on your own.",
    );

    buffer.writeln(
      "- NEVER proactively start teaching, quizzing, or asking what chapters they're studying.",
    );

    buffer.writeln(
      '- NEVER give unsolicited study advice or motivational lectures.',
    );

    buffer.writeln(
      '- Only talk about a subject, or use the course data below, when the user clearly asks about it or mentions it first.',
    );

    buffer.writeln(
      '- If they DO ask for help with a topic: explain it clearly with real-world analogies, one idea at a time, in a chatty way, then let them steer where to go next.',
    );

    buffer.writeln(
      '- Mention attendance only if the user asks about it directly.',
    );

    // IMAGES
    buffer.writeln('\nIMAGES:');

    buffer.writeln(
      'You have vision. If the user sends an image, look at it, read any text in it, and respond naturally. Never say you can\'t see images.',
    );

    // BACKGROUND CONTEXT
    buffer.writeln(
      '\nBACKGROUND CONTEXT (private, do not recite or mention unless asked):',
    );

    if (currentSubjects.isEmpty) {
      buffer.writeln('- The student has not added any subjects yet.');
    } else {
      for (var sub in currentSubjects) {
        buffer.writeln(
          '- ${sub.name} (Target: ${sub.requiredPercentage}%, '
          'Current: ${sub.attendancePercentage(DateTime.now()).toStringAsFixed(1)}%)',
        );
      }
    }

    return buffer.toString();
  }

  // ==========================================
  // INITIALIZE CHAT
  // ==========================================

  void startChatWithContext(
    List<Subject> currentSubjects, {
    List<Map<String, dynamic>>? previousHistory,
  }) {
    _currentSubjects = List<Subject>.from(currentSubjects);

    final systemMessage = {
      'role': 'system',
      'content': _buildSystemPrompt(_currentSubjects),
    };

    if (previousHistory != null && previousHistory.isNotEmpty) {
      final restored =
          List<Map<String, dynamic>>.from(previousHistory);

      if (restored.first['role'] == 'system') {
        restored[0] = systemMessage;
      } else {
        restored.insert(0, systemMessage);
      }

      _messageHistory = restored;
    } else {
      _messageHistory = [systemMessage];
    }

    debugPrint('Sarvam AI System Prompt Loaded Successfully.');
    debugPrint('CURRENT AI DATE: ${_getCurrentDateTime()}');
  }

  List<Map<String, dynamic>> get currentMemory => _messageHistory;

  // ==========================================
  // TRIM HISTORY
  // ==========================================

  List<Map<String, dynamic>> _trimmedHistory() {
    if (_messageHistory.length <= _maxHistoryMessages + 1) {
      return List.from(_messageHistory);
    }

    final system = _messageHistory.first;

    final recent = _messageHistory.sublist(
      _messageHistory.length - _maxHistoryMessages,
    );

    return [system, ...recent];
  }

  // ==========================================
  // SEND MESSAGE
  // ==========================================

  Future<String> sendMessage(
    String userMessage, {
    String? base64Image,
  }) async {
    if (_messageHistory.isEmpty) {
      return 'Error: Chat session was not initialized with student data.';
    }

    // Refresh the date and time before EVERY message.
    // This prevents stale dates in long-running conversations.
    _messageHistory[0] = {
      'role': 'system',
      'content': _buildSystemPrompt(_currentSubjects),
    };

    String textToSave = userMessage.isEmpty
        ? 'Analyzed an uploaded image.'
        : userMessage;

    _messageHistory.add({
      'role': 'user',
      'content': textToSave,
    });

    
List<Map<String, dynamic>> apiPayload = _trimmedHistory();

// Add current date directly to the latest user message.
// This gives the model fresh date context on every request.
final String currentDateInstruction = '''
IMPORTANT CURRENT DATE AND TIME:

${_getCurrentDateTime()}

This date and time are authoritative.

- Do not use dates mentioned in older conversation messages as today's date.
- Older assistant responses may contain incorrect date information.
- Always calculate today and tomorrow relative to the current date above.
- Never claim to have checked live festival information unless you actually have access to a live source.
- If you cannot verify a festival or current event, say so honestly.

''';

if (base64Image != null) {
  apiPayload.last = {
    'role': 'user',
    'content': [
      {
        'type': 'text',
        'text':
            '$currentDateInstruction\n${userMessage.isEmpty ? "What do you think of this image?" : userMessage}',
      },
      {
        'type': 'image_url',
        'image_url': {
          'url': 'data:image/jpeg;base64,$base64Image',
        },
      },
    ],
  };
} else {
  apiPayload[apiPayload.length - 1] = {
    'role': 'user',
    'content': '$currentDateInstruction\nUser message: $textToSave',
  };
}

debugPrint('NEXUS DATE SENT: ${_getCurrentDateTime()}');


    final String apiUrl = base64Image != null
        ? 'https://api.sarvam.ai/v2/chat/completions'
        : 'https://api.sarvam.ai/v1/chat/completions';

    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'api-subscription-key': _apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': base64Image != null
                  ? 'gemma4'
                  : 'sarvam-105b',
              'messages': apiPayload,
              'temperature': 0.8,
              'top_p': 0.95,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        final String aiText =
            data['choices'][0]['message']['content'];

        _messageHistory.add({
          'role': 'assistant',
          'content': aiText,
        });

        return aiText;
      } else {
        _messageHistory.removeLast();

        debugPrint(
          'Sarvam API Error: ${response.statusCode} - ${response.body}',
        );

        return 'The AI server is experiencing an issue. Code: ${response.statusCode}';
      }
    } catch (e) {
      _messageHistory.removeLast();

      debugPrint('Network Error reaching Sarvam: $e');

      return 'Connection Error: Failed to reach the AI server. Check your connection.';
    }
  }
}

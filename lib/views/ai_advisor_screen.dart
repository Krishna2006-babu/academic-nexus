import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/firebase_service.dart';
import '../models/academic_models.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Required for Uint8List
import 'package:image_picker/image_picker.dart';

class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _controller = TextEditingController();

  // Upgraded to Map<String, dynamic> to store text and image bytes locally
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _isInitializing = true;

  // Image upload variables
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _imageBytes; // Memory bytes for Web/Edge compatibility

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  Future<void> _initializeAI() async {
    try {
      List<Subject> currentSubjects = await FirebaseService()
          .streamSubjects('sem_01')
          .first;

      // 1. Check Firestore for old chats
      List<Map<String, dynamic>> savedHistory = await FirebaseService()
          .loadChatHistory();

      // 2. Pass the old chats into the AI's brain
      _aiService.startChatWithContext(
        currentSubjects,
        previousHistory: savedHistory,
      );

      setState(() {
        // 3. If there is history, render it. If not, show the welcome message.
        if (savedHistory.length > 1) {
          // > 1 because the hidden system prompt is always index 0
          for (var i = 1; i < savedHistory.length; i++) {
            // Rebuild the UI chat bubbles from the saved text
            _messages.add({
              "role": savedHistory[i]["role"] == "assistant" ? "ai" : "user",
              "text": savedHistory[i]["content"],
            });
          }
        } else {
          _messages.add({
            "role": "ai",
            "text":
                "Hello! I am your AI Academic Advisor. I have just synced with your secure vault. How can I help you optimize your schedule today?",
          });
        }
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "ai",
          "text": "Error connecting to your vault. Let's chat generally!",
        });
        _isInitializing = false;
      });
    }
  }

  // Opens the browser file picker / gallery and handles the file as bytes
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  // Sends the text and optional image payload to your upgraded AIService
  Future<void> _handleSend() async {
    if (_controller.text.trim().isEmpty && _imageBytes == null) return;

    String userMsg = _controller.text.trim();
    String? base64String;
    Uint8List? previewBytes =
        _imageBytes; // Keep a local reference for the chat layout

    if (_imageBytes != null) {
      base64String = base64Encode(_imageBytes!);
    }

    _controller.clear();
    setState(() {
      _messages.add({
        "role": "user",
        "text": userMsg,
        "imageBytes":
            previewBytes, // Saves local bytes to render the user's sent photo in the UI
      });
      _isTyping = true;
      // Clear the attachment preview slots immediately after sending
      _selectedImage = null;
      _imageBytes = null;
    });

    // Pass both parameters down to your upgraded Groq network handler
    String response = await _aiService.sendMessage(
      userMsg,
      base64Image: base64String,
    );

    if (mounted) {
      setState(() {
        _messages.add({"role": "ai", "text": response});
        _isTyping = false;
      });
      FirebaseService().saveChatHistory(_aiService.currentMemory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text("AI Academic Advisor"),
        backgroundColor: Colors.indigoAccent,
      ),
      body: Column(
        children: [
          // The Chat Bubble List
          Expanded(
            child: _isInitializing
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.indigoAccent,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      bool isMe = msg["role"] == "user";
                      bool hasImage = msg["imageBytes"] != null;

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.indigoAccent
                                : Colors.grey[800],
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isMe
                                  ? const Radius.circular(0)
                                  : const Radius.circular(16),
                              bottomLeft: isMe
                                  ? const Radius.circular(16)
                                  : const Radius.circular(0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // If the message contains an image, display it cleanly inside the bubble layout
                              if (hasImage)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      msg["imageBytes"] as Uint8List,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              if (msg["text"]!.isNotEmpty)
                                Text(
                                  msg["text"]!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // "AI is thinking..." indicator
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "AI Advisor is analyzing...",
                  style: TextStyle(
                    color: Colors.indigoAccent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          // Active Attachment Preview Bar (pops open when a file is selected)
          if (_imageBytes != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.indigoAccent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          _imageBytes!,
                          height: 90,
                          width: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedImage = null;
                          _imageBytes = null;
                        }),
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.red,
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // The Text Input Bar
          Container(
            padding: EdgeInsets.only(
              left: 4,
              right: 12,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            color: Colors.grey[850],
            child: Row(
              children: [
                // Media Gallery Button
                IconButton(
                  icon: const Icon(
                    Icons.add_photo_alternate,
                    color: Colors.indigoAccent,
                    size: 28,
                  ),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction
                        .send, // <--- 1. Changes the keyboard button to a "Send" icon
                    onSubmitted: (_) =>
                        _handleSend(), // <--- 2. Triggers your send function when Enter is pressed
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _imageBytes != null
                          ? "Add a caption..."
                          : "Ask about your attendance strategy...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.indigoAccent,
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _handleSend,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

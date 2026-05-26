import 'package:flutter/material.dart';
import '../models/academic_models.dart';
import '../services/firebase_service.dart';

class SubjectVaultScreen extends StatefulWidget {
  final Subject subject; 
  const SubjectVaultScreen({super.key, required this.subject});

  @override
  State<SubjectVaultScreen> createState() => _SubjectVaultScreenState();
}

class _SubjectVaultScreenState extends State<SubjectVaultScreen> {
  final FirebaseService _dbService = FirebaseService();
  final String currentSemesterId = 'sem_01';
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.subject.takeawayNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showAddResourceSheet() {
    String newTitle = '';
    String newUrl = '';
    String selectedType = 'Link'; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Add Study Material", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Title', labelStyle: TextStyle(color: Colors.grey)), onChanged: (val) => newTitle = val),
                  const SizedBox(height: 12),
                  TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'URL / Link', labelStyle: TextStyle(color: Colors.grey)), onChanged: (val) => newUrl = val),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Material Type:", style: TextStyle(color: Colors.white)),
                      DropdownButton<String>(
                        value: selectedType,
                        dropdownColor: Colors.grey[850],
                        style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold),
                        underline: Container(height: 2, color: Colors.indigoAccent),
                        items: ['PDF/Drive', 'YouTube Video', 'PYQ', 'Link'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                        onChanged: (String? newValue) { if (newValue != null) setModalState(() => selectedType = newValue); },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: () {
                        if (newTitle.isNotEmpty && newUrl.isNotEmpty) {
                          ResourceItem newItem = ResourceItem(id: '', title: newTitle, url: newUrl, type: selectedType, dateAdded: DateTime.now().toIso8601String());
                          _dbService.addResource(currentSemesterId, widget.subject.id, newItem);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text("Save Material", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _getIconForType(String type) {
    if (type == 'YouTube Video') return Icons.play_circle_filled;
    if (type == 'PDF/Drive') return Icons.picture_as_pdf;
    if (type == 'PYQ') return Icons.history_edu;
    return Icons.link;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text("${widget.subject.name} Vault", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.indigoAccent,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[850], border: Border(bottom: BorderSide(color: Colors.grey[800]!, width: 2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Class notes, syllabus details, or reminders...",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    _dbService.updateSubjectData(currentSemesterId, widget.subject.id, {'takeawayNote': _noteController.text.trim()});
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notes saved!"), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
                  },
                  icon: const Icon(Icons.save, size: 16, color: Colors.white),
                  label: const Text("Save Notes", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                )
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<ResourceItem>>(
              stream: _dbService.streamResources(currentSemesterId, widget.subject.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Vault is empty. Add links below!", style: TextStyle(color: Colors.grey)));

                final resources = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: resources.length,
                  itemBuilder: (context, index) {
                    final item = resources[index];
                    return Card(
                      color: Colors.grey[800],
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(_getIconForType(item.type), color: Colors.indigoAccent, size: 32),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        subtitle: Text(item.type, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        trailing: const Icon(Icons.open_in_new, color: Colors.white54),
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Link saved: ${item.url}"))),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddResourceSheet,
        backgroundColor: Colors.indigoAccent,
        child: const Icon(Icons.add_link, color: Colors.white),
      ),
    );
  }
}
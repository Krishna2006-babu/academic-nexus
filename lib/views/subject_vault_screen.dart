
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/academic_models.dart';
import '../services/firebase_service.dart';

class SubjectVaultScreen extends StatefulWidget {
  final Subject subject;

  const SubjectVaultScreen({
    super.key,
    required this.subject,
  });

  @override
  State<SubjectVaultScreen> createState() =>
      _SubjectVaultScreenState();
}

class _SubjectVaultScreenState extends State<SubjectVaultScreen> {
  final FirebaseService _dbService = FirebaseService();

  final String currentSemesterId = 'sem_01';

  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController =
        TextEditingController(text: widget.subject.takeawayNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ==========================================
  // ADD STUDY MATERIAL
  // ==========================================

  void _showAddResourceSheet() {
    String selectedType = 'Link';

    Uint8List? selectedFileBytes;
    String? selectedFileName;

    bool isSaving = false;
    String savingMessage = 'Preparing material...';

    final titleController = TextEditingController();
    final urlController = TextEditingController();

    final parentContext = context;

    showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bool isUploadType =
                selectedType == 'PDF' ||
                selectedType == 'Image';

            // ==========================================
            // FILE PICKER
            // ==========================================

            
Future<void> pickStudyFile() async {
  try {
    final FilePickerResult? result =
        await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: selectedType == 'PDF'
          ? ['pdf']
          : ['png', 'jpg', 'jpeg'],
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final PlatformFile file = result.files.single;

    if (file.bytes == null) {
      throw Exception('Unable to read selected file.');
    }

    if (!sheetContext.mounted) return;

    setModalState(() {
      selectedFileBytes = file.bytes;
      selectedFileName = file.name;
    });
  } catch (e) {
    if (!parentContext.mounted) return;

ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(
        content: Text('File selection failed: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}


            // ==========================================
            // SAVE MATERIAL
            // ==========================================

            
Future<void> saveMaterial() async {
  final String title = titleController.text.trim();
  final String url = urlController.text.trim();

  if (title.isEmpty) {
    ScaffoldMessenger.of(parentContext).showSnackBar(
      const SnackBar(content: Text('Please enter a title.')),
    );
    return;
  }

  if (isUploadType &&
      (selectedFileBytes == null || selectedFileName == null)) {
    ScaffoldMessenger.of(parentContext).showSnackBar(
      const SnackBar(content: Text('Please select a file.')),
    );
    return;
  }

  if (!isUploadType && url.isEmpty) {
    ScaffoldMessenger.of(parentContext).showSnackBar(
      const SnackBar(content: Text('Please enter a URL.')),
    );
    return;
  }

  setModalState(() {
    isSaving = true;
    savingMessage = 'Preparing material...';
  });

  try {
    String resourceUrl = url;

    // STEP 1: Upload PDF or image
    if (isUploadType) {
      debugPrint('SAVE FLOW: Starting Storage upload');

      setModalState(() {
        savingMessage = 'Uploading file to Firebase Storage...';
      });

      resourceUrl = await _dbService.uploadVaultFile(
        semesterId: currentSemesterId,
        subjectId: widget.subject.id,
        bytes: selectedFileBytes!,
        originalFileName: selectedFileName!,
      );

      debugPrint('SAVE FLOW: Storage upload successful');
    }

    if (!sheetContext.mounted) return;

    // STEP 2: Prepare Firestore resource
    setModalState(() {
      savingMessage = 'Saving material details...';
    });

    final ResourceItem newItem = ResourceItem(
      id: '',
      title: title,
      url: resourceUrl,
      type: selectedType,
      dateAdded: DateTime.now().toIso8601String(),
    );

    // STEP 3: Save to Firestore
    debugPrint('SAVE FLOW: Starting Firestore save');

    await _dbService.addResource(
      currentSemesterId,
      widget.subject.id,
      newItem,
    ).timeout(
      const Duration(seconds: 45),
    );

    debugPrint('SAVE FLOW: Firestore save successful');

    // STEP 4: Close dialog and show success
    if (!parentContext.mounted || !sheetContext.mounted) {
      return;
    }

    Navigator.of(sheetContext).pop();

    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(
        content: Text(
          isUploadType
              ? 'File uploaded and saved successfully!'
              : 'Study material saved successfully!',
        ),
        backgroundColor: Colors.green,
      ),
    );

  } catch (e) {
    debugPrint('SAVE MATERIAL ERROR: $e');

    if (!parentContext.mounted) return;

    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(
        content: Text('Failed to save material: $e'),
        backgroundColor: Colors.red,
      ),
    );

  } finally {
    if (sheetContext.mounted) {
      setModalState(() {
        isSaving = false;
      });
    }
  }
}


            // ==========================================
            // DIALOG UI
            // ==========================================

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext)
                      .viewInsets
                      .bottom,
                  left: 20,
                  right: 20,
                  top: 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Study Material',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // TITLE
                      TextField(
                        controller: titleController,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          labelStyle: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // MATERIAL TYPE
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Material Type:',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),

                          DropdownButton<String>(
                            value: selectedType,
                            dropdownColor: Colors.grey[850],
                            style: const TextStyle(
                              color: Colors.indigoAccent,
                              fontWeight: FontWeight.bold,
                            ),
                            underline: Container(
                              height: 2,
                              color: Colors.indigoAccent,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Link',
                                child: Text('Link'),
                              ),
                              DropdownMenuItem(
                                value: 'YouTube Video',
                                child: Text('YouTube Video'),
                              ),
                              DropdownMenuItem(
                                value: 'PDF/Drive',
                                child: Text('PDF/Drive Link'),
                              ),
                              DropdownMenuItem(
                                value: 'PYQ',
                                child: Text('PYQ'),
                              ),
                              DropdownMenuItem(
                                value: 'PDF',
                                child: Text('PDF Upload'),
                              ),
                              DropdownMenuItem(
                                value: 'Image',
                                child: Text('Image Upload'),
                              ),
                            ],
                            onChanged: isSaving
                                ? null
                                : (String? newValue) {
                                    if (newValue == null) {
                                      return;
                                    }

                                    setModalState(() {
                                      selectedType = newValue;
                                      selectedFileBytes = null;
                                      selectedFileName = null;
                                    });
                                  },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // LINK INPUT
                      if (!isUploadType)
                        TextField(
                          controller: urlController,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'URL / Link',
                            hintText:
                                'Enter your material link',
                            labelStyle: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ),

                      // FILE UPLOAD
                      if (isUploadType) ...[
                        OutlinedButton.icon(
                          onPressed:
                              isSaving ? null : pickStudyFile,
                          icon: Icon(
                            selectedType == 'PDF'
                                ? Icons.picture_as_pdf
                                : Icons.image,
                          ),
                          label: Text(
                            selectedFileName == null
                                ? selectedType == 'PDF'
                                    ? 'Choose PDF File'
                                    : 'Choose Image'
                                : 'Change File',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Colors.indigoAccent,
                            side: const BorderSide(
                              color: Colors.indigoAccent,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),

                        if (selectedFileName != null) ...[
                          const SizedBox(height: 12),

                          Container(
                            padding:
                                const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selectedType == 'PDF'
                                      ? Icons.picture_as_pdf
                                      : Icons.image,
                                  color: Colors.indigoAccent,
                                ),

                                const SizedBox(width: 10),

                                Expanded(
                                  child: Text(
                                    selectedFileName!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                    overflow:
                                        TextOverflow.ellipsis,
                                  ),
                                ),

                                IconButton(
                                  onPressed: isSaving
                                      ? null
                                      : () {
                                          setModalState(() {
                                            selectedFileBytes =
                                                null;
                                            selectedFileName =
                                                null;
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),

                        Text(
                          selectedType == 'PDF'
                              ? 'Supported format: PDF'
                              : 'Supported formats: PNG, JPG, JPEG',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // SAVE BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.indigoAccent,
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 15,
                            ),
                          ),
                          onPressed:
                              isSaving ? null : saveMaterial,
                          child: isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child:
                                      CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Save Material',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      urlController.dispose();
    });
  }

  // ==========================================
  // RESOURCE ICONS
  // ==========================================

  IconData _getIconForType(String type) {
    if (type == 'YouTube Video') {
      return Icons.play_circle_filled;
    }

    if (type == 'PDF/Drive' || type == 'PDF') {
      return Icons.picture_as_pdf;
    }

    if (type == 'Image') {
      return Icons.image;
    }

    if (type == 'PYQ') {
      return Icons.history_edu;
    }

    return Icons.link;
  }

  // ==========================================
  // OPEN RESOURCE
  // ==========================================

  Future<void> _openResource(ResourceItem item) async {
    try {
      final String rawUrl = item.url.trim();

      Uri? uri = Uri.tryParse(rawUrl);

      if (uri != null && !uri.hasScheme) {
        uri = Uri.tryParse('https://$rawUrl');
      }

      if (uri == null || !uri.hasAuthority) {
        throw Exception('Invalid resource URL.');
      }

      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception('Unable to open this resource.');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open material: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],

      appBar: AppBar(
        title: Text(
          '${widget.subject.name} Vault',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.indigoAccent,
      ),

      body: Column(
        children: [
          // ==========================================
          // NOTES SECTION
          // ==========================================

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[800]!,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText:
                        'Class notes, syllabus details, or reminders...',
                    hintStyle: TextStyle(
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                ),

                const SizedBox(height: 8),

                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await _dbService.updateSubjectData(
                        currentSemesterId,
                        widget.subject.id,
                        {
                          'takeawayNote':
                              _noteController.text.trim(),
                        },
                      );

                      if (!mounted) return;

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text('Notes saved!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to save notes: $e',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.save,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Save Notes',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ==========================================
          // RESOURCE LIST
          // ==========================================

          Expanded(
            child: StreamBuilder<List<ResourceItem>>(
              stream: _dbService.streamResources(
                currentSemesterId,
                widget.subject.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Unable to load study materials.',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Vault is empty. Add links or files below!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final resources = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: resources.length,
                  itemBuilder: (context, index) {
                    final item = resources[index];

                    return Card(
                      color: Colors.grey[800],
                      margin:
                          const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          _getIconForType(item.type),
                          color: Colors.indigoAccent,
                          size: 32,
                        ),

                        title: Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        subtitle: Text(
                          item.type,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),

                        trailing: const Icon(
                          Icons.open_in_new,
                          color: Colors.white54,
                        ),

                        onTap: () => _openResource(item),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ==========================================
      // ADD MATERIAL BUTTON
      // ==========================================

      floatingActionButton: FloatingActionButton(
        onPressed: _showAddResourceSheet,
        backgroundColor: Colors.indigoAccent,
        child: const Icon(
          Icons.add_link,
          color: Colors.white,
        ),
      ),
    );
  }
}

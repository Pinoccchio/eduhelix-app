import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';

class TextToSpeech extends StatefulWidget {
  final String studentNumber;

  TextToSpeech({required this.studentNumber});

  @override
  _TextToSpeechState createState() => _TextToSpeechState();
}

class _TextToSpeechState extends State<TextToSpeech> {
  List<UploadedFile> uploadedFiles = [];

  @override
  void initState() {
    super.initState();
    _fetchUploadedFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Text-To-Speech',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FileUploadWidget(onFilePicked: (result) {
              if (result != null) {
                PlatformFile file = result.files.first;
                _handleFileSelection(context, file);
              }
            }),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.studentNumber)
                  .collection('files')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset('assets/animated_icon/empty-animation.json', width: 200, height: 200),
                        SizedBox(height: 20),
                        Text('No files available.'),
                      ],
                    ),
                  );
                }

                final files = snapshot.data!.docs;

                return Column(
                  children: files.map((file) {
                    final fileName = file['fileName'] ?? 'Unknown';
                    final fileURL = file['fileURL'] ?? '';
                    final uploadedAt = file['uploadedAt'] != null
                        ? _formatDate(file['uploadedAt'].toDate())
                        : 'Unknown Date';

                    return FileContainer(
                      fileName: fileName,
                      uploadedAt: uploadedAt,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FileDetailsPage(
                              fileName: fileName,
                              fileURL: fileURL,
                            ),
                          ),
                        );
                      },
                      onDelete: () async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.studentNumber)
                            .collection('files')
                            .doc(file.id)
                            .delete();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'File deleted successfully',
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final DateFormat formatter = DateFormat('MM/dd/yyyy \'at\' h:mm a');
    return formatter.format(dateTime);
  }

  Future<void> _handleFileSelection(BuildContext context, PlatformFile file) async {
    Uint8List? fileBytes = file.bytes;

    if (fileBytes != null) {
      print('File selected: ${file.name}, Extension: ${file.extension}');

      // Show a snackbar when upload starts
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploading ${file.name}...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );

      // Handle if file is a PDF
      if (file.extension == 'pdf') {
        print('PDF file detected. Proceeding with upload...');
        await _uploadPdfToFirebase(file, fileBytes, widget.studentNumber);
      }
      // Handle if file is a Word document
      else if (file.extension == 'doc' || file.extension == 'docx') {
        print('Word document detected. Redirecting to conversion...');
        await _launchConversionUrl(context);
      } else {
        print('Unsupported file type detected: ${file.extension}');
      }
    } else {
      print('File bytes are null. Attempting to read file from path...');
      try {
        File pickedFile = File(file.path!);
        fileBytes = await pickedFile.readAsBytes();

        if (fileBytes != null) {
          print('File read successfully from path. Extension: ${file.extension}');

          // Show a snackbar when upload starts
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uploading ${file.name}...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 3),
            ),
          );

          // Handle if file is a PDF
          if (file.extension == 'pdf') {
            print('PDF file detected. Proceeding with upload...');
            await _uploadPdfToFirebase(file, fileBytes, widget.studentNumber);
          }
          // Handle if file is a Word document
          else if (file.extension == 'doc' || file.extension == 'docx') {
            print('Word document detected. Redirecting to conversion...');
            await _launchConversionUrl(context);
          } else {
            print('Unsupported file type detected: ${file.extension}');
          }
        } else {
          print('Error: fileBytes is null after reading from path');
        }
      } catch (e) {
        print('Error reading file from path: $e');
      }
    }
  }

  Future<void> _uploadPdfToFirebase(PlatformFile file, Uint8List fileBytes, String studentNumber) async {
    try {
      String fileName = file.name;
      DateTime uploadTime = DateTime.now();  // Get the current time

      // Create a reference to the storage location
      Reference storageRef = FirebaseStorage.instance.ref().child('uploads/$studentNumber/$fileName');

      // Upload the file
      await storageRef.putData(fileBytes);

      // Get the file's download URL
      String downloadURL = await storageRef.getDownloadURL();

      // Save the file info in Firestore using studentNumber with timestamp
      var docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentNumber)
          .collection('files')
          .add({
        'fileName': fileName,
        'fileURL': downloadURL,
        'uploadedAt': Timestamp.fromDate(uploadTime),
      });

      // Add file to the local state for UI display
      setState(() {
        uploadedFiles.add(UploadedFile(
          id: docRef.id,  // Get the document ID from Firestore
          fileName: fileName,
          fileBytes: fileBytes,
          downloadURL: downloadURL,  // Save URL instead of fileBytes
          uploadedAt: Timestamp.fromDate(uploadTime),
        ));
      });

      // Show a snackbar when the upload is complete
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File ${file.name} uploaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error uploading file to Firebase: $e');

      // Show a snackbar when there's an error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload ${file.name}. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _launchConversionUrl(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('The selected file is a Word document. Convert it to PDF. Redirecting...'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );

    await Future.delayed(const Duration(seconds: 5));

    const url = 'https://www.ilovepdf.com/word_to_pdf';
    Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _fetchUploadedFiles() async {
    try {
      final fileDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentNumber)
          .collection('files')
          .get();

      List<UploadedFile> files = [];

      for (var doc in fileDocs.docs) {
        final data = doc.data();
        final fileName = data['fileName'] ?? '';
        final fileURL = data['fileURL'] ?? '';
        final uploadedAt = data['uploadedAt'] as Timestamp;  // Cast uploadedAt to Timestamp

        // Fetch file bytes from URL
        final fileBytes = await _fetchFileBytes(fileURL);

        files.add(UploadedFile(
          id: doc.id,  // Store document ID
          fileName: fileName,
          fileBytes: fileBytes,
          downloadURL: fileURL,
          uploadedAt: uploadedAt,  // Add uploadedAt
        ));
      }

      setState(() {
        uploadedFiles = files;
      });
    } catch (e) {
      print('Error fetching files: $e');
    }
  }

  // Helper method to fetch file bytes from URL
  Future<Uint8List> _fetchFileBytes(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to load file');
    }
  }
}

class UploadedFile {
  final String id;  // Add id field
  final String fileName;
  final Uint8List fileBytes;
  final String downloadURL;
  final Timestamp uploadedAt;  // Assuming this is a Timestamp type

  UploadedFile({
    required this.id,  // Add id to the constructor
    required this.fileName,
    required this.fileBytes,
    required this.downloadURL,
    required this.uploadedAt,
  });
}


class FileUploadWidget extends StatelessWidget {
  final Function(FilePickerResult?) onFilePicked;

  FileUploadWidget({required this.onFilePicked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx'],
        );
        onFilePicked(result);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upload File', style: TextStyle(color: Colors.white)),
                Text('PDF or Word File', style: TextStyle(color: Colors.grey)),
              ],
            ),
            const Icon(Icons.file_upload, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class FileContainer extends StatelessWidget {
  final String fileName;
  final String uploadedAt;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const FileContainer({
    required this.fileName,
    required this.uploadedAt,
    required this.onTap,
    required this.onDelete,
  });

  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button to dismiss dialog
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800], // Set the background color of the dialog
          title: Text(
            'Confirm Deletion',
            style: TextStyle(color: Colors.white), // Set title color
          ),
          content: Text(
            'Are you sure you want to delete "$fileName"?',
            style: TextStyle(color: Colors.white), // Set content color
          ),
          actions: <Widget>[
            TextButton(
              child: Text('No'),
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text('Yes'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                onDelete(); // Call the delete function
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  Text(
                    uploadedAt,
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteConfirmationDialog(context),
          ),
        ],
      ),
    );
  }
}

class FileDetailsPage extends StatefulWidget {
  final String fileName;
  final String fileURL;

  FileDetailsPage({required this.fileName, required this.fileURL});

  @override
  _FileDetailsPageState createState() => _FileDetailsPageState();
}

class _FileDetailsPageState extends State<FileDetailsPage> {
  double _playbackSpeed = 0.5;
  bool _isPlaying = false;
  PdfViewerController _pdfViewerController = PdfViewerController();
  final FlutterTts _flutterTts = FlutterTts();
  String _selectedText = '';
  String _selectedLanguage = 'en-US';
  List<String> _sentences = [];
  int _currentSentenceIndex = 0;
  String _currentSentence = '';

  @override
  void initState() {
    super.initState();
    _flutterTts.setSpeechRate(_playbackSpeed);
    _flutterTts.setLanguage(_selectedLanguage);
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          if (_currentSentenceIndex < _sentences.length - 1) {
            _currentSentenceIndex++;
            _speakCurrentSentence();
          } else {
            _isPlaying = false;
            _currentSentence = '';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  void _onLanguageChanged(String? language) {
    setState(() {
      _selectedLanguage = language ?? 'en-US';
      _flutterTts.setLanguage(_selectedLanguage);
    });
  }

  void _speakCurrentSentence() {
    if (_currentSentenceIndex < _sentences.length) {
      String sentence = _sentences[_currentSentenceIndex];
      _flutterTts.speak(sentence);
      setState(() {
        _currentSentence = sentence;
      });
    }
  }

  Future<void> _speak() async {
    if (_selectedText.isEmpty) {
      await _flutterTts.speak('Text is empty!');
    } else {
      _sentences = _selectedText.split(RegExp(r'(?<=[.!?])\s+'));
      _currentSentenceIndex = 0;
      _speakCurrentSentence();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  Future<void> _pause() async {
    await _flutterTts.pause();
    setState(() {
      _isPlaying = false;
    });
  }

  Future<void> _stop() async {
    await _flutterTts.stop();
    setState(() {
      _isPlaying = false;
      _currentSentenceIndex = 0;
      _currentSentence = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            _flutterTts.stop();
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.fileName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  SfPdfViewer.network(
                    widget.fileURL,
                    controller: _pdfViewerController,
                    enableTextSelection: true,
                    onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _selectedText = details.selectedText ?? '';
                            print(_selectedText);
                          });
                        }
                      });
                    },
                  ),
                  if (_currentSentence.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        color: Colors.black.withOpacity(0.7),
                        child: Text(
                          _currentSentence,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ControlButtonsSection(
              onPlayPause: () {
                if (_isPlaying) {
                  _pause();
                } else {
                  if (_selectedText.isNotEmpty) {
                    _speak();
                  } else {
                    _flutterTts.speak("There is no text selected to read.");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("There is no text selected to read."),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              onSpeedChanged: (speed) {
                setState(() {
                  _playbackSpeed = speed ?? 0.5;
                  _flutterTts.setSpeechRate(_playbackSpeed);
                });
              },
              currentSpeed: _playbackSpeed,
              isPlaying: _isPlaying,
              selectedLanguage: _selectedLanguage,
              onLanguageChanged: _onLanguageChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class ControlButtonsSection extends StatelessWidget {
  final VoidCallback onPlayPause;
  final ValueChanged<double?> onSpeedChanged;
  final double currentSpeed;
  final bool isPlaying;
  final String selectedLanguage;
  final ValueChanged<String?> onLanguageChanged;

  ControlButtonsSection({
    required this.onPlayPause,
    required this.onSpeedChanged,
    required this.currentSpeed,
    required this.isPlaying,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: 50,
                color: isPlaying ? Colors.red : Color(0xFF73CBE6),
              ),
              onPressed: onPlayPause,
            ),
          ],
        ),
        const SizedBox(height: 20),
        PlaybackSpeedControl(
          onSpeedChanged: onSpeedChanged,
          currentSpeed: currentSpeed,
          selectedLanguage: selectedLanguage,
          onLanguageChanged: onLanguageChanged,
        ),
      ],
    );
  }
}

class PlaybackSpeedControl extends StatelessWidget {
  final ValueChanged<double?> onSpeedChanged;
  final double currentSpeed;
  final String selectedLanguage;
  final ValueChanged<String?> onLanguageChanged;

  PlaybackSpeedControl({
    required this.onSpeedChanged,
    required this.currentSpeed,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'Speed: ${currentSpeed}x',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 20),
            DropdownButton<double?>(
              value: currentSpeed,
              items: [0.5, 1.0, 1.5, 2.0].map((speed) {
                return DropdownMenuItem<double?>(
                  value: speed,
                  child: Text(
                    '${speed}x',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onSpeedChanged,
              dropdownColor: Colors.grey[800],
              underline: SizedBox(),
            ),
          ],
        ),
        DropdownButton<String?>(
          value: selectedLanguage,
          items: [
            DropdownMenuItem(
              value: 'en-US',
              child: Text(
                'English',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            DropdownMenuItem(
              value: 'fil-PH',
              child: Text(
                'Filipino',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          onChanged: onLanguageChanged,
          dropdownColor: Colors.grey[800],
          underline: SizedBox(),
        ),
      ],
    );
  }
}
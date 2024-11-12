import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/plant_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../Study_Planner/study_planner.dart';
import '../text_to_speech.dart';
import 'menu_item.dart';

class Home extends StatefulWidget {
  final String studentNumber;
  final String? firstName;
  final String? lastName;

  const Home({
    required this.studentNumber,
    this.firstName,
    this.lastName,
  });

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final TextEditingController _searchController = TextEditingController();
  String? _profileImageUrl;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);

    if (widget.studentNumber.isNotEmpty) {
      _listenForUserData();
    } else {
      Fluttertoast.showToast(
        msg: "Student number is empty. Please sign in again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    }
  }

  void _listenForUserData() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.studentNumber)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var user = snapshot.data()!;
        if (mounted) {
          setState(() {
            _profileImageUrl = user['profilePictureUrl'];
          });
        }
      } else {
        Fluttertoast.showToast(
          msg: "User data does not exist.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
            _buildWelcomeText(),
            const SizedBox(height: 8),
            _buildHeaderRow(),
            const SizedBox(height: 24),
            _buildSearchBar(),
            const SizedBox(height: 24),
            _buildMenuTitle(),
            const SizedBox(height: 16),
            _buildMenuItems(context),
            const SizedBox(height: 32),
            _buildTranscriptionsTitle(),
            const SizedBox(height: 10),
            _buildTranscriptionsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Align(
      alignment: Alignment.topLeft,
      child: Text(
        'Welcome to EduHelix',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w400,
          fontSize: 12,
          height: 1.3,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            widget.firstName ?? 'User',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 32,
              height: 1.1,
              color: Colors.white,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/profile',
              arguments: {
                'firstName': widget.firstName,
                'lastName': widget.lastName,
                'studentNumber': widget.studentNumber,
                'profilePictureUrl': _profileImageUrl,
              },
            );
          },
          child: SizedBox(
            width: 24,
            height: 24,
            child: Lottie.asset(
              'assets/animated_icon/wired-flat-268-avatar-man.json',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(36),
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(left: 8),
            width: 18,
            height: 18,
            child: SvgPicture.asset('assets/vectors/vector_8_x2.svg'),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 16,
                  color: const Color(0xFF949494),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTitle() {
    return Align(
      alignment: Alignment.topLeft,
      child: Text(
        'Menu',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          height: 1.3,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // GestureDetector for Study Planner navigation
        GestureDetector(
          onTap: () {



            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudyPlanner(
                  studentNumber: widget.studentNumber,
                ),
              ),
            );



            /*

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlantScreen(),
              ),
            );

             */



          },
          child: MenuItem(
            iconPath: 'assets/animated_icon/study-planner-animated.json',
            label: 'Study Planner',
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TextToSpeech(
                  studentNumber: widget.studentNumber,
                ),
              ),
            );
          },
          child: MenuItem(
            iconPath: 'assets/animated_icon/animated-microphone.json',
            label: 'Text-To-Speech',
          ),
        ),
      ],
    );
  }


  Widget _buildTranscriptionsTitle() {
    return Align(
      alignment: Alignment.topLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Transcriptions',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              height: 1.3,
              color: Colors.white,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TextToSpeech(
                    studentNumber: widget.studentNumber,
                  ),
                ),
              );
            },
            child: Text(
              'See all',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.1,
                color: const Color(0xFF73CBE6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionsList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
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

          // Filter files based on search query
          final filteredFiles = files.where((file) {
            final fileName = (file['fileName'] ?? '').toLowerCase();
            return fileName.contains(_searchQuery);
          }).toList();

          return ListView.builder(
            itemCount: filteredFiles.length,
            itemBuilder: (context, index) {
              final file = filteredFiles[index];
              final fileName = file['fileName'] ?? 'Unknown';
              final uploadedAt = file['uploadedAt'] != null
                  ? _formatDate(file['uploadedAt'].toDate())
                  : 'Unknown Date';
              final fileUrl = file['fileURL'] ?? ''; // Corrected field name

              return FileContainer(
                fileName: fileName,
                uploadedAt: uploadedAt,
                onTap: () {
                  if (fileUrl.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FileDetailsPage(
                          fileName: fileName,
                          fileURL: fileUrl,
                        ),
                      ),
                    );
                  } else {
                    Fluttertoast.showToast(
                      msg: "File URL is missing.",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                  }
                },
                onDelete: () async {
                  await _showDeleteConfirmationDialog(context, file.id);
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final DateFormat formatter = DateFormat('MM/dd/yyyy \'at\' h:mm a');
    return formatter.format(dateTime);
  }

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, String fileId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: Text(
            'Delete File',
            style: TextStyle(color: Colors.white),
          ),
          content: Text('Are you really sure you want to delete this file?',
              style: TextStyle(color: Colors.white)),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.studentNumber)
                    .collection('files')
                    .doc(fileId)
                    .delete();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
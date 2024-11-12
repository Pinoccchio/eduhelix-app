import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/Study_Planner/update_data.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:home_widget/home_widget.dart';
import 'package:rive/rive.dart';

class StudyPlanner extends StatefulWidget {
  final String studentNumber;

  const StudyPlanner({Key? key, required this.studentNumber}) : super(key: key);

  @override
  _StudyPlannerState createState() => _StudyPlannerState();
}

class _StudyPlannerState extends State<StudyPlanner> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, Artboard?> _riveArtboards = {};
  Map<String, SMIInput<double>?> _progressInputs = {};
  Timer? _taskCheckTimer;
  Timer? _uiUpdateTimer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startRealTimeTaskChecker();
    _startUiUpdateTimer();
    _updateWidgetStudentNumber();
  }

  void _loadRiveAnimation(String taskId) async {
    if (_riveArtboards.containsKey(taskId)) return;

    final data = await rootBundle.load('assets/animated_icon/tree_demo.riv');
    final file = RiveFile.import(data);
    final artboard = file.mainArtboard;
    var controller = StateMachineController.fromArtboard(artboard, 'Grow');
    if (controller != null) {
      artboard.addController(controller);
      _progressInputs[taskId] = controller.findInput<double>('input') as SMINumber;
    }
    setState(() => _riveArtboards[taskId] = artboard);
  }

  @override
  void dispose() {
    _disposed = true;
    _tabController.dispose();
    _taskCheckTimer?.cancel();
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  void _startUiUpdateTimer() {
    _uiUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_disposed) {
        setState(() {});
      }
    });
  }

  Future<void> _updateWidgetStudentNumber() async {
    if (_disposed) return;
    try {
      await HomeWidget.saveWidgetData<String>('studentNumber', widget.studentNumber);
      await HomeWidget.updateWidget(
        name: 'StudyPlannerWidgetProvider',
        iOSName: 'StudyPlannerWidgetProvider',
      );
      print('Student number saved for widget: ${widget.studentNumber}');
    } catch (e) {
      print('Error updating widget: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        flexibleSpace: Center(
          child: Text(
            'Study Planner',
            style: GoogleFonts.almarai(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          indicator: BoxDecoration(
            color: const Color(0xFF2FD1C5),
            borderRadius: BorderRadius.circular(8),
          ),
          tabs: [
            _buildTab('To Do'),
            _buildTab('Missed'),
            _buildTab('Completed'),
          ],
        ),
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            _buildNewTaskButton(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTaskList('To Do'),
                  _buildTaskList('Missed'),
                  _buildTaskList('Completed'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewTaskButton() {
    return Container(
      margin: const EdgeInsets.only(top: 10, right: 24),
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () {
          _showNewTaskDialog(context);
        },
        icon: const Icon(Icons.add, color: Color(0xFF57E597)),
        label: Text(
          'New Task',
          style: GoogleFonts.lato(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: const Color(0xFF57E597)),
        ),
      ),
    );
  }

  void _showNewTaskDialog(BuildContext context) {
    final subjectController = TextEditingController();
    final startDateTimeController = TextEditingController();
    final endDateTimeController = TextEditingController();
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenSize = MediaQuery.of(context).size;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFF000000),
          child: Container(
            width: screenSize.width * 0.9,
            height: screenSize.height * 0.7,
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Create a Task',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildDialogTextField('Subject', controller: subjectController),
                  const SizedBox(height: 20),
                  _buildDateTimePicker('Start Date & Time', controller: startDateTimeController, context: context),
                  const SizedBox(height: 20),
                  _buildDateTimePicker('End Date & Time', controller: endDateTimeController, context: context),
                  const SizedBox(height: 20),
                  _buildDialogTextField('Details', controller: detailsController),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2FD1C5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (subjectController.text.isEmpty ||
                            startDateTimeController.text.isEmpty ||
                            endDateTimeController.text.isEmpty ||
                            detailsController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill in all fields.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.studentNumber)
                            .collection('to-do-files')
                            .add({
                          'subject': subjectController.text,
                          'startTime': DateTime.parse(startDateTimeController.text),
                          'endTime': DateTime.parse(endDateTimeController.text),
                          'details': detailsController.text,
                          'status': 'To Do',
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        Navigator.of(context).pop();
                        _updateWidgetStudentNumber();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                        child: Text(
                          'Create',
                          style: GoogleFonts.almarai(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogTextField(String labelText, {required TextEditingController controller}) {
    return TextField(
      controller: controller,
      style: GoogleFonts.lato(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.lato(color: const Color(0xFF585A66)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE4EDFF)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF57E597)),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker(String labelText, {required TextEditingController controller, required BuildContext context}) {
    return TextField(
      controller: controller,
      readOnly: true,
      style: GoogleFonts.lato(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.lato(color: const Color(0xFF585A66)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE4EDFF)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF57E597)),
          borderRadius: BorderRadius.circular(8),
        ),
        suffixIcon: const Icon(Icons.calendar_today, color: Colors.white),
      ),
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );

        if (pickedDate != null) {
          TimeOfDay? pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );

          if (pickedTime != null) {
            final DateTime finalDateTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
            controller.text = finalDateTime.toIso8601String();
          }
        }
      },
    );
  }

  Widget _buildTab(String text) {
    return Tab(
      child: Container(
        alignment: Alignment.center,
        child: Text(
          text,
          style: GoogleFonts.lato(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(String taskType) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentNumber)
          .collection('to-do-files')
          .where('status', isEqualTo: taskType)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset('assets/animated_icon/empty-animation.json', width: 200, height: 200),
                const SizedBox(height: 20),
                const Text('No tasks available.', style: TextStyle(color: Colors.white)),
              ],
            ),
          );
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            DateTime endTime = (data['endTime'] as Timestamp).toDate();
            DateTime startTime = (data['startTime'] as Timestamp).toDate();

            return StreamBuilder<DateTime>(
              stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
              builder: (context, currentTimeSnapshot) {
                DateTime currentTime = currentTimeSnapshot.data ?? DateTime.now();
                double progress = _calculateProgress(startTime, endTime);

                if (taskType == 'To Do') {
                  _loadRiveAnimation(doc.id);
                  if (_progressInputs[doc.id] != null) {
                    _progressInputs[doc.id]!.value = progress * 100;
                  }
                }

                String dueDateString = DateFormat.yMMMd().add_jm().format(endTime);
                String timeLeftString = _getTimeLeftString(taskType, startTime, endTime, currentTime, data);

                return Card(
                  color: Colors.grey[850],
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text(data['subject'], style: const TextStyle(color: Colors.white)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Due: $dueDateString', style: const TextStyle(color: Colors.white70)),
                        Text(timeLeftString, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 10),
                        if (taskType == 'To Do' && _riveArtboards[doc.id] != null)
                          SizedBox(
                            height: 150,
                            child: Rive(
                              artboard: _riveArtboards[doc.id]!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey,
                          color: _getProgressColor(progress, taskType),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (taskType != 'Completed')
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _markTaskAsCompleted(doc.id),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editTask(context, doc.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteTask(context, doc.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  String _getTimeLeftString(String taskType, DateTime startTime, DateTime endTime, DateTime currentTime, Map<String, dynamic> data) {
    if (taskType == 'Completed') {
      DateTime completionTime = (data['completionTime'] as Timestamp?)?.toDate() ?? DateTime.now();
      Duration timeDifference = completionTime.difference(endTime);
      return timeDifference.isNegative
          ? 'Completed ${_formatDuration(timeDifference.abs())} early'
          : 'Completed ${_formatDuration(timeDifference)} late';
    } else if (taskType == 'To Do') {
      Duration timeLeft = endTime.difference(currentTime);
      return 'Time left: ${_formatDetailedDuration(timeLeft)}';
    } else {
      Duration timeOverdue = currentTime.difference(endTime);
      return 'Overdue by: ${_formatDetailedDuration(timeOverdue)}';
    }
  }

  String _formatDetailedDuration(Duration duration) {
    if (duration.isNegative) {
      return 'Task is overdue';
    }

    List<String> parts = [];

    if (duration.inDays > 0) {
      parts.add('${duration.inDays} day${duration.inDays > 1 ? 's' : ''}');
    }

    int hours = duration.inHours % 24;
    if (hours > 0) {
      parts.add('$hours hour${hours > 1 ? 's' : ''}');
    }

    int minutes = duration.inMinutes % 60;
    if (minutes > 0) {
      parts.add('$minutes minute${minutes > 1 ? 's' : ''}');
    }

    int seconds = duration.inSeconds % 60;
    parts.add('$seconds second${seconds > 1 ? 's' : ''}');

    return parts.join(', ');
  }

  Color _getProgressColor(double progress, String taskType) {
    if (taskType == 'Completed') {
      return const Color(0xFF57E597); // Green color for completed tasks
    }
    if (progress < 0.5) {
      return Colors.green;
    } else if (progress < 0.75) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return 'Overdue';
    }
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    }
    if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    }
    return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
  }

  void _startRealTimeTaskChecker() {
    _taskCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (_disposed) return;
      QuerySnapshot tasks = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentNumber)
          .collection('to-do-files')
          .where('status', isEqualTo: 'To Do')
          .get();

      DateTime currentTime = DateTime.now();
      for (var doc in tasks.docs) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime endTime = (data['endTime'] as Timestamp).toDate();

        if (endTime.isBefore(currentTime)) {
          _markTaskAsMissed(doc.id);
        }
      }
    });
  }

  void _markTaskAsMissed(String docId) async {
    if (_disposed) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentNumber)
          .collection('to-do-files')
          .doc(docId)
          .update({'status': 'Missed'});
      _updateWidgetStudentNumber();
    } catch (e) {
      print('Error updating task: $e');
    }
  }

  double _calculateProgress(DateTime startTime, DateTime endTime) {
    final totalDuration = endTime.difference(startTime).inSeconds;
    final remainingDuration = endTime.difference(DateTime.now()).inSeconds;
    return remainingDuration > 0
        ? 1 - (remainingDuration / totalDuration)
        : 1.0; // Task is due or overdue
  }

  void _markTaskAsCompleted(String docId) async {
    if (_disposed) return;
    try {
      DateTime completionTime = DateTime.now();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentNumber)
          .collection('to-do-files')
          .doc(docId)
          .update({
        'status': 'Completed',
        'completionTime': completionTime,
      });

      if (!_disposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task marked as completed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _updateWidgetStudentNumber();
    } catch (e) {
      print('Error updating task: $e');
    }
  }

  void _editTask(BuildContext context, String docId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateDataScreen(
          studentNumber: widget.studentNumber,
          docId: docId,
        ),
      ),
    );
  }

  void _deleteTask(BuildContext context, String docId) async {
    if (_disposed) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentNumber)
          .collection('to-do-files')
          .doc(docId)
          .delete();

      if (!_disposed) {
        Fluttertoast.showToast(
          msg: 'Task deleted successfully.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
      _updateWidgetStudentNumber();
    } catch (e) {
      if (!_disposed) {
        Fluttertoast.showToast(
          msg: 'Failed to delete task.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    }
  }
}
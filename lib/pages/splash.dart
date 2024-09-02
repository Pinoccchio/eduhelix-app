import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/pages/SignIn_Screen/sign_in_filled.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lottie/lottie.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Database_Helper/FirestoreDatabaseHelper.dart';
import 'Home_Screen/home.dart'; // For storing preferences

class Splash extends StatefulWidget {
  @override
  _SplashState createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _checkInternetConnectionAndProceed();
  }

  // Check for internet connection and proceed based on its availability
  Future<void> _checkInternetConnectionAndProceed() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.wifi)) {
      // Internet is available, proceed with user session check
      _checkUserSession();
    } else {
      // No internet connection, show a message and close the app
      _showNoInternetDialog();
    }
  }

  // Check if the user is logged in and handle navigation
  Future<void> _checkUserSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final studentNumber = prefs.getString('studentNumber');
    final firstName = prefs.getString('firstName');
    final lastName = prefs.getString('lastName');

    if (studentNumber != null) {
      // User is logged in, navigate to the home screen
      _navigateToHomeScreen(studentNumber, firstName, lastName);
    } else {
      // Check if it's the first time and handle user registration
      bool isFirstTime = prefs.getBool('isFirstTime') ?? true;
      if (isFirstTime) {
        await _uploadStaticUsers();
        await prefs.setBool('isFirstTime', false); // Set isFirstTime to false after uploading
      }
      _navigateToSignInScreen();
    }
  }

  // Upload static users to Firestore
  Future<void> _uploadStaticUsers() async {
    try {
      await FirestoreDatabaseHelper.uploadStaticUsers();
      Fluttertoast.showToast(
        msg: "Static users uploaded successfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error uploading static users: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  // Navigate to the sign-in screen
  void _navigateToSignInScreen() {
    Future.delayed(Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => SignInFilled()),
      );
    });
  }

  // Navigate to the home screen with user data
  void _navigateToHomeScreen(String studentNumber, String? firstName, String? lastName) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => Home(
          studentNumber: studentNumber,
          firstName: firstName,
          lastName: lastName,
        ),
      ),
    );
  }

  // Show no internet connection dialog
  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1AADB6), // Set the background color of the dialog
        title: Text(
          'No Internet Connection',
          style: TextStyle(color: Colors.white), // Set the text color of the title
        ),
        content: Text(
          'Please connect to the internet and try again.',
          style: TextStyle(color: Colors.white), // Set the text color of the content
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Close the app when there is no internet connection
              exit(0);
            },
            child: Text(
              'OK',
              style: TextStyle(color: Colors.white), // Set the text color of the button
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Color(0xFF000000),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Centered logo
            Center(
              child: SizedBox(
                width: 213,
                height: 38.9,
                child: SvgPicture.asset(
                  'assets/vectors/group_33398_x2.svg',
                ),
              ),
            ),
            // Loading animation at the bottom
            Positioned(
              bottom: 30.0,
              child: SizedBox(
                width: 180,
                height: 180,
                child: Lottie.asset(
                  'assets/animated_icon/loading-animation.json',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

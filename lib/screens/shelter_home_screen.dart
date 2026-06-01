import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/screens/chat_screen.dart';
import 'package:mobile_app/screens/profile_clinic_shelters.dart';

// Your actual screens
import 'package:mobile_app/screens/shelter_cases.dart';
import 'package:mobile_app/screens/shelter_animal.dart';
import 'package:mobile_app/screens/shelter_requests.dart';

class ShelterHomeScreen extends StatefulWidget {
  const ShelterHomeScreen({super.key});

  @override
  State<ShelterHomeScreen> createState() => _ShelterHomeScreenState();
}

class _ShelterHomeScreenState extends State<ShelterHomeScreen> {
  int _currentIndex = 0; // 0 is now Cases!

  final Color _bgGrey = const Color(0xffF8F9FA);
  final Color _primaryGreen = const Color(0xff5bb381);

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false, // This completely blocks the back navigation
        onPopInvoked: (didPop) {
          if (didPop) return;

          // Show a quick snackbar so they aren't confused why the button isn't working
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You are on the Home Screen. Go to Profile to log out."),
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: Scaffold(
      backgroundColor: _bgGrey,

      // 🚨 Clean 4-screen stack
      body: IndexedStack(
        index: _currentIndex,
        children:  [
          ShelterCasesScreen(),     // Index 0: Cases
          ShelterAnimalsScreen(),   // Index 1: Animals
          ShelterRequestsScreen(),  // Index 2: Requests
          MessagesScreen(isShelter: true),          // Index 3: Messages
          OrganizationProfileScreen()
        ],
      ),

      // 🚨 Clean 4-item Nav Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _primaryGreen,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.nunito(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.warning_amber_rounded), label: "Cases"),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: "Animals"),
          BottomNavigationBarItem(icon: Icon(Icons.inbox_outlined), label: "Requests"),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: "Messages"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),

        ],
      ),
    )
    );
  }
}
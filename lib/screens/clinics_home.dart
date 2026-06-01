import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/screens/profile_clinic_shelters.dart';

import 'clinics_cases.dart';


class ClinicHomeScreen extends StatefulWidget {
  const ClinicHomeScreen({super.key});

  @override
  State<ClinicHomeScreen> createState() => _ClinicHomeScreenState();
}

class _ClinicHomeScreenState extends State<ClinicHomeScreen> {
  int _currentIndex = 0;

  final Color _bgGrey = const Color(0xffF8F9FA);
  final Color _primaryBlue = const Color(0xff5D8ED5); // Using Blue for Clinics to visually separate from Green Shelters

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
        child:Scaffold(
      backgroundColor: _bgGrey,

      // 🚨 Clean stack for the Clinic Role
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          ClinicCasesScreen(), // Index 0: Cases ready for transport/treatment
          OrganizationProfileScreen()
        ],
      ),

      // 🚨 Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _primaryBlue,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.nunito(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.medical_services_outlined), label: "Cases"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    )
    );
  }
}
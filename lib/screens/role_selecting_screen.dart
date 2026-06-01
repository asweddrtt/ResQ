import 'package:flutter/foundation.dart'; // Needed for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // 0 = Volunteer (Default), 1 = Shelter, 2 = Clinic
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // WEB FIX: If running on Web, wrap everything in a phone-sized box
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.grey[200],
        body: Center(
          child: Container(
            width: 375, // Force mobile width
            height: 812, // Force mobile height
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
            ),
            child: _buildMobileLayout(), // Call the actual screen code
          ),
        ),
      );
    }

    // On Mobile: Just render normally
    return Scaffold(
      body: _buildMobileLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background Color
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey.withOpacity(0.1),
            ),

            // Main White Card
            SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 325.w,
                    padding: EdgeInsets.symmetric(vertical: 25.h, horizontal: 20.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Choose your role",
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.bold,
                            fontSize: 22.sp,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          "This helps us tailor your ResQ experience.",
                          style: GoogleFonts.nunito(
                            fontSize: 12.sp,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 25.h),

                        // --- OPTIONS ---
                        _buildRoleOption(
                          index: 0,
                          title: "Volunteer",
                          subtitle: "Adopt animals, report cases, and donate.",
                          icon: Icons.person_outline_rounded,
                        ),
                        SizedBox(height: 15.h),
                        _buildRoleOption(
                          index: 1,
                          title: "Shelter",
                          subtitle: "Post animals for adoption and manage inquiries.",
                          icon: Icons.grid_view_rounded,
                        ),
                        SizedBox(height: 15.h),
                        _buildRoleOption(
                          index: 2,
                          title: "Clinic",
                          subtitle: "Provide medical care and update treatment plans.",
                          icon: Icons.medical_services_outlined,
                        ),

                        SizedBox(height: 25.h),

                        // Footer Text
                        Center(
                          child: Text(
                            "You can request a role change later from Settings.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 10.sp,
                              color: Colors.grey.withOpacity(0.6),
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),

                        // Continue Button
                        Container(
                          width: double.infinity,
                          height: 48.h,
                          decoration: BoxDecoration(
                              color: const Color(0xffffa94d),
                              borderRadius: BorderRadius.circular(30.r)),
                          child: TextButton(
                            onPressed: () {
                              if (_selectedIndex == 0) {
                                context.push("/user_reg");
                              }
                              else if (_selectedIndex == 1) {
                                context.push("/shelter_reg");
                              }
                              else if (_selectedIndex == 2) {
                                context.push("/clinic_reg");
                              }  
                            },
                            child: Text(
                              "Continue",
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildRoleOption({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff5bb381) : Colors.transparent, // Green if selected
          borderRadius: BorderRadius.circular(15.r),
          // Add Orange border if selected (like in your screenshot)
          border: isSelected
              ? Border.all(color: const Color(0xffffa94d), width: 2)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            // Icon Circle
            Container(
              height: 40.h,
              width: 40.w,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.black : Colors.black87,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 15.w),
            // Text Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 12.sp,
                      // Make text lighter if selected so it's readable on green
                      color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            // Radio Button Circle (Right Side)
            if (isSelected)
              Icon(Icons.radio_button_checked, color: const Color(0xffffa94d), size: 24.sp)
            else
              Icon(Icons.radio_button_off, color: Colors.grey[300], size: 24.sp)
          ],
        ),
      ),
    );
  }
}
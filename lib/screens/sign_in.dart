import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  // State
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.grey.withOpacity(0.1),
              ),

              // Main Card
              SingleChildScrollView(
                child: Container(
                  width: 325.w,
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        "Welcome back!",
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold,
                          fontSize: 22.sp,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        "Sign in to continue your journey with ResQ.",
                        style: GoogleFonts.nunito(
                          fontSize: 12.sp,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 30.h),

                      // --- FORM FIELDS ---

                      // Email
                      _buildLabel("Email address"),
                      _buildTextField(
                          controller: _emailController,
                          hint: "you@example.com",
                          icon: Icons.mail_outline
                      ),
                      SizedBox(height: 20.h),

                      // Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel("Password"),
                          // Forgot Password Link
                          GestureDetector(
                            onTap: (){
                              // Handle Forgot Password
                            },
                            child: Text(
                              "Forgot password?",
                              style: GoogleFonts.nunito(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xffffa94d), // Orange
                              ),
                            ),
                          )
                        ],
                      ),
                      _buildPasswordField(),

                      SizedBox(height: 30.h),

                      // Login Button
                      Container(
                        width: double.infinity,
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: const Color(0xffffa94d), // Orange
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                        child: TextButton(
                          onPressed: () async {
                            try {
                              // 1. Tell Supabase to log them in and capture the response
                              final AuthResponse res = await supabase.auth.signInWithPassword(
                                email: _emailController.text.trim(),
                                password: _passController.text,
                              );

                              final user = res.user;

                              if (user != null) {
                                // 2. Fetch the user's profile from your database to check their role
                                final userData = await supabase
                                    .from('users')
                                    .select('role')
                                    .eq('id', user.id)
                                    .single();

                                final String role = (userData['role'] ?? 'volunteer').toString().toLowerCase();

                                // 3. Route them to the correct screen based on the role
                                if (mounted) {
                                  if (role == 'clinic') {
                                    context.pushReplacement("/clinic_home");
                                  } else if (role == 'shelter') {
                                    context.pushReplacement("/shelter_home");
                                  } else {
                                    context.pushReplacement("/home"); // Normal user home feed
                                  }
                                }
                              }

                            } catch (error) {
                              // 4. If they type the wrong password, show a red error popup
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(error.toString()),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(
                            "Login",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20.h),

                      // Footer Link (Go to Register)
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            // Navigate to Register Screen
                          },
                          child: InkWell(
                            onTap: (){
                              context.pushReplacement("/role_selection");
                            },
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.nunito(fontSize: 12.sp, color: Colors.grey),
                                children: [
                                  const TextSpan(text: "Don't have an account? "),
                                  TextSpan(
                                    text: "Create account",
                                    style: TextStyle(
                                        color: const Color(0xffffa94d),
                                        fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.bold,
          fontSize: 14.sp,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller
  }) {
    return Container(
      height: 50.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.nunito(fontSize: 14.sp),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 14.h),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: Colors.grey[400], size: 20.sp),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      height: 50.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _passController,
        obscureText: !_isPasswordVisible,
        style: GoogleFonts.nunito(fontSize: 14.sp),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 14.h),
          hintText: "••••••••",
          hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 2),
          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400], size: 20.sp),
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
              size: 20.sp,
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
        ),
      ),
    );
  }
}
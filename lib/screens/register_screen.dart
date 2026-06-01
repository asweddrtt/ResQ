import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  // State Variables
  bool _isPasswordVisible = false;
  bool _hasCapital = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;
  bool _passwordsMatch = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Listen to password changes to update UI indicators
    _passController.addListener(() {
      final text = _passController.text;
      setState(() {
        _hasCapital = text.contains(RegExp(r'[A-Z]'));
        _hasNumber = text.contains(RegExp(r'[0-9]'));
        _hasSpecial = text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
        _checkMatch();
      });
    });

    _confirmPassController.addListener(_checkMatch);
  }

  void _checkMatch() {
    setState(() {
      _passwordsMatch = _passController.text.isNotEmpty &&
          _passController.text == _confirmPassController.text;
    });
  }

  Future<void> _signUp() async {
    if (!_passwordsMatch || _emailController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // 1. Create the Auth User and capture the response
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passController.text,
        // Keeping the metadata here in case you still need their name saved in auth!
        data: {
          'full_name': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
          'role': 'volunteer',
        },
      );

      final user = res.user;

      // 2. Insert into user_verifications using the new user's ID
      if (user != null) {
        await supabase.from('user_verifications').insert({
          'user_id': user.id,
          'doc_type': 'national_id',
          'status': 'pending', // Starting as pending makes sense for a new registration
        });
      }

      if (mounted) {
        context.push("/email_ver");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.grey.withOpacity(0.1),
              ),

              // Scrollable Card
              SingleChildScrollView(
                padding: EdgeInsets.symmetric(vertical: 20.h),
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
                        "Create your ResQ account",
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold,
                          fontSize: 20.sp,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        "Join our community and start making a difference.",
                        style: GoogleFonts.nunito(
                          fontSize: 12.sp,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 25.h),

                      // --- FORM FIELDS ---

                      // First Name
                      _buildLabel("First name"),
                      _buildTextField(hint: "Jane", icon: Icons.person_outline, controller: _firstNameController),
                      SizedBox(height: 15.h),

                      // Last Name
                      _buildLabel("Last name"),
                      _buildTextField(hint: "Doe", icon: Icons.person_outline, controller: _lastNameController),
                      SizedBox(height: 15.h),

                      // Email
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel("Email address"),
                          Text("We'll send a verification link",
                              style: GoogleFonts.nunito(fontSize: 10.sp, color: Colors.blueGrey))
                        ],
                      ),
                      _buildTextField(hint: "you@example.com", icon: Icons.mail_outline, controller: _emailController),
                      SizedBox(height: 5.h),
                      Text("This email looks available.",
                          style: GoogleFonts.nunito(fontSize: 10.sp, color: Colors.blue[300])),
                      SizedBox(height: 15.h),

                      // Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel("Password"),
                          Text("Min. 8 characters",
                              style: GoogleFonts.nunito(fontSize: 10.sp, color: Colors.grey))
                        ],
                      ),
                      _buildPasswordField(),

                      SizedBox(height: 10.h),

                      // Password Strength Indicators
                      _buildRequirementDot("At least 1 capital letter", _hasCapital),
                      _buildRequirementDot("At least 1 number", _hasNumber),
                      _buildRequirementDot("At least 1 special character", _hasSpecial),

                      SizedBox(height: 15.h),

                      // Confirm Password
                      _buildLabel("Confirm password"),
                      _buildTextField(
                          hint: "Re-enter password",
                          controller: _confirmPassController,
                          isPassword: true
                      ),
                      SizedBox(height: 5.h),
                      if (_passwordsMatch)
                        Text("Passwords match.",
                            style: GoogleFonts.nunito(fontSize: 10.sp, color: Colors.blue[300])),

                      SizedBox(height: 20.h),

                      // Terms Text
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.nunito(fontSize: 10.sp, color: Colors.grey),
                          children: [
                            const TextSpan(text: "By creating an account, you agree to the "),
                            TextSpan(
                              text: "Terms & Conditions.",
                              style: TextStyle(color: const Color(0xffffa94d), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // Create Button
                      Container(
                        width: double.infinity,
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: const Color(0xffffa94d),
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                        child: TextButton(
                          onPressed: _isLoading ? null : _signUp,
                          child: _isLoading 
                            ? SizedBox(height: 20.h, width: 20.h, child: CircularProgressIndicator(color: Colors.black))
                            : Text(
                            "Create account",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),


                      SizedBox(height: 15.h),

                      // Footer Link
                      Center(
                        child: InkWell(
                          onTap: () {
                            context.push("/sign_in");
                          },
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.nunito(fontSize: 12.sp, color: const Color(0xffffa94d)),
                              children: const [
                                TextSpan(text: "Already have an account? "),
                                TextSpan(
                                  text: "Login",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
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

  // --- HELPER WIDGETS ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 5.h),
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
    IconData? icon,
    bool isPassword = false,
    TextEditingController? controller
  }) {
    return Container(
      alignment: Alignment.center,
      height: 45.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: GoogleFonts.nunito(fontSize: 14.sp),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h), // Center text vertically
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: icon != null
              ? Icon(icon, color: Colors.grey[400], size: 20.sp)
              : null,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      height: 45.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _passController,
        obscureText: !_isPasswordVisible,
        style: GoogleFonts.nunito(fontSize: 14.sp),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
          hintText: "••••••••",
          hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 2),
          suffixIcon: TextButton(
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
            child: Text(
              _isPasswordVisible ? "Hide" : "Show",
              style: GoogleFonts.nunito(
                  color: const Color(0xffffa94d),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementDot(String text, bool isMet) {
    return Padding(
      padding: EdgeInsets.only(top: 4.h),
      child: Row(
        children: [
          Container(
            width: 8.w,
            height: 8.h,
            decoration: BoxDecoration(
              color: isMet ? const Color(0xff5bb381) : Colors.grey[200], // Green if met, Grey if not
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 10.sp,
              color: isMet ? const Color(0xff5bb381) : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
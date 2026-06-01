import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ClinicReg extends StatefulWidget {
  const ClinicReg({super.key});

  @override
  State<ClinicReg> createState() => _ClinicReg();
}

class _ClinicReg extends State<ClinicReg> {
  // Replace these with your actual Supabase URL and Anon Key
  static const String _supabaseProjectUrl = 'https://dgwrsfjpxuvgqrbhhjro.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3JzZmpweHV2Z3FyYmhoanJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNDUzMTYsImV4cCI6MjA4NjkyMTMxNn0.g9IBC8ZjBOYWpa4-k6FWA6qiEV0CvZcqd5AG8JZLyPE';

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _selectedFileName;
  String? _selectedFilePath;

  // ==========================================
  // UPLOAD HELPERS (From ReportCaseScreen)
  // ==========================================
  String _resolveContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  bool _isTransientUploadError(Object error) {
    if (error is SocketException || error is TimeoutException) return true;
    if (error is http.ClientException) {
      final msg = error.message.toLowerCase();
      return msg.contains('connection closed') || msg.contains('connection reset') || msg.contains('timed out');
    }
    final message = error.toString().toLowerCase();
    return message.contains('connection closed before full header') ||
        message.contains('connection reset by peer') ||
        message.contains('timeout');
  }

  Future<void> _uploadUsingRestFallback({
    required SupabaseClient supabase,
    required String bucket,
    required String filePath,
    required File file,
    required String contentType,
  }) async {
    final session = supabase.auth.currentSession;
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('No auth session for REST upload fallback.');
    }

    final encodedSegments = filePath.split('/').map(Uri.encodeComponent).join('/');
    final uri = Uri.parse('$_supabaseProjectUrl/storage/v1/object/$bucket/$encodedSegments');
    final bytes = await file.readAsBytes();

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'apikey': _supabaseAnonKey,
        'Content-Type': contentType,
        'x-upsert': 'false',
      },
      body: bytes,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('REST upload failed (${response.statusCode}): ${response.body}');
    }
  }

  // ==========================================
  // PICKER & SUBMIT LOGIC
  // ==========================================

  final ImagePicker _picker = ImagePicker();
  Future<void> _pickDocument() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedFileName = pickedFile.name;
          _selectedFilePath = pickedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking document: $e')),
        );
      }
    }
  }


  Future<void> _submitForm() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Sign up the user
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': 'clinic'},
      );

      final user = authResponse.user;
      if (user == null) throw Exception("Authentication failed. User is null.");

      await supabase.from('users').update({'role': 'clinic'}).eq('id', user.id);

      // 2. Insert clinic AND fetch the newly generated Clinic ID
      final clinicResponse = await supabase.from('clinics').insert({
        'user_id': user.id,
        'name': name,
        'phone': _phoneController.text.trim(),
        'license_number': _licenseController.text.trim(),
        'city': _cityController.text.trim(),
        'status': 'pending',
      }).select().single();

      final String clinicId = clinicResponse['id'];

      // 3. Insert into clinic_verifications
      await supabase.from('clinic_verifications').insert({
        'clinic_id': clinicId,
        'status': 'pending',
      });

      // 4. Robust Document Upload
      if (_selectedFilePath != null) {
        final file = File(_selectedFilePath!);
        if (!await file.exists()) throw Exception("Selected file not found on device.");

        final ext = _selectedFilePath!.split('.').last.toLowerCase();
        final contentType = _resolveContentType(ext);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = '${user.id}/license_$timestamp.$ext';

        try {
          // Standard Upload Attempt
          await supabase.storage.from('verification_docs').upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
        } catch (uploadError) {
          if (_isTransientUploadError(uploadError)) {
            // Transient error: Retry once
            await Future.delayed(const Duration(milliseconds: 800));
            try {
              await supabase.storage.from('verification_docs').upload(
                storagePath,
                file,
                fileOptions: FileOptions(contentType: contentType, upsert: false),
              );
            } catch (retryError) {
              throw Exception("Storage retry failed: $retryError");
            }
          } else {
            // Hard error: Try REST API Fallback
            try {
              await _uploadUsingRestFallback(
                supabase: supabase,
                bucket: 'verification_docs',
                filePath: storagePath,
                file: file,
                contentType: contentType,
              );
            } catch (restError) {
              throw Exception("REST fallback failed: $restError");
            }
          }
        }

        // Log the media file only if upload succeeds
        await supabase.from('media_files').insert({
          'owner_type': 'user',
          'owner_id': user.id,
          'kind': 'license',
          'bucket': 'verification_docs',
          'path': storagePath,
          'mime_type': contentType,
          'uploaded_by': user.id,
        });
      }

      // Route to Email Verification
      if (mounted) context.push("/email_ver", extra: "clinic");

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // UI LOGIC
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
              SingleChildScrollView(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Container(
                  width: 325.w,
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25.r),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(color: const Color(0xff5bb381), borderRadius: BorderRadius.circular(20.r)),
                        child: Text("Clinic verification", style: GoogleFonts.nunito(color: Colors.black87, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 15.h),
                      Text("Clinic details", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 22.sp)),
                      SizedBox(height: 5.h),
                      Text("Verified clinics helps us keep animals safe and healthy.", style: GoogleFonts.nunito(fontSize: 12.sp, color: Colors.grey)),
                      SizedBox(height: 25.h),

                      _buildLabel("Email address"),
                      _buildTextField(hint: "contact@clinic.com", controller: _emailController),
                      SizedBox(height: 15.h),

                      _buildLabel("Password"),
                      _buildTextField(hint: "Secure password", controller: _passwordController, isPassword: true),
                      SizedBox(height: 15.h),

                      _buildLabel("Clinic name"),
                      _buildTextField(hint: "Hope Paws Clinic", controller: _nameController),
                      SizedBox(height: 15.h),

                      _buildLabel("Phone number"),
                      _buildTextField(hint: "+1 555 123 4567", controller: _phoneController, isNumber: true),
                      SizedBox(height: 15.h),

                      _buildLabel("License number"),
                      _buildTextField(hint: "123456789", controller: _licenseController, isNumber: true),
                      SizedBox(height: 15.h),

                      _buildLabel("City / Area"),
                      _buildTextField(hint: "Riverdale, East District", controller: _cityController),
                      SizedBox(height: 15.h),

                      _buildLabel("Upload Medical license "),
                      SizedBox(height: 5.h),
                      GestureDetector(
                        onTap: _pickDocument,
                        child: Text(
                          _selectedFileName ?? "Tap to upload document",
                          style: GoogleFonts.nunito(fontSize: 14.sp, color: Colors.blueGrey.withOpacity(0.6)),
                        ),
                      ),
                      SizedBox(height: 30.h),

                      Container(
                        width: double.infinity, padding: EdgeInsets.all(15.r),
                        decoration: BoxDecoration(color: const Color(0xff5bb381), borderRadius: BorderRadius.circular(15.r)),
                        child: Text("Your Clinic will appear as verified after approval", style: GoogleFonts.nunito(color: Colors.black87, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(height: 20.h),

                      Container(
                        width: double.infinity, height: 48.h,
                        decoration: BoxDecoration(color: const Color(0xffffa94d), borderRadius: BorderRadius.circular(30.r)),
                        child: TextButton(
                          onPressed: _isLoading ? null : _submitForm,
                          child: _isLoading
                              ? SizedBox(height: 20.h, width: 20.h, child: const CircularProgressIndicator(color: Colors.black))
                              : Text("Submit for review", style: TextStyle(color: Colors.black, fontSize: 16.sp, fontWeight: FontWeight.w600)),
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
      child: Text(text, style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.black87)),
    );
  }

  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    bool isNumber = false,
    bool isPassword = false,
  }) {
    return Container(
      margin: EdgeInsets.only(top: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        obscureText: isPassword,
        keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
        style: GoogleFonts.nunito(fontSize: 14.sp),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
      ),
    );
  }
}
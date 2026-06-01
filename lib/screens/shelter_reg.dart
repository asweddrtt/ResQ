import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ShelterRegistrationScreen extends StatefulWidget {
  const ShelterRegistrationScreen({super.key});

  @override
  State<ShelterRegistrationScreen> createState() => _ShelterRegistrationScreenState();
}

class _ShelterRegistrationScreenState extends State<ShelterRegistrationScreen> {
  // Controllers for your backend teammate to use later
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  
  bool _isLoading = false;
  String? _selectedFileName;

  String? _selectedFileExt;
  Uint8List? _selectedFileBytes;
  static const String _supabaseProjectUrl = 'https://dgwrsfjpxuvgqrbhhjro.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3JzZmpweHV2Z3FyYmhoanJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNDUzMTYsImV4cCI6MjA4NjkyMTMxNn0.g9IBC8ZjBOYWpa4-k6FWA6qiEV0CvZcqd5AG8JZLyPE';

  final ImagePicker _picker = ImagePicker(); // A

  Future<void> _pickDocument() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        // Read bytes IMMEDIATELY to bypass Android cache wipes
        final bytes = await pickedFile.readAsBytes();

        setState(() {
          _selectedFileName = pickedFile.name;
          _selectedFileExt = pickedFile.path.split('.').last.toLowerCase();
          _selectedFileBytes = bytes;
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

  String _resolveContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  bool _isTransientUploadError(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return true;
    }
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
    required Uint8List bytes, // CHANGED from File to Uint8List
    required String contentType,
  }) async {
    final session = supabase.auth.currentSession;
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('No auth session for REST upload fallback.');
    }

    final encodedSegments = filePath.split('/').map(Uri.encodeComponent).join('/');
    final uri = Uri.parse('$_supabaseProjectUrl/storage/v1/object/$bucket/$encodedSegments');

    // We no longer need to read the file here because we already have the bytes!

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'apikey': _supabaseAnonKey,
        'Content-Type': contentType,
        'x-upsert': 'false',
      },
      body: bytes, // Pass the bytes directly
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('REST upload failed (${response.statusCode}): ${response.body}');
    }
  }

  Future<void> _submitForm() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      
      // 1. Sign up the user
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': 'shelter'},
      );
      
      final user = authResponse.user;
      if (user == null) {
        throw Exception("Authentication failed. User is null.");
      }

      await supabase.from('users').update({'role': 'shelter'}).eq('id', user.id);

      // 2. Insert shelter details
      await supabase.from('shelters').insert({
        'user_id': user.id,
        'name': name,
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'license_number': _licenseController.text.trim(),
        'city': _cityController.text.trim(),
        'description': _descController.text.trim(),
        'status': 'pending',
      });

      // 3. Upload verification document if selected
      if (_selectedFileBytes != null && _selectedFileExt != null) {
        final contentType = _resolveContentType(_selectedFileExt!);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = '${user.id}/license_$timestamp.${_selectedFileExt!}';
        const bucket = 'verification_docs';

        Object? lastUploadError;
        bool uploadSuccess = false;

        // 1. Standard SDK Upload (Using uploadBinary!)
        try {
          await supabase.storage.from(bucket).uploadBinary(
            storagePath,
            _selectedFileBytes!, // Passing bytes from memory
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
          uploadSuccess = true;
        } catch (uploadError) {
          if (_isTransientUploadError(uploadError)) {
            // 2. Retry
            await Future.delayed(const Duration(milliseconds: 800));
            try {
              await supabase.storage.from(bucket).uploadBinary(
                storagePath,
                _selectedFileBytes!,
                fileOptions: FileOptions(contentType: contentType, upsert: false),
              );
              uploadSuccess = true;
            } catch (retryError) {
              lastUploadError = retryError;
            }
          } else {
            lastUploadError = uploadError;
            // 3. REST API Fallback
            try {
              await _uploadUsingRestFallback(
                supabase: supabase,
                bucket: bucket,
                filePath: storagePath,
                bytes: _selectedFileBytes!, // Passing bytes directly
                contentType: contentType,
              );
              uploadSuccess = true;
            } catch (restError) {
              lastUploadError = restError;
            }
          }
        }

        if (!uploadSuccess) {
          throw Exception("Failed to upload document. Last error: $lastUploadError");
        }

        await supabase.from('media_files').insert({
          'owner_type': 'user',
          'owner_id': user.id,
          'kind': 'license',
          'bucket': bucket,
          'path': storagePath,
          'mime_type': contentType,
          'uploaded_by': user.id,
        });
      }

      // Route to Email Verification
      if (mounted) {
        context.push("/email_ver", extra: "shelter");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during registration: $e')),
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
      backgroundColor: Colors.white, // Prevents Dark Mode black background issue
      body: SafeArea(
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background Pattern/Color
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.grey.withOpacity(0.1),
              ),

              // Main Scrollable Card
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
                      // 1. Green Badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: const Color(0xff5bb381),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          "Shelter verification",
                          style: GoogleFonts.nunito(
                            color: Colors.black87,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 15.h),

                      // 2. Header
                      Text(
                        "Tell us about your shelter",
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold,
                          fontSize: 22.sp,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        "We'll review your details to keep adoptions safe and transparent.",
                        style: GoogleFonts.nunito(
                          fontSize: 12.sp,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 25.h),

                      // --- FORM FIELDS ---

                      _buildLabel("Email address"),
                      _buildTextField(hint: "contact@shelter.com", controller: _emailController),
                      SizedBox(height: 15.h),

                      _buildLabel("Password"),
                      _buildTextField(hint: "Secure password", controller: _passwordController, isPassword: true),
                      SizedBox(height: 15.h),

                      _buildLabel("Shelter name"),
                      _buildTextField(hint: "Hope Paws Shelter", controller: _nameController),
                      SizedBox(height: 15.h),

                      _buildLabel("Phone number"),
                      _buildTextField(hint: "+1 555 123 4567", controller: _phoneController, isNumber: true),
                      SizedBox(height: 15.h),

                      _buildLabel("City / Area"),
                      _buildTextField(hint: "Riverdale, East District", controller: _cityController),
                      SizedBox(height: 15.h),

                      _buildLabel("Full Address"),
                      _buildTextField(hint: "123 Paws Street", controller: _addressController),
                      SizedBox(height: 15.h),

                      _buildLabel("License Number"),
                      _buildTextField(hint: "NGO-123456", controller: _licenseController),
                      SizedBox(height: 15.h),

                      _buildLabel("Shelter description"),
                      _buildTextField(
                        hint: "Short description of your mission and facilities.",
                        controller: _descController,
                        maxLines: 3, // Taller box for description
                      ),
                      SizedBox(height: 15.h),

                      // Document Upload
                      _buildLabel("Upload license / NGO document"),
                      SizedBox(height: 5.h),
                      GestureDetector(
                        onTap: () {
                          _pickDocument();
                        },
                        child: Text(
                          _selectedFileName ?? "Tap to upload file or photo",                          style: GoogleFonts.nunito(
                            fontSize: 14.sp,
                            color: Colors.blueGrey.withOpacity(0.6),
                          ),
                        ),
                      ),
                      SizedBox(height: 30.h),

                      // Info Banner
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(15.r),
                        decoration: BoxDecoration(
                          color: const Color(0xff5bb381), // Green
                          borderRadius: BorderRadius.circular(15.r),
                        ),
                        child: Text(
                          "Your account will be activated after our team reviews your documents.",
                          style: GoogleFonts.nunito(
                            color: Colors.black87,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // Submit Button
                      Container(
                        width: double.infinity,
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: const Color(0xffffa94d), // Orange
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                        child: TextButton(
                          onPressed: _isLoading ? null : _submitForm,
                          child: _isLoading
                            ? SizedBox(height: 20.h, width: 20.h, child: CircularProgressIndicator(color: Colors.black))
                            : Text(
                            "Submit for review",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
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
    required TextEditingController controller,
    int maxLines = 1,
    bool isNumber = false,
    bool isPassword = false,
  }) {
    // In the design, these fields look like they don't have a border,
    // or maybe a very faint one. I'll make it clean with no visible background.
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
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
          contentPadding: EdgeInsets.symmetric(vertical: 5.h),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
      ),
    );
  }
}
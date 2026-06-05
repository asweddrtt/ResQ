import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart'; // Make sure this is imported!
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {

  static const String _supabaseProjectUrl = 'https://dgwrsfjpxuvgqrbhhjro.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3JzZmpweHV2Z3FyYmhoanJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNDUzMTYsImV4cCI6MjA4NjkyMTMxNn0.g9IBC8ZjBOYWpa4-k6FWA6qiEV0CvZcqd5AG8JZLyPE';



  // State variables to track if files have been uploaded

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String? _frontIdName;
  String? _frontIdPath;
  String? _backIdName;
  String? _backIdPath;
  String? _selfieName;
  String? _selfiePath;

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
    required File file,
    required String contentType,
  })
  async {
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

  // Generic function to pick a file and update the correct state variable
  // Generic function to pick an image and update the correct state variable
  Future<void> _pickImage(String type) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery, // Or ImageSource.camera if you prefer
      );

      if (pickedFile != null) {
        setState(() {
          if (type == 'front') {
            _frontIdName = pickedFile.name;
            _frontIdPath = pickedFile.path;
          }
          if (type == 'back') {
            _backIdName = pickedFile.name;
            _backIdPath = pickedFile.path;
          }
          if (type == 'selfie') {
            _selfieName = pickedFile.name;
            _selfiePath = pickedFile.path;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadDocsAndFinish() async {
    if (_frontIdPath == null || _backIdPath == null || _selfiePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required photos')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("You must be logged in to upload documents.");
      }

      final filesToUpload = {
        'id_front': _frontIdPath!,
        'id_back': _backIdPath!,
        'selfie': _selfiePath!,
      };

      const bucket = 'verification_docs';

      for (var entry in filesToUpload.entries) {
        final kind = entry.key;
        final path = entry.value;

        final file = File(path);
        final ext = path.split('.').last.toLowerCase();
        final contentType = _resolveContentType(ext);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = '${user.id}/${kind}_$timestamp.$ext';

        Object? lastUploadError;
        bool uploadSuccess = false;

        // 1. Standard SDK Upload attempt
        try {
          await supabase.storage.from(bucket).upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
          uploadSuccess = true;
        } catch (uploadError) {
          if (_isTransientUploadError(uploadError)) {
            // 2. Retry upon transient network issue
            await Future.delayed(const Duration(milliseconds: 800));
            try {
              await supabase.storage.from(bucket).upload(
                storagePath,
                file,
                fileOptions: FileOptions(contentType: contentType, upsert: false),
              );
              uploadSuccess = true;
            } catch (retryError) {
              lastUploadError = retryError;
            }
          } else {
            lastUploadError = uploadError;
            try {
              await _uploadUsingRestFallback(
                supabase: supabase,
                bucket: bucket,
                filePath: storagePath,
                file: file,
                contentType: contentType,
              );
              uploadSuccess = true;
            } catch (restError) {
              lastUploadError = restError;
            }
          }
        }

        if (!uploadSuccess) {
          throw Exception("Failed to upload $kind. Last error: $lastUploadError");
        }

        // Record in media_files
        await supabase.from('media_files').insert({
          'owner_type': 'user',
          'owner_id': user.id,
          'kind': kind,
          'bucket': bucket,
          'path': storagePath,
          'mime_type': contentType,
          'uploaded_by': user.id,
        });
      }

      await supabase.from('user_verifications')
          .update({
        'doc_type': 'national_id',
        'status': 'pending', // Feel free to change to 'submitted' if you have that status!
      })
          .eq('user_id', user.id);

      if (mounted) {
        context.push("/home");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading documents: $e')),
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
      backgroundColor: Colors.white,
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

              // Main Card
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
                      SizedBox(height: 15.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Front ID", style: GoogleFonts.nunito(fontSize: 12.sp, color: Colors.blueGrey[300])),
                          Text("Back ID", style: GoogleFonts.nunito(fontSize: 12.sp, color: Colors.blueGrey[300])),
                          Text("Selfie", style: GoogleFonts.nunito(fontSize: 12.sp, color: Colors.blueGrey[300])),
                        ],
                      ),
                      SizedBox(height: 30.h),

                      // --- HEADER ---
                      Text(
                        "Verify your identity",
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold,
                          fontSize: 22.sp,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        "Help keep the ResQ community safe and trustworthy.",
                        style: GoogleFonts.nunito(
                          fontSize: 12.sp,
                          color: Colors.blueGrey[300],
                        ),
                      ),
                      SizedBox(height: 35.h),

                      // --- UPLOAD ROWS ---
                      _buildUploadRow(
                        title: "Front of ID",
                        subtitle: "Upload a clear photo of the front side.",
                        fileName: _frontIdName,
                        onTap: () => _pickImage('front'),
                      ),
                      SizedBox(height: 25.h),

                      _buildUploadRow(
                        title: "Back of ID",
                        subtitle: "Include any important details on the back.",
                        fileName: _backIdName,
                        onTap: () => _pickImage('back'),
                      ),
                      SizedBox(height: 25.h),

                      _buildUploadRow(
                        title: "Personal photo",
                        subtitle: "Take or upload a clear photo of yourself.",
                        fileName: _selfieName,
                        onTap: () => _pickImage('selfie'),
                      ),
                      SizedBox(height: 40.h),

                      // --- FOOTER TEXT ---
                      Center(
                        child: Text(
                          "Your data is encrypted and only used for identity verification.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 10.sp,
                            color: Colors.blueGrey[300],
                          ),
                          
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // --- BUTTONS ---
                      Container(
                        width: double.infinity,
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: const Color(0xff5bb381), // Green
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                        child: TextButton(
                          onPressed: () {
                            context.push("/email_ver");
                          },
                          child: Text(
                            "Back",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 15.h),
                      Container(
                        width: double.infinity,
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: const Color(0xffffa94d), // Orange
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                        child: TextButton(
                          onPressed: _isLoading ? null : _uploadDocsAndFinish,
                          child: _isLoading
                            ? SizedBox(height: 20.h, width: 20.h, child: CircularProgressIndicator(color: Colors.black))
                            : Text(
                            "Next",
                            style: TextStyle(
                              color: Colors.black87,
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

  // --- HELPER WIDGET ---

  Widget _buildUploadRow({
    required String title,
    required String subtitle,
    required String? fileName,
    required VoidCallback onTap,
  }) {
    bool isUploaded = fileName != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: GoogleFonts.nunito(
                  fontSize: 11.sp,
                  color: Colors.blueGrey[300],
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 10.w),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: isUploaded ? const Color(0xff5bb381).withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUploaded ? "Uploaded" : "Upload",
                  style: GoogleFonts.nunito(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: isUploaded ? const Color(0xff5bb381) : const Color(0xffffa94d),
                  ),
                ),
                if (isUploaded) ...[
                  SizedBox(width: 5.w),
                  Icon(Icons.check_circle, color: const Color(0xff5bb381), size: 14.sp),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }
}
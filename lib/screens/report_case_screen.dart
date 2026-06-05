import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportCaseScreen extends StatefulWidget {
  const ReportCaseScreen({super.key});

  @override
  State<ReportCaseScreen> createState() => _ReportCaseScreenState();
}

class _ReportCaseScreenState extends State<ReportCaseScreen> {
  static const String _supabaseProjectUrl = 'https://dgwrsfjpxuvgqrbhhjro.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3JzZmpweHV2Z3FyYmhoanJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNDUzMTYsImV4cCI6MjA4NjkyMTMxNn0.g9IBC8ZjBOYWpa4-k6FWA6qiEV0CvZcqd5AG8JZLyPE';

  // Navigation State
  int _currentIndex = 1; // 1 is for 'Report'

  // Form State
  String _selectedAnimal = 'Dog';

  final MapController _mapController = MapController();
  LatLng _selectedLocation = const LatLng(30.0074, 31.4913);
  String _selectedSeverity = 'Emergency';

  // --- IMAGE PICKER STATE & LOGIC ---
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];

  bool _isSubmitting = false;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationTextController = TextEditingController();

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

  Future<void> _pickImage(ImageSource source) async {
    // Stop them if they already have 4 photos
    if (_selectedImages.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only select up to 4 photos')),
      );
      return;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // --- 1. USE MY LOCATION LOGIC ---
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if GPS is on
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable GPS')));
      return;
    }

    // Check permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // Get the location and move the map!
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _mapController.move(LatLng(position.latitude, position.longitude), 16.0);
  }

  // --- 2. SEARCH ADDRESS LOGIC ---
  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;

    // We use Nominatim: OpenStreetMap's 100% free geocoding API!
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');

    try {
      final response = await http.get(url, headers: {'User-Agent': 'ResQ_App'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);

          // Move map to the searched location
          _mapController.move(LatLng(lat, lon), 15.0);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address not found')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error searching address')));
    }
  }
  // --- SUBMIT LOGIC ---
  Future<void> _submitReport() async {
    if (_locationTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a detailed address so rescuers can find the animal.'), backgroundColor: Colors.red),
      );
      return;
    }
    final List<String> localLogs = ["Starting submission..."];

    // Shows a non-dismissible dialog with logs to see what's happening
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Uploading Report...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: localLogs.length,
                      itemBuilder: (c, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(localLogs[i], style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    setState(() => _isSubmitting = true);

    void updateUI(String msg) {
      print("REPORT_LOG: $msg");
      localLogs.add(msg);
      if (mounted) setState(() {});
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in.");

      updateUI("User ID: ${user.id}");
      updateUI("Images selected: ${_selectedImages.length}");

      const bucketCandidates = ['case_photos'];
      updateUI("Upload buckets in priority order: ${bucketCandidates.join(', ')}");

      // 1. Create Case
      updateUI("Creating case record...");
      final caseData = await supabase.from('cases').insert({
        'animal_type': _selectedAnimal,
        'severity': _selectedSeverity.toLowerCase(),
        'description': _descriptionController.text.trim(),
        'location_lat': _selectedLocation.latitude,
        'location_lng': _selectedLocation.longitude,
        'location_text': _locationTextController.text.trim(), // 🚨 ADD THIS LINE!
        'reported_by': user.id,
      }).select().single();

      final String caseId = caseData['id'];
      updateUI("✅ Case created: $caseId");

      // 2. Upload Images
      if (_selectedImages.isEmpty) {
        updateUI("No images to upload.");
      } else {
        for (int i = 0; i < _selectedImages.length; i++) {
          final file = _selectedImages[i];
          updateUI("Processing image ${i+1}/${_selectedImages.length}");

          if (!await file.exists()) {
            updateUI("❌ File ${i+1} NOT FOUND at ${file.path}");
            continue;
          }

          final hasExtension = file.path.contains('.');
          final ext = hasExtension ? file.path.split('.').last.toLowerCase() : 'jpg';
          final contentType = _resolveContentType(ext);
          final filePath = 'cases/$caseId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

          String? uploadedBucket;
          Object? lastUploadError;

          for (final candidateBucket in bucketCandidates) {
            try {
              updateUI("Uploading image ${i + 1} to '$candidateBucket'...");
              await supabase.storage.from(candidateBucket).upload(
                    filePath,
                    file,
                    fileOptions: FileOptions(contentType: contentType, upsert: false),
                  );
              uploadedBucket = candidateBucket;
              updateUI("✅ Upload ${i + 1} OK in '$candidateBucket'.");
              break;
            } catch (uploadError) {
              if (_isTransientUploadError(uploadError)) {
                updateUI("⚠️ Temporary network issue. Retrying '$candidateBucket' once...");
                await Future.delayed(const Duration(milliseconds: 800));
                try {
                  await supabase.storage.from(candidateBucket).upload(
                        filePath,
                        file,
                        fileOptions: FileOptions(contentType: contentType, upsert: false),
                      );
                  uploadedBucket = candidateBucket;
                  updateUI("✅ Retry succeeded in '$candidateBucket'.");
                  break;
                } catch (retryError) {
                  lastUploadError = retryError;
                  updateUI("⚠️ Retry failed for '$candidateBucket': $retryError");
                }
              } else {
                lastUploadError = uploadError;
                updateUI("⚠️ Upload to '$candidateBucket' failed: $uploadError");

                // Fallback to direct Storage REST API if SDK upload path fails.
                try {
                  updateUI("Trying REST fallback for '$candidateBucket'...");
                  await _uploadUsingRestFallback(
                    supabase: supabase,
                    bucket: candidateBucket,
                    filePath: filePath,
                    file: file,
                    contentType: contentType,
                  );
                  uploadedBucket = candidateBucket;
                  updateUI("✅ REST fallback succeeded in '$candidateBucket'.");
                  break;
                } catch (restError) {
                  lastUploadError = restError;
                  updateUI("⚠️ REST fallback failed for '$candidateBucket': $restError");
                }
              }
            }
          }

          if (uploadedBucket == null) {
            throw Exception("Image ${i + 1} failed in all buckets. Last error: $lastUploadError");
          }

          updateUI("Creating DB entry for image ${i+1}...");
          await supabase.from('case_photos').insert({
            'case_id': caseId,
            'bucket': uploadedBucket,
            'path': filePath,
          });
          updateUI("✅ DB entry ${i+1} OK.");
        }
      }

      updateUI("Success!");
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        context.push("/home");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report and photos submitted successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e, stack) {
      updateUI("❌ ERROR: $e");
      print("STACK: $stack");
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Error"),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }


  // --- 3. SEARCH DIALOG UI ---
  void _showSearchDialog() {
    TextEditingController searchController = TextEditingController();
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Search Address", style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            content: TextField(
              controller: searchController,
              decoration: const InputDecoration(hintText: "e.g. Maadi, Cairo"),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffffa94d)),
                onPressed: () {
                  Navigator.pop(context);
                  _searchAddress(searchController.text);
                },
                child: const Text("Search", style: TextStyle(color: Colors.black)),
              )
            ],
          );
        }
    );
  }

  @override
  void dispose() {
    _locationTextController.dispose(); // 🚨 ADD THIS
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.withOpacity(0.5), // Off-white background

      // --- APP BAR ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xffffa94d).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pets, color: Color(0xffffa94d), size: 20),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Report a Case", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
            Text("Help rescuers respond faster", style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.black, size: 18),
            ),
            onPressed: () {
              // TODO: Handle close
            },
          ),
          const SizedBox(width: 10),
        ],
      ),



      // --- MAIN BODY ---
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          children: [
            _buildLocationCard(),
            const SizedBox(height: 15),
            _buildAnimalInfoCard(),
            const SizedBox(height: 15),
            _buildDetailsCard(),
            const SizedBox(height: 20),
            _buildBottomActions(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS (BROKEN DOWN BY SECTION)
  // ==========================================

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStep(1, "Location", isActive: true),
        Expanded(child: Container(height: 2, color: const Color(0xff5bb381))),
        _buildStep(2, "Animal", isActive: true),
        Expanded(child: Container(height: 2, color: Colors.grey[300])),
        _buildStep(3, "Details", isActive: false),
      ],
    );
  }

  Widget _buildStep(int number, String label, {required bool isActive}) {
    return Column(
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xff5bb381) : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(number.toString(), style: GoogleFonts.nunito(color: isActive ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? Colors.black : Colors.grey)),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Step 1 - Confirm location", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Drag the map to place the pin.", style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _getCurrentLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xffffa94d), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, size: 14, color: Colors.black),
                      const SizedBox(width: 4),
                      Text("Use my location", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 15),

          // --- REAL MAP AREA ---
          Container(
            height: 180, // Made it slightly taller so it's easier to use
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            clipBehavior: Clip.antiAlias, // This ensures the map doesn't spill over the rounded corners
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 15.0,
                    onPositionChanged: (MapCamera camera, bool hasGesture) {
                      if (hasGesture) {
                        setState(() {
                          // Updates the variable as the user drags the map!
                          // (Notice we use 'camera' instead of 'position' now, and it's no longer nullable!)
                          _selectedLocation = camera.center;
                        });
                      }
                    },
                  ),
                  children: [
                    // This is the free OpenStreetMap tile server
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.yourcompany.resq', // Replace with your app package
                    ),
                  ],
                ),
                // The Center Pin (Stays fixed while map moves underneath)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 35.0), // Offsets the pin so the tip points at the center
                    child: Icon(
                      Icons.location_on,
                      size: 40,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          _buildRequiredHeader("Detailed Address"),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
            child: TextField(
              controller: _locationTextController,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "e.g. Building 12, Street 5, Next to pharmacy...",
                hintStyle: GoogleFonts.nunito(color: Colors.grey, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }
  Widget _buildAnimalInfoCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRequiredHeader("Animal type"),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildChoicePill("Dog", icon: Icons.pets, isSelected: _selectedAnimal == 'Dog', onTap: () => setState(() => _selectedAnimal = 'Dog')),
              _buildChoicePill("Cat", isSelected: _selectedAnimal == 'Cat', onTap: () => setState(() => _selectedAnimal = 'Cat')),
              _buildChoicePill("Bird", isSelected: _selectedAnimal == 'Bird', onTap: () => setState(() => _selectedAnimal = 'Bird')),
              _buildChoicePill("Other", isSelected: _selectedAnimal == 'Other', onTap: () => setState(() => _selectedAnimal = 'Other')),
            ],
          ),
          const SizedBox(height: 20),
          _buildRequiredHeader("Severity level"),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSeverityPill("Emergency", const Color(0xfff46363), Icons.warning_amber_rounded),
              _buildSeverityPill("Moderate", const Color(0xffffc107), null),
              _buildSeverityPill("Low", const Color(0xff5bb381), null),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Emergency: Life-threatening or heavy bleeding • Moderate: stable but needs help • Low: safe but at risk.",
            style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey),
          )
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRequiredHeader("Describe the situation"),
          const SizedBox(height: 10),

          // --- TEXTFIELD (Left exactly as is) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
            child: TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Visible injuries, behavior, nearby hazards...",
                hintStyle: GoogleFonts.nunito(color: Colors.grey, fontSize: 14),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Photos (optional if unsafe)", style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey)),
              Text("${_selectedImages.length}/4 photos", style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)), // Dynamic counter!
            ],
          ),
          const SizedBox(height: 10),

          // --- DYNAMIC PHOTO STRIP ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Camera Button
                _buildActionPhotoBox(Icons.camera_alt_outlined, () => _pickImage(ImageSource.camera)),
                // Gallery Button
                _buildActionPhotoBox(Icons.image_outlined, () => _pickImage(ImageSource.gallery)),

                // Display the selected images!
                ..._selectedImages.asMap().entries.map((entry) {
                  int index = entry.key;
                  File imageFile = entry.value;
                  return _buildImageThumbnail(imageFile, index);
                }), // .toList() is not needed when using the spread operator (...)
              ],
            ),
          ),

          const SizedBox(height: 5),
          Text("If it is not safe to take photos, you can skip this step.", style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 15),

          // Warning Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xffffa94d), borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.black),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("Stay safe. Keep distance and avoid putting yourself or the animal at risk.",
                      style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- NEW PHOTO HELPER WIDGETS ---

  // For the Camera and Gallery buttons
  Widget _buildActionPhotoBox(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        height: 60, width: 60,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Icon(icon, color: Colors.grey),
      ),
    );
  }

  Widget _buildImageThumbnail(File image, int index) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 10),
          height: 60, width: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            image: DecorationImage(
              image: FileImage(image),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // The tiny delete button in the top right corner
        Positioned(
          top: 0,
          right: 10,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildBottomActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(25)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.save_outlined, size: 18, color: Colors.black54),
                    const SizedBox(width: 8),
                    Text("Save draft", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.black54)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GestureDetector(
                onTap: _isSubmitting ? null : _submitReport, // <--- Attach function here
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                      color: _isSubmitting ? Colors.grey : const Color(0xff5bb381),
                      borderRadius: BorderRadius.circular(25)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSubmitting)
                        const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      else ...[
                        const Icon(Icons.send, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text("Submit report", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.white)),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text("Your report will be sent to nearby rescuers and clinics in real time.",
            style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
      ],
    );
  }

  // --- SMALL UI COMPONENTS ---

  Widget _buildRequiredHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey)),
        Text("Required", style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xfff46363))),
      ],
    );
  }

  Widget _buildActionPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildChoicePill(String label, {IconData? icon, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[200] : Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.grey[400]! : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.black : Colors.grey),
              const SizedBox(width: 4),
            ],
            Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.black : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityPill(String label, Color color, IconData? icon) {
    bool isSelected = _selectedSeverity == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedSeverity = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : color),
              const SizedBox(width: 4),
            ],
            Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : color)),
          ],
        ),
      ),
    );
  }

}
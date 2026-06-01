import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AddAdoptionScreen extends StatefulWidget {
  const AddAdoptionScreen({super.key});

  @override
  State<AddAdoptionScreen> createState() => _AddAdoptionScreenState();
}

class _AddAdoptionScreenState extends State<AddAdoptionScreen> {
  static const String _supabaseProjectUrl = 'https://dgwrsfjpxuvgqrbhhjro.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3JzZmpweHV2Z3FyYmhoanJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNDUzMTYsImV4cCI6MjA4NjkyMTMxNn0.g9IBC8ZjBOYWpa4-k6FWA6qiEV0CvZcqd5AG8JZLyPE';

  // ==========================================
  // UI COLORS
  // ==========================================
  final Color _primaryGreen = const Color(0xff5bb381);
  final Color _bgGrey = const Color(0xffF8F9FA);
  final Color _textDark = Colors.black87;
  final Color _textGrey = Colors.grey.shade600;
  final Color _borderGrey = Colors.grey.shade300;
  final Color _redAsterisk = const Color(0xfff46363);
  final Color _orangeActive = const Color(0xffffa94d);

  // ==========================================
  // STATE VARIABLES
  // ==========================================
  bool _isSubmitting = false;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _breedCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _colorCtrl = TextEditingController();
  final TextEditingController _healthConditionCtrl = TextEditingController();
  final TextEditingController _specialNeedsCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _areaCtrl = TextEditingController();
  final TextEditingController _feeCtrl = TextEditingController();
  final TextEditingController _preferredContactCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  // Toggles mapped to DB Enums
  int _selectedSpecies = 0; // 0: dog, 1: cat, 2: other
  int _selectedGender = 0; // 0: male, 1: female
  int _selectedSize = 1; // 0: small, 1: medium, 2: large
  int _selectedVaccinated = 0; // 0: true, 1: false
  int _selectedNeutered = 0; // 0: true, 1: false
  int _selectedLiving = 0; // 0: indoor, 1: outdoor, 2: both
  int _energyLevel = 1; // 0: low, 1: medium, 2: high

  // Checkboxes
  bool _friendlyPeople = true;
  bool _friendlyKids = false;
  bool _friendlyAnimals = false;
  bool _houseTrained = false;
  bool _homeVisitRequired = true;
  bool _contractRequired = true;

  // Photos
  final ImagePicker _picker = ImagePicker();
  List<Uint8List?> _selectedImageBytes = [null, null, null];
  List<String?> _selectedImageExts = [null, null, null];

  String _resolveContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'heic':
      case 'heif': return 'image/heic';
      default: return 'application/octet-stream';
    }
  }
  bool _isTransientUploadError(Object error) {
    if (error is SocketException || error is TimeoutException) return true;
    if (error is http.ClientException) {
      final msg = error.message.toLowerCase();
      return msg.contains('connection closed') || msg.contains('connection reset') || msg.contains('timed out');
    }
    final msg = error.toString().toLowerCase();
    return msg.contains('connection closed before full header') || msg.contains('connection reset by peer') || msg.contains('timeout');
  }

  Future<void> _uploadUsingRestFallback({
    required SupabaseClient supabase,
    required String bucket,
    required String filePath,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final session = supabase.auth.currentSession;
    final token = session?.accessToken;
    if (token == null || token.isEmpty) throw Exception('No auth session for REST upload fallback.');

    final encodedSegments = filePath.split('/').map(Uri.encodeComponent).join('/');
    final uri = Uri.parse('$_supabaseProjectUrl/storage/v1/object/$bucket/$encodedSegments');

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

  Future<void> _pickPhoto(int index) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes[index] = bytes;
          _selectedImageExts[index] = pickedFile.path.split('.').last.toLowerCase();
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  // ==========================================
  // SUBMIT TO SUPABASE LOGIC
  // ==========================================
  Future<void> _submitAdoption() async {
    // Basic validation
    if (_breedCtrl.text.isEmpty || _ageCtrl.text.isEmpty || _cityCtrl.text.isEmpty || _areaCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields (*)'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSubmitting = true);
    final supabase = Supabase.instance.client;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      // 1. Get Shelter ID for this user
      final shelterData = await supabase.from('shelters').select('id').eq('user_id', user.id).maybeSingle();
      if (shelterData == null) throw Exception("Shelter profile not found for this user.");
      final String shelterId = shelterData['id'];

      // Map UI values to DB Constraints
      final speciesMap = ['dog', 'cat', 'other'];
      final genderMap = ['male', 'female'];
      final sizeMap = ['small', 'medium', 'large'];
      final livingMap = ['indoor', 'outdoor', 'both'];
      final energyMap = ['low', 'medium', 'high'];

      // 2. Insert Animal
      final animalResponse = await supabase.from('animals').insert({
        'shelter_id': shelterId,
        'name': _nameCtrl.text.trim().isEmpty ? 'Buddy' : _nameCtrl.text.trim(),
        'species': speciesMap[_selectedSpecies],
        'breed': _breedCtrl.text.trim(),
        'age': _ageCtrl.text.trim(),
        'gender': genderMap[_selectedGender],
        'size': sizeMap[_selectedSize],
        'color': _colorCtrl.text.trim(),
        'vaccinated': _selectedVaccinated == 0,
        'is_neutered': _selectedNeutered == 0,
        'health_condition': _healthConditionCtrl.text.trim(),
        'special_needs': _specialNeedsCtrl.text.trim(),
        'friendly_people': _friendlyPeople,
        'friendly_kids': _friendlyKids,
        'friendly_animals': _friendlyAnimals,
        'house_trained': _houseTrained,
        'energy_level': energyMap[_energyLevel],
        'living_preference': livingMap[_selectedLiving],
        'adoption_fee': double.tryParse(_feeCtrl.text.trim()) ?? 0,
        'home_visit_required': _homeVisitRequired,
        'contract_required': _contractRequired,
        'city': _cityCtrl.text.trim(),
        'area': _areaCtrl.text.trim(),
        'preferred_contact': _preferredContactCtrl.text.trim(),
        'contact_phone': _phoneCtrl.text.trim(),
        'status': 'available'
      }).select().single();

      final String animalId = animalResponse['id'];

      // 3. Upload Photos (if any are selected)
      for (int i = 0; i < _selectedImageBytes.length; i++) {
        final bytes = _selectedImageBytes[i];
        final ext = _selectedImageExts[i];

        if (bytes != null && ext != null) {
          final contentType = _resolveContentType(ext);
          final filePath = 'animals/$animalId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
          const bucket = 'animal_photos';

          Object? lastUploadError;
          bool uploadSuccess = false;

          // 1. Standard SDK Upload
          try {
            await supabase.storage.from(bucket).uploadBinary(
              filePath, bytes, fileOptions: FileOptions(contentType: contentType, upsert: false),
            );
            uploadSuccess = true;
          } catch (uploadError) {
            if (_isTransientUploadError(uploadError)) {
              // 2. Retry
              await Future.delayed(const Duration(milliseconds: 800));
              try {
                await supabase.storage.from(bucket).uploadBinary(
                  filePath, bytes, fileOptions: FileOptions(contentType: contentType, upsert: false),
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
                  filePath: filePath,
                  bytes: bytes,
                  contentType: contentType,
                );
                uploadSuccess = true;
              } catch (restError) {
                lastUploadError = restError;
              }
            }
          }

          if (!uploadSuccess) {
            throw Exception("Failed to upload photo $i. Last error: $lastUploadError");
          }

          // Save link in table
          await supabase.from('animal_photos').insert({
            'animal_id': animalId,
            'bucket': bucket,
            'path': filePath,
            'is_cover': i == 0, // Make the first uploaded photo the cover!
          });
        }
      }

      // Success!
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Animal listed for adoption!'), backgroundColor: Colors.green));
        context.pop(); // Go back to Shelter Animals Screen
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // HEADER
              // ==========================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Add an animal for adoption", style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: _textDark)),
                        const SizedBox(height: 4),
                        Text("Share clear details to help them find the right home.", style: GoogleFonts.nunito(fontSize: 13, color: _textGrey, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.black54), onPressed: () => context.pop())
                ],
              ),
              const SizedBox(height: 20),

              // ==========================================
              // 1. ANIMAL DETAILS CARD
              // ==========================================
              _buildCard(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Animal details", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: _textDark)),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.nunito(fontSize: 11, color: _textGrey, fontWeight: FontWeight.w600),
                          children: [const TextSpan(text: "Fields marked "), TextSpan(text: "*", style: TextStyle(color: _redAsterisk, fontWeight: FontWeight.bold)), const TextSpan(text: " are required")],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  _buildLabel("Name", isOptional: true),
                  _buildTextField(controller: _nameCtrl, hint: "Buddy", icon: Icons.local_offer_outlined),
                  const SizedBox(height: 15),

                  _buildLabel("Species", isRequired: true),
                  _buildToggleRow(["Dog", "Cat", "Other"], activeIndex: _selectedSpecies, onSelect: (val) => setState(() => _selectedSpecies = val)),
                  const SizedBox(height: 15),

                  _buildLabel("Breed", isRequired: true),
                  _buildTextField(controller: _breedCtrl, hint: "Mixed breed", icon: Icons.pets_outlined),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel("Age", isRequired: true), _buildTextField(controller: _ageCtrl, hint: "2 years", icon: Icons.calendar_today_outlined)])),
                      const SizedBox(width: 15),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel("Gender", isRequired: true), _buildToggleRow(["Male", "Female"], activeIndex: _selectedGender, onSelect: (val) => setState(() => _selectedGender = val))])),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // 🚨 CHANGED TO TOGGLE TO MATCH DB CONSTRAINT
                  _buildLabel("Size", isRequired: true),
                  _buildToggleRow(["Small", "Medium", "Large"], activeIndex: _selectedSize, onSelect: (val) => setState(() => _selectedSize = val)),
                  const SizedBox(height: 15),

                  _buildLabel("Color", isOptional: true),
                  _buildTextField(controller: _colorCtrl, hint: "Brown & white", icon: Icons.color_lens_outlined),
                ],
              ),
              const SizedBox(height: 15),

              // ==========================================
              // 2. HEALTH STATUS CARD
              // ==========================================
              _buildCard(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Health status", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: _textDark)),
                      Text("Help adopters understand care needs.", style: GoogleFonts.nunito(fontSize: 11, color: _textGrey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 15),

                  _buildLabel("Vaccinated?", isRequired: true),
                  _buildToggleRow(["Yes", "No"], activeIndex: _selectedVaccinated, onSelect: (val) => setState(() => _selectedVaccinated = val)),
                  const SizedBox(height: 15),

                  _buildLabel("Neutered / Spayed?", isRequired: true),
                  _buildToggleRow(["Yes", "No"], activeIndex: _selectedNeutered, onSelect: (val) => setState(() => _selectedNeutered = val)),
                  const SizedBox(height: 15),

                  _buildLabel("Current health condition"),
                  _buildTextArea(controller: _healthConditionCtrl, hint: "Healthy, regular check-ups..."),
                  const SizedBox(height: 15),

                  _buildLabel("Special needs", isOptional: true),
                  _buildTextArea(controller: _specialNeedsCtrl, hint: "E.g. sensitive stomach, anxiety..."),
                ],
              ),
              const SizedBox(height: 15),

              // ==========================================
              // 3. BEHAVIOR & HANDLING CARD
              // ==========================================
              _buildCard(
                children: [
                  Text("Behavior & handling", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: _textDark)),
                  const SizedBox(height: 15),

                  _buildCheckItem("Friendly with people", isChecked: _friendlyPeople, onTap: () => setState(() => _friendlyPeople = !_friendlyPeople)),
                  _buildCheckItem("Friendly with kids", isChecked: _friendlyKids, onTap: () => setState(() => _friendlyKids = !_friendlyKids)),
                  _buildCheckItem("Friendly with other animals", isChecked: _friendlyAnimals, onTap: () => setState(() => _friendlyAnimals = !_friendlyAnimals)),
                  _buildCheckItem("House trained", isChecked: _houseTrained, onTap: () => setState(() => _houseTrained = !_houseTrained)),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Energy level", style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: _textDark)),
                      Text(_energyLevel == 0 ? "Low" : _energyLevel == 1 ? "Medium" : "High", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xff5D8ED5))),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(children: [_buildEnergySegment(index: 0), _buildEnergySegment(index: 1), _buildEnergySegment(index: 2)]),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Low", style: GoogleFonts.nunito(fontSize: 11, color: _textGrey)),
                      Text("Medium", style: GoogleFonts.nunito(fontSize: 11, color: _textGrey)),
                      Text("High", style: GoogleFonts.nunito(fontSize: 11, color: _textGrey)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 15),

              // ==========================================
              // 4. PHOTOS CARD
              // ==========================================
              // ==========================================
              // 4. PHOTOS CARD
              // ==========================================
              _buildCard(
                children: [
                  // 🚨 CHANGED: Removed the red asterisk and added the 'Optional' tag
                  _buildLabel("Photos", isOptional: true),

                  const SizedBox(height: 4),
                  Text("Upload up to 3 clear photos showing face and body. You can skip this step.", style: GoogleFonts.nunito(fontSize: 12, color: _textGrey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPhotoBox("Face", 0),
                      _buildPhotoBox("Side", 1),
                      _buildPhotoBox("Body", 2),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // ==========================================
              // 5. LOCATION & CONDITIONS CARD
              // ==========================================
              _buildCard(
                children: [
                  Text("Location", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: _textDark)),
                  const SizedBox(height: 15),

                  _buildLabel("City", isRequired: true),
                  _buildTextField(controller: _cityCtrl, hint: "Cairo"),
                  const SizedBox(height: 15),

                  _buildLabel("Area", isRequired: true),
                  _buildTextField(controller: _areaCtrl, hint: "Maadi"),
                  const SizedBox(height: 25),

                  Text("Adoption conditions", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: _textDark)),
                  const SizedBox(height: 15),

                  _buildLabel("Living setup", isRequired: true),
                  _buildToggleRow(["Indoor", "Outdoor", "Both"], activeIndex: _selectedLiving, onSelect: (val) => setState(() => _selectedLiving = val)),
                  const SizedBox(height: 15),

                  _buildLabel("Adoption fee", isOptional: true),
                  _buildTextField(controller: _feeCtrl, hint: "e.g. 500", suffixText: "EGP"),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Home visit required?", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark)),
                      Switch(value: _homeVisitRequired, onChanged: (v) => setState(() => _homeVisitRequired = v), activeColor: _primaryGreen),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Adoption contract required?", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark)),
                      Switch(value: _contractRequired, onChanged: (v) => setState(() => _contractRequired = v), activeColor: _primaryGreen),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // ==========================================
              // BOTTOM SUBMIT ACTION
              // ==========================================
              InkWell(
                onTap: _isSubmitting ? null : _submitAdoption, // 🚨 WIRED UP
                child: Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(color: _isSubmitting ? Colors.grey : _primaryGreen, borderRadius: BorderRadius.circular(30)),
                  child: Center(
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text("Submit for adoption listing", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // INLINE HELPER METHODS
  // ==========================================
  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false, bool isOptional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(text: TextSpan(style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: _textDark), children: [TextSpan(text: text), if (isRequired) TextSpan(text: " *", style: TextStyle(color: _redAsterisk))])),
          if (isOptional) Text("Optional", style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, IconData? icon, IconData? suffixIcon, String? suffixText}) {
    return Container(
      height: 45, padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _borderGrey)),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: Colors.grey.shade400), const SizedBox(width: 10)],
          Expanded(child: TextField(controller: controller, style: GoogleFonts.nunito(fontSize: 14, color: _textDark, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade400, fontWeight: FontWeight.w600), border: InputBorder.none, isDense: true))),
          if (suffixIcon != null) Icon(suffixIcon, size: 20, color: Colors.grey.shade500),
          if (suffixText != null) Text(suffixText, style: GoogleFonts.nunito(fontSize: 14, color: _textDark, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextArea({required TextEditingController controller, required String hint}) {
    return Container(
      width: double.infinity, constraints: const BoxConstraints(minHeight: 80), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _borderGrey)),
      child: TextField(controller: controller, maxLines: 3, style: GoogleFonts.nunito(fontSize: 14, color: _textDark, fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade400, fontWeight: FontWeight.w600), border: InputBorder.none)),
    );
  }

  Widget _buildToggleRow(List<String> options, {required int activeIndex, required Function(int) onSelect}) {
    return Container(
      height: 45, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Row(
        children: List.generate(options.length, (index) {
          bool isActive = index == activeIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(index),
              child: Container(
                margin: EdgeInsets.only(right: index == options.length - 1 ? 0 : 8),
                decoration: BoxDecoration(color: isActive ? _primaryGreen : Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: isActive ? _primaryGreen : _borderGrey)),
                child: Center(child: Text(options[index], style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.bold, color: isActive ? Colors.white : _textDark))),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCheckItem(String text, {required bool isChecked, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap, behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(children: [Icon(isChecked ? Icons.check_circle : Icons.circle_outlined, color: isChecked ? _primaryGreen : Colors.grey.shade400, size: 20), const SizedBox(width: 10), Text(text, style: GoogleFonts.nunito(fontSize: 14, color: _textDark, fontWeight: FontWeight.w600))]),
      ),
    );
  }

  Widget _buildEnergySegment({required int index}) {
    bool isActive = index <= _energyLevel;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _energyLevel = index),
        child: Container(height: 12, alignment: Alignment.center, child: Container(height: 4, color: isActive ? _orangeActive : _borderGrey)),
      ),
    );
  }

  // 🚨 FIXED: Now shows the selected image!
  Widget _buildPhotoBox(String label, int index) {
    final bytes = _selectedImageBytes[index];
    return Expanded(
      child: GestureDetector(
        onTap: () => _pickPhoto(index),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _borderGrey, style: BorderStyle.solid),
            image: bytes != null ? DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover) : null,
          ),
          child: bytes == null
              ? Center(child: Text(label, style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w700)))
              : Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(Icons.check_circle, color: _primaryGreen, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}
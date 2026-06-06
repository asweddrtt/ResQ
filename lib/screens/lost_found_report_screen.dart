import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class LostFoundReportScreen extends StatefulWidget {
  const LostFoundReportScreen({super.key});

  @override
  State<LostFoundReportScreen> createState() => _LostFoundReportScreenState();
}

class _LostFoundReportScreenState extends State<LostFoundReportScreen> {
  static const String _supabaseUrl = 'https://dgwrsfjpxuvgqrbhhjro.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3JzZmpweHV2Z3FyYmhoanJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNDUzMTYsImV4cCI6MjA4NjkyMTMxNn0.g9IBC8ZjBOYWpa4-k6FWA6qiEV0CvZcqd5AG8JZLyPE';

  final MapController _mapController = MapController();
  LatLng _pinLocation = const LatLng(30.0074, 31.4913);

  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _locationTextCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<File> _photos = [];

  int _reportType = 0;    // 0 = lost, 1 = found
  int _animalType = 0;    // 0 = dog, 1 = cat, 2 = bird, 3 = other
  bool _isSubmitting = false;

  final Color _primaryGreen = const Color(0xff5bb381);
  final Color _orange = const Color(0xffffa94d);
  final Color _red = const Color(0xfff46363);

  @override
  void dispose() {
    _descCtrl.dispose();
    _locationTextCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    try {
      bool svcEnabled = await Geolocator.isLocationServiceEnabled();
      if (!svcEnabled) {
        _snack('Please enable GPS', Colors.orange);
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      if (perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final loc = LatLng(pos.latitude, pos.longitude);
      _mapController.move(loc, 16);
      setState(() => _pinLocation = loc);
    } catch (e) {
      _snack('Could not get location', Colors.red);
    }
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 3) {
      _snack('Max 3 photos', Colors.orange);
      return;
    }
    final XFile? f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (f != null) setState(() => _photos.add(File(f.path)));
  }

  String _resolveContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      default: return 'application/octet-stream';
    }
  }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty || _locationTextCtrl.text.trim().isEmpty) {
      _snack('Please fill description and location', Colors.orange);
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final typeMap = ['dog', 'cat', 'bird', 'other'];

      // 1. Insert report
      final reportRes = await supabase.from('lost_found_reports').insert({
        'type': _reportType == 0 ? 'lost' : 'found',
        'animal_type': typeMap[_animalType],
        'description': _descCtrl.text.trim(),
        'location_text': _locationTextCtrl.text.trim(),
        'location_lat': _pinLocation.latitude,
        'location_lng': _pinLocation.longitude,
        'created_by': user.id,
        'status': 'open',
      }).select().single();

      final String reportId = reportRes['id'];

      // 2. Upload photos
      for (int i = 0; i < _photos.length; i++) {
        final file = _photos[i];
        if (!await file.exists()) continue;
        final ext = file.path.split('.').last.toLowerCase();
        final ct = _resolveContentType(ext);
        final path = 'lost_found/$reportId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        const bucket = 'lost_found_photos';

        try {
          await supabase.storage.from(bucket).upload(
            path, file, fileOptions: FileOptions(contentType: ct, upsert: false),
          );
        } catch (_) {
          // REST fallback
          final session = supabase.auth.currentSession;
          if (session != null) {
            final bytes = await file.readAsBytes();
            await http.post(
              Uri.parse('$_supabaseUrl/storage/v1/object/$bucket/${Uri.encodeComponent(path)}'),
              headers: {'Authorization': 'Bearer ${session.accessToken}', 'apikey': _anonKey, 'Content-Type': ct},
              body: bytes,
            );
          }
        }

        await supabase.from('lost_found_photos').insert({
          'report_id': reportId,
          'bucket': bucket,
          'path': path,
        });
      }

      if (mounted) {
        _snack('Report submitted! 🐾', _primaryGreen);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.nunito()), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report Lost / Found', style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87)),
            Text('Help reunite pets with their families', style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [

            // ── Report type ──
            _buildCard(children: [
              Text('Report type', style: _labelStyle()),
              const SizedBox(height: 10),
              Row(children: [
                _typeToggle('Lost', 0, Colors.red.shade400),
                const SizedBox(width: 10),
                _typeToggle('Found', 1, _primaryGreen),
              ]),
            ]),
            const SizedBox(height: 12),

            // ── Animal type ──
            _buildCard(children: [
              Text('Animal type', style: _labelStyle()),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                _animalChip('Dog', 0, Icons.pets),
                _animalChip('Cat', 1, Icons.pets_outlined),
                _animalChip('Bird', 2, Icons.flutter_dash),
                _animalChip('Other', 3, Icons.cruelty_free_outlined),
              ]),
            ]),
            const SizedBox(height: 12),

            // ── Description ──
            _buildCard(children: [
              _requiredLabel('Description'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Color, size, collar, distinguishing marks…',
                    hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Location ──
            _buildCard(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _requiredLabel('Location'),
                  GestureDetector(
                    onTap: _useMyLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [
                        const Icon(Icons.my_location, size: 13, color: Colors.black87),
                        const SizedBox(width: 4),
                        Text('Use my location', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Map
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 160,
                  child: Stack(children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _pinLocation,
                        initialZoom: 14,
                        onPositionChanged: (cam, gesture) {
                          if (gesture) setState(() => _pinLocation = cam.center);
                        },
                      ),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.mobile_app'),
                      ],
                    ),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 30),
                        child: Icon(Icons.location_on, size: 36, color: Colors.red),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              // Location text
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _locationTextCtrl,
                  style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g. Near Maadi metro, behind the bakery…',
                    hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Photos ──
            _buildCard(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Photos', style: _labelStyle()),
                  Text('${_photos.length}/3 · Optional', style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              Row(children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                    ),
                    child: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey.shade400, size: 28),
                  ),
                ),
                const SizedBox(width: 10),
                ..._photos.asMap().entries.map((e) => _photoThumb(e.value, e.key)),
              ]),
            ]),
            const SizedBox(height: 20),

            // ── Submit ──
            InkWell(
              onTap: _isSubmitting ? null : _submit,
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  color: _isSubmitting ? Colors.grey.shade300 : _primaryGreen,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: _isSubmitting ? [] : [BoxShadow(color: _primaryGreen.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('Submit Report', style: GoogleFonts.nunito(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _typeToggle(String label, int idx, Color color) {
    final isSelected = _reportType == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _reportType = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.grey.shade200),
          ),
          child: Center(
            child: Text(label, style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade600, fontSize: 14)),
          ),
        ),
      ),
    );
  }

  Widget _animalChip(String label, int idx, IconData icon) {
    final isSelected = _animalType == idx;
    return GestureDetector(
      onTap: () => setState(() => _animalType = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isSelected ? _primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _primaryGreen : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade700)),
        ]),
      ),
    );
  }

  Widget _photoThumb(File file, int idx) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          width: 72, height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: -4, right: 4,
          child: GestureDetector(
            onTap: () => setState(() => _photos.removeAt(idx)),
            child: Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  TextStyle _labelStyle() => GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87);

  Widget _requiredLabel(String text) {
    return Row(children: [
      Text(text, style: _labelStyle()),
      Text(' *', style: GoogleFonts.nunito(color: const Color(0xfff46363), fontWeight: FontWeight.bold)),
    ]);
  }
}

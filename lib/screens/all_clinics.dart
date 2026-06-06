import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllClinicsScreen extends StatefulWidget {
  const AllClinicsScreen({super.key});

  @override
  State<AllClinicsScreen> createState() => _AllClinicsScreenState();
}

class _AllClinicsScreenState extends State<AllClinicsScreen> {
  final Color _bgGrey = const Color(0xffF8F9FA);
  final Color _clinicBlue = Colors.blue.shade400;

  late Future<List<Map<String, dynamic>>> _clinicsFuture;

  @override
  void initState() {
    super.initState();
    _clinicsFuture = _fetchClinics();
  }

  Future<List<Map<String, dynamic>>> _fetchClinics() async {
    // Fetch only approved clinics
    final response = await Supabase.instance.client
        .from('clinics')
        .select()
        .eq('status', 'approved')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        backgroundColor: _bgGrey,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          "Partner Clinics",
          style: GoogleFonts.nunito(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _clinicsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error loading clinics.", style: GoogleFonts.nunito()));
          }

          final clinics = snapshot.data ?? [];

          if (clinics.isEmpty) {
            return Center(
              child: Text(
                "No approved clinics available yet.",
                style: GoogleFonts.nunito(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: clinics.map((clinic) => _buildClinicCard(clinic)).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClinicCard(Map<String, dynamic> clinic) {
    final name = clinic['name'] ?? 'Unknown Clinic';
    final city = clinic['city'] ?? 'Location not provided';
    final phone = clinic['phone'] ?? 'No phone available';

    // Handling potential nulls from your DB
    final description = clinic['description'];
    final address = clinic['address'];
    final workingHours = clinic['working_hours'];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _clinicBlue.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.medical_services_outlined, color: _clinicBlue, size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(city, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Details section
          _buildInfoRow(Icons.phone_outlined, phone),
          if (address != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(Icons.location_on_outlined, address),
          ],
          if (workingHours != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time_outlined, workingHours),
          ],

          if (description != null && description.toString().trim().isNotEmpty) ...[
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text(
                description,
                style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
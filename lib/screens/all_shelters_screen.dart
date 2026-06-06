import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllSheltersScreen extends StatefulWidget {
  const AllSheltersScreen({super.key});

  @override
  State<AllSheltersScreen> createState() => _AllSheltersScreenState();
}

class _AllSheltersScreenState extends State<AllSheltersScreen> {
  final Color _bgGrey = const Color(0xffF8F9FA);
  final Color _primaryGreen = const Color(0xff5bb381);

  late Future<List<Map<String, dynamic>>> _sheltersFuture;

  @override
  void initState() {
    super.initState();
    _sheltersFuture = _fetchShelters();
  }

  Future<List<Map<String, dynamic>>> _fetchShelters() async {
    // Fetching only approved shelters based on your typical flow
    final response = await Supabase.instance.client
        .from('shelters')
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
          "Local Shelters",
          style: GoogleFonts.nunito(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _sheltersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error loading shelters.", style: GoogleFonts.nunito()));
          }

          final shelters = snapshot.data ?? [];

          if (shelters.isEmpty) {
            return Center(
              child: Text(
                "No approved shelters available yet.",
                style: GoogleFonts.nunito(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: shelters.map((shelter) => _buildShelterCard(shelter)).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShelterCard(Map<String, dynamic> shelter) {
    final name = shelter['name'] ?? 'Unknown Shelter';
    final city = shelter['city'] ?? 'Location not provided';
    final phone = shelter['phone'] ?? 'No phone available';
    final description = shelter['description'] ?? 'No description provided.';
    // Handling nulls gracefully since your DB insert had nulls for these:
    final address = shelter['address'];
    final workingHours = shelter['working_hours'];

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
                decoration: BoxDecoration(color: _primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.other_houses_outlined, color: _primaryGreen, size: 24),
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
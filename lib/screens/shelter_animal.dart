import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShelterAnimalsScreen extends StatefulWidget {
  const ShelterAnimalsScreen({super.key});

  @override
  State<ShelterAnimalsScreen> createState() => _ShelterAnimalsScreenState();
}

class _ShelterAnimalsScreenState extends State<ShelterAnimalsScreen> {
  final Color _bgGrey = const Color(0xffF8F9FA);
  final Color _textDark = Colors.black87;
  final Color _textLight = Colors.grey.shade500;
  final Color _primaryGreen = const Color(0xff5bb381);

  int _selectedTabIndex = 0; // 0: Available, 1: Adopted, 2: In Treatment, 3: Foster

  String? _myShelterId;
  bool _isLoadingShelter = true;

  @override
  void initState() {
    super.initState();
    _fetchMyShelterId();
  }

  // 🚨 1. Fetch the Shelter ID linked to this User
  Future<void> _fetchMyShelterId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('shelters')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _myShelterId = data['id'];
          _isLoadingShelter = false;
        });
      } else {
        setState(() => _isLoadingShelter = false);
      }
    } catch (e) {
      debugPrint("Error fetching shelter ID: $e");
      setState(() => _isLoadingShelter = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,

      // 🚨 Floating '+' Button to Add Animal
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.pushNamed('/add_adoption');

        },
        backgroundColor: _primaryGreen,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 1. HEADER & SEARCH
            // ==========================================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("My Animals", style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: _textDark)),
                        const SizedBox(height: 2),
                        Text("Manage animals in your shelter", style: GoogleFonts.nunito(fontSize: 12, color: _textLight, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), shape: BoxShape.circle), child: const Icon(Icons.search, color: Colors.black87, size: 20)),
                      const SizedBox(width: 10),
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), shape: BoxShape.circle), child: const Icon(Icons.tune, color: Colors.black87, size: 20)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // 3. ANIMAL LIST (REAL-TIME STREAM)
            // ==========================================
            Expanded(
              child: _isLoadingShelter
                  ? const Center(child: CircularProgressIndicator())
                  : _myShelterId == null
                  ? _buildEmptyState("You don't have a registered Shelter profile yet.\nPlease complete your shelter setup.")
                  : StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('animals')
                    .stream(primaryKey: ['id'])
                    .eq('shelter_id', _myShelterId!)
                    .order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  final allAnimals = snapshot.data ?? [];

                  // 🚨 Filter locally based on the selected tab
                  final filteredAnimals = allAnimals.where((animal) {
                    final status = animal['status'] ?? 'available';
                    if (_selectedTabIndex == 0) return status == 'available';
                    if (_selectedTabIndex == 1) return status == 'adopted';
                    if (_selectedTabIndex == 2) return status == 'in_treatment';
                    if (_selectedTabIndex == 3) return status == 'foster';
                    return false;
                  }).toList();

                  if (filteredAnimals.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildEmptyState("No animals found in this category.\nClick + to add a new animal."),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
                    itemCount: filteredAnimals.length,
                    itemBuilder: (context, index) {
                      final animal = filteredAnimals[index];
                      return _buildAnimalCard(animal);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  // ==========================================
  // LOGIC: Update Animal Status/Details
  // ==========================================
  Future<void> _updateAnimalDetails(String animalId, String newName, String newAge, String newStatus) async {
    try {
      await Supabase.instance.client.from('animals').update({
        'name': newName.trim(),
        'age': newAge.trim(),
        'status': newStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', animalId);

      if (mounted) {
        Navigator.pop(context); // Close the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Animal updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating animal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==========================================
  // UI: Show View Details Dialog
  // ==========================================
  void _showAnimalDetailsDialog(Map<String, dynamic> animal) {
    final String name = animal['name'] ?? 'Unnamed';
    final String species = animal['species'] ?? 'Pet';
    final String breed = animal['breed'] ?? 'Unknown Breed';
    final String age = animal['age'] ?? 'Unknown';
    final String gender = animal['gender'] ?? 'Unknown';
    final String size = animal['size'] ?? 'Unknown';
    final bool isVaccinated = animal['vaccinated'] ?? false;
    final bool isNeutered = animal['is_neutered'] ?? false;
    final String energy = animal['energy_level'] ?? 'medium';
    final String health = animal['health_condition'] ?? 'No health details provided.';
    final String specialNeeds = animal['special_needs'] ?? 'None.';

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("$name's Details", style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailRow(Icons.pets, "Species/Breed", "${species.toUpperCase()} • $breed"),
                    _buildDetailRow(Icons.cake, "Age & Gender", "$age • ${gender.toUpperCase()}"),
                    _buildDetailRow(Icons.straighten, "Size & Energy", "${size.toUpperCase()} • ${energy.toUpperCase()} Energy"),
                    const Divider(height: 30),

                    Text("Medical Status", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(isVaccinated ? Icons.check_circle : Icons.cancel, color: isVaccinated ? _primaryGreen : Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Text("Vaccinated", style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 15),
                        Icon(isNeutered ? Icons.check_circle : Icons.cancel, color: isNeutered ? _primaryGreen : Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Text("Neutered/Spayed", style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 15),

                    Text("Health Notes", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                      child: Text(health.isEmpty ? "No health notes." : health, style: GoogleFonts.nunito(fontSize: 13)),
                    ),
                    const SizedBox(height: 15),

                    Text("Special Needs", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                      child: Text(specialNeeds.isEmpty ? "None." : specialNeeds, style: GoogleFonts.nunito(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Close", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              )
            ],
          );
        }
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _primaryGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                Text(value, style: GoogleFonts.nunito(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // UI: Show Edit Dialog
  // ==========================================
  void _showEditAnimalDialog(Map<String, dynamic> animal) {
    final String id = animal['id'];
    final TextEditingController nameCtrl = TextEditingController(text: animal['name']);
    final TextEditingController ageCtrl = TextEditingController(text: animal['age']);
    String selectedStatus = animal['status'] ?? 'available';
    bool isSubmitting = false;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text("Edit Animal", style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Name", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      TextField(controller: nameCtrl, decoration: const InputDecoration(isDense: true)),
                      const SizedBox(height: 15),

                      Text("Age", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      TextField(controller: ageCtrl, decoration: const InputDecoration(isDense: true)),
                      const SizedBox(height: 25),

                      Text("Adoption Status", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'available', child: Text("Available")),
                          DropdownMenuItem(value: 'adopted', child: Text("Adopted")),
                          DropdownMenuItem(value: 'in_treatment', child: Text("In Treatment")),
                          DropdownMenuItem(value: 'foster', child: Text("Foster")),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedStatus = val);
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel", style: GoogleFonts.nunito(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      onPressed: isSubmitting
                          ? null
                          : () {
                        setDialogState(() => isSubmitting = true);
                        _updateAnimalDetails(id, nameCtrl.text, ageCtrl.text, selectedStatus);
                      },
                      child: isSubmitting
                          ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text("Save", style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              }
          );
        }
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(height: 60, width: 60, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)), child: Icon(Icons.pets, color: Colors.grey.shade400, size: 28)),
          const SizedBox(width: 15),
          Expanded(
            child: Text(message, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: _textLight)),
          )
        ],
      ),
    );
  }

  Widget _buildAnimalCard(Map<String, dynamic> animal) {
    final String id = animal['id'] ?? '';
    final String shortId = "ID #A-${id.length > 4 ? id.substring(0, 4).toUpperCase() : id}";
    final String name = animal['name'] ?? 'Unnamed';
    final String age = animal['age'] ?? 'Unknown age';
    final String breed = animal['breed'] ?? 'Mixed breed';
    final String size = animal['size'] ?? 'Medium';
    final bool isVaccinated = animal['vaccinated'] ?? false;
    final String status = animal['status'] ?? 'available';

    // Status styling
    Color statusBg = _primaryGreen.withOpacity(0.15);
    Color statusText = _primaryGreen;
    String statusDisplay = "Available";

    if (status == 'adopted') {
      statusBg = Colors.blue.shade100; statusText = Colors.blue.shade700; statusDisplay = "Adopted";
    } else if (status == 'in_treatment') {
      statusBg = Colors.orange.shade100; statusText = Colors.orange.shade800; statusDisplay = "In Treatment";
    } else if (status == 'foster') {
      statusBg = Colors.indigo.shade100; statusText = Colors.indigo.shade600; statusDisplay = "Foster";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🚨 SMART IMAGE WIDGET (Fetches from animal_photos)
              _AnimalCoverImage(animalId: id),
              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: _textDark)),
                        Text(shortId, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: _textLight)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text("$age • $breed • $size", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadge(statusDisplay, statusText, statusBg),
                        if (isVaccinated) _buildBadge("Vaccinated", _primaryGreen, _primaryGreen.withOpacity(0.1)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Bottom Row: Action Buttons
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showAnimalDetailsDialog(animal), // 🚨 WIRED UP!
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: _primaryGreen, borderRadius: BorderRadius.circular(25)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.visibility_outlined, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text("View", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _showEditAnimalDialog(animal),
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade300)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_outlined, color: _textDark, size: 18),
                        const SizedBox(width: 6),
                        Text("Edit", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: textColor)),
    );
  }
}

// ==========================================
// 🚨 SMART WIDGET TO FETCH COVER PHOTO
// ==========================================
class _AnimalCoverImage extends StatefulWidget {
  final String animalId;
  const _AnimalCoverImage({required this.animalId});

  @override
  State<_AnimalCoverImage> createState() => _AnimalCoverImageState();
}

class _AnimalCoverImageState extends State<_AnimalCoverImage> {
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  Future<void> _fetchImage() async {
    try {
      final data = await Supabase.instance.client
          .from('animal_photos')
          .select('bucket, path')
          .eq('animal_id', widget.animalId)
          .limit(1)
          .maybeSingle();

      if (data != null && mounted) {
        final String publicUrl = Supabase.instance.client.storage
            .from(data['bucket'])
            .getPublicUrl(data['path']);

        setState(() {
          imageUrl = publicUrl;
        });
      }
    } catch (e) {
      // Silently fail if no image exists
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      width: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(15),
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: imageUrl == null
          ? Icon(Icons.pets, color: Colors.grey.shade400)
          : null,
    );
  }
}
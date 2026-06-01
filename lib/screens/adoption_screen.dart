import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdoptionScreen extends StatefulWidget {
  const AdoptionScreen({super.key});

  @override
  State<AdoptionScreen> createState() => _AdoptionScreenState();
}

class _AdoptionScreenState extends State<AdoptionScreen> {
  // ==========================================
  // STATE VARIABLES
  // ==========================================
  bool _isLoading = true;
  List<Map<String, dynamic>> _animals = [];
  String _selectedFilter = "All"; // "All", "Dog", "Cat", "Other"

  @override
  void initState() {
    super.initState();
    _fetchAvailableAnimals();
  }

  // ==========================================
  // 1. FETCH ANIMALS FROM DATABASE
  // ==========================================
  Future<void> _fetchAvailableAnimals() async {
    setState(() => _isLoading = true);
    try {
      // Relational Query: Get animal + its photos + its shelter name
      final data = await Supabase.instance.client
          .from('animals')
          .select('''
            *,
            animal_photos (bucket, path, is_cover),
            shelters (name)
          ''')
          .eq('status', 'available')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _animals = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching animals: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // 2. SEND ADOPTION REQUEST LOGIC
  // ==========================================
  Future<void> _sendAdoptionRequest(String animalId, String animalName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to adopt.')));
      return;
    }

    try {
      // Prevent spam: Check if this user already requested this exact animal
      final existingRequest = await Supabase.instance.client
          .from('adoption_requests')
          .select('id')
          .eq('animal_id', animalId)
          .eq('applicant_user_id', user.id)
          .maybeSingle();

      if (existingRequest != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have already submitted a request for this pet!'), backgroundColor: Colors.orange));
        }
        return;
      }

      // Insert the request
      await Supabase.instance.client.from('adoption_requests').insert({
        'animal_id': animalId,
        'applicant_user_id': user.id,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Adoption request sent for $animalName! The shelter will review it soon.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending request: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // Confirmation Dialog so users don't accidentally click and spam requests
  void _confirmAdoption(String animalId, String animalName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Adopt $animalName?", style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: Text("This will send your profile information to the shelter for review. Do you want to proceed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff5bb381)),
            onPressed: () {
              Navigator.pop(context);
              _sendAdoptionRequest(animalId, animalName);
            },
            child: const Text("Yes, Send Request", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),

      // Floating action button
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add_adoption'),
        backgroundColor: const Color(0xffffa94d),
        elevation: 4,
        child: const Icon(Icons.pets, color: Colors.white),
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchAvailableAnimals,
          color: const Color(0xffffa94d),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==========================================
                      // HEADER
                      // ==========================================
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xffffa94d).withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.pets, color: Color(0xffffa94d), size: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Adopt a Friend", style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
                                Text("Find your next rescue companion", style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]), child: const Icon(Icons.favorite_border, color: Colors.black54, size: 20)),
                          const SizedBox(width: 10),
                          const CircleAvatar(radius: 18, backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=5')),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ==========================================
                      // SEARCH BAR
                      // ==========================================
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]),
                              child: TextField(decoration: InputDecoration(hintText: "Search pets, breeds, shelters", hintStyle: GoogleFonts.nunito(color: Colors.grey[400], fontSize: 14), prefixIcon: Icon(Icons.search, color: Colors.grey[400]), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 15))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: const Color(0xffffa94d), borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: const Color(0xffffa94d).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
                            child: Row(children: [const Icon(Icons.location_on_outlined, color: Colors.black87, size: 18), const SizedBox(width: 4), Text("Nearby", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14))]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ==========================================
                      // FILTER CHIPS
                      // ==========================================
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip("All"),
                            _buildFilterChip("Dog"),
                            _buildFilterChip("Cat"),
                            _buildFilterChip("Other"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Available for Adoption", style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
                          Text("${_filteredAnimals().length} pets", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ),

              // ==========================================
              // DYNAMIC PET GRID
              // ==========================================
              if (_isLoading)
                const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator())))
              else if (_filteredAnimals().isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(child: Text("No animals found.", style: GoogleFonts.nunito(color: Colors.grey, fontWeight: FontWeight.bold))),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 2 items per row
                      childAspectRatio: 0.72, // Adjust this ratio if cards look too tall/short
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                    ),
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        return _buildDynamicPetCard(_filteredAnimals()[index]);
                      },
                      childCount: _filteredAnimals().length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  // Filter local state based on chip selected
  List<Map<String, dynamic>> _filteredAnimals() {
    if (_selectedFilter == "All") return _animals;
    return _animals.where((a) => (a['species'] ?? '').toString().toLowerCase() == _selectedFilter.toLowerCase()).toList();
  }

  Widget _buildFilterChip(String label) {
    bool isActive = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xffffa94d) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Text(label, style: GoogleFonts.nunito(fontWeight: isActive ? FontWeight.w800 : FontWeight.w700, color: isActive ? Colors.black87 : Colors.grey[600])),
      ),
    );
  }


  // ==========================================
  // UI: Show Comprehensive Animal Details Dialog
  // ==========================================
  void _showAnimalDetailsDialog(Map<String, dynamic> animal) {
    final String id = animal['id'] ?? '';
    final String name = animal['name'] ?? 'Unknown';
    final String species = animal['species'] ?? 'Pet';
    final String breed = animal['breed'] ?? 'Mixed';
    final String age = animal['age'] ?? 'Unknown Age';
    final String gender = animal['gender'] ?? 'Unknown Gender';
    final String size = animal['size'] ?? 'Medium';
    final bool isVaccinated = animal['vaccinated'] ?? false;
    final bool isNeutered = animal['is_neutered'] ?? false;
    final String energy = animal['energy_level'] ?? 'Medium';
    final String health = animal['health_condition'] ?? '';
    final String specialNeeds = animal['special_needs'] ?? '';
    final String description = animal['description'] ?? 'No description provided.';

    // 🚨 Safely extract the shelter name if it exists, otherwise assume independent rescuer
    final String shelterName = animal['shelters'] != null ? animal['shelters']['name'] : 'Independent Rescuer';

    // 🚨 Convert the photo paths to actual URLs for the slider
    final List photosData = animal['animal_photos'] ?? [];
    final List<String> photoUrls = photosData.map((p) {
      return Supabase.instance.client.storage.from(p['bucket']).getPublicUrl(p['path']);
    }).toList();

    showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.all(15), // Makes it wide
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.white,
                height: MediaQuery.of(context).size.height * 0.85, // 85% of screen height!
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // 1. SCROLLABLE PHOTO LIBRARY (Top Section)
                    SizedBox(
                      height: 280,
                      child: Stack(
                        children: [
                          if (photoUrls.isEmpty)
                            Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.pets, size: 50, color: Colors.grey)))
                          else
                            PageView.builder(
                              itemCount: photoUrls.length,
                              itemBuilder: (context, index) {
                                return Image.network(
                                  photoUrls[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                            SizedBox(height: 8),
                                            Text("Image unavailable", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),

                          // Image Counter Pill
                          if (photoUrls.length > 1)
                            Positioned(
                              bottom: 10, right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(15)),
                                child: Text("Swipe for more", style: GoogleFonts.nunito(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),

                          // Close Button Overlay
                          Positioned(
                            top: 10, right: 10,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 20)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. SCROLLABLE DETAILS (Middle Section)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name and Shelter Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87)),
                                      Text("$breed • $age • $gender", style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                // Shelter/Owner Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xffffa94d).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.home_work_outlined, color: Color(0xffd97706), size: 16),
                                      const SizedBox(height: 4),
                                      Text(shelterName, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xffd97706))),
                                    ],
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Quick Info Grid
                            Wrap(
                              spacing: 10, runSpacing: 10,
                              children: [
                                _buildInfoChip(Icons.straighten, "Size", size.toUpperCase()),
                                _buildInfoChip(Icons.bolt, "Energy", energy.toUpperCase()),
                                if (isVaccinated) _buildInfoChip(Icons.vaccines, "Vaccinated", "YES"),
                                if (isNeutered) _buildInfoChip(Icons.content_cut, "Neutered", "YES"),
                              ],
                            ),
                            const Divider(height: 30),

                            // Description
                            Text("About $name", style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
                            const SizedBox(height: 8),
                            Text(description, style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade700, height: 1.5)),
                            const SizedBox(height: 20),

                            // Medical Notes (Only shows if they exist!)
                            if (health.isNotEmpty || specialNeeds.isNotEmpty) ...[
                              Text("Health & Special Needs", style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity, padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (health.isNotEmpty) Text("Health: $health", style: GoogleFonts.nunito(fontSize: 13, color: Colors.red.shade900)),
                                    if (health.isNotEmpty && specialNeeds.isNotEmpty) const SizedBox(height: 4),
                                    if (specialNeeds.isNotEmpty) Text("Special Needs: $specialNeeds", style: GoogleFonts.nunito(fontSize: 13, color: Colors.red.shade900)),
                                  ],
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),

                    // 3. BOTTOM ADOPT BUTTON
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff5bb381),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          _sendAdoptionRequest(id, name); // 🚨 Trigger your existing submission function!
                        },
                        child: Text("Submit Adoption Request", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        }
    );
  }

  // Small helper widget for the new dialog
  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text("$label: ", style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          Text(value, style: GoogleFonts.nunito(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
  Widget _buildDynamicPetCard(Map<String, dynamic> animal) {
    final String id = animal['id'] ?? '';
    final String name = animal['name'] ?? 'Unknown';
    final String species = animal['species'] ?? 'Pet';
    final String age = animal['age'] ?? '';
    final String gender = animal['gender'] ?? '';
    final String city = animal['city'] ?? 'Local';
    final bool isVaccinated = animal['vaccinated'] ?? false;
    final String energyLevel = animal['energy_level'] ?? 'medium';

    String? imageUrl;
    final List photos = animal['animal_photos'] ?? [];
    if (photos.isNotEmpty) {
      final coverPhoto = photos.firstWhere((p) => p['is_cover'] == true, orElse: () => photos.first);
      imageUrl = Supabase.instance.client.storage.from(coverPhoto['bucket']).getPublicUrl(coverPhoto['path']);
    }

    return GestureDetector(
      // 🚨 CHANGED: Now opens the massive details dialog instead of immediately confirming
      onTap: () => _showAnimalDetailsDialog(animal),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE
            Stack(
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    image: imageUrl != null ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
                  ),
                  child: imageUrl == null ? const Center(child: Icon(Icons.pets, color: Colors.grey)) : null,
                ),
                Positioned(
                  top: 10, right: 10,
                  child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.favorite_border, size: 16, color: Colors.black54)),
                )
              ],
            ),

            // DETAILS
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text("${species[0].toUpperCase()}${species.substring(1)} • $age • $gender", style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(child: Text(city, style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
                    ),

                    // DYNAMIC TAG PILL
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xff5bb381).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isVaccinated ? Icons.medical_services_outlined : Icons.bolt, size: 10, color: const Color(0xff15803d)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: FittedBox(
                              child: Text(
                                // 🚨 FIXED: Ensured the word "Energy" is printed regardless of vaccination status!
                                isVaccinated
                                    ? "Vaccinated • ${energyLevel[0].toUpperCase()}${energyLevel.substring(1)} Energy"
                                    : "${energyLevel[0].toUpperCase()}${energyLevel.substring(1)} Energy",
                                style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xff15803d)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
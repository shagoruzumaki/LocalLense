import 'package:flutter/material.dart';
import '../../api/admin_api.dart';

/// Admin screen for full Restaurant CRUD.
/// Reachable only from ProfilePage when role == 'admin'.
class AdminRestaurantsScreen extends StatefulWidget {
  const AdminRestaurantsScreen({super.key});

  @override
  State<AdminRestaurantsScreen> createState() => _AdminRestaurantsScreenState();
}

class _AdminRestaurantsScreenState extends State<AdminRestaurantsScreen> {
  final AdminApi _adminApi = AdminApi();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _restaurants = [];

  static const _categories = ['restaurant', 'cafe', 'street_food', 'fine_dining'];

  @override
  void initState() {
    super.initState();
    _fetchRestaurants();
  }

  Future<void> _fetchRestaurants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _adminApi.getAllRestaurants();
      if (mounted) setState(() => _restaurants = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> restaurant) async {
    final id = restaurant['id'] as String;
    final isActive = restaurant['active'] == true;
    try {
      if (isActive) {
        await _adminApi.softDeleteRestaurant(id);
      } else {
        await _adminApi.restoreRestaurant(id);
      }
      _showSnack(isActive ? 'Restaurant deactivated' : 'Restaurant restored');
      _fetchRestaurants();
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFFFFD700),
    ));
  }

  Future<void> _openRestaurantForm({Map<String, dynamic>? existing}) async {
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final addressController = TextEditingController(text: existing?['address'] ?? '');
    final phoneController = TextEditingController(text: existing?['phone'] ?? '');
    final latController = TextEditingController(text: existing?['latitude']?.toString() ?? '');
    final lngController = TextEditingController(text: existing?['longitude']?.toString() ?? '');
    String category = existing?['category'] ?? _categories.first;
    int priceTier = existing != null ? (existing['price_tier'] ?? 1) : 1;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            existing == null ? 'Add Restaurant' : 'Edit Restaurant',
            style: const TextStyle(color: Colors.white, fontFamily: 'serif'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _formField(nameController, 'Name'),
                const SizedBox(height: 12),
                _formField(addressController, 'Address'),
                const SizedBox(height: 12),
                _formField(phoneController, 'Phone (optional)'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _formField(latController, 'Latitude', isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _formField(lngController, 'Longitude', isNumber: true)),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD700))),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => category = val ?? category),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: priceTier,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Price Tier (1=budget, 4=luxury)',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD700))),
                  ),
                  items: [1, 2, 3, 4]
                      .map((p) => DropdownMenuItem(value: p, child: Text('$p')))
                      .toList(),
                  onChanged: (val) => setDialogState(() => priceTier = val ?? priceTier),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final address = addressController.text.trim();
                final lat = double.tryParse(latController.text.trim());
                final lng = double.tryParse(lngController.text.trim());

                if (name.isEmpty || address.isEmpty || lat == null || lng == null) {
                  _showSnack('Please fill name, address, and valid coordinates', isError: true);
                  return;
                }

                try {
                  if (existing == null) {
                    await _adminApi.addRestaurant(
                      name: name,
                      category: category,
                      address: address,
                      latitude: lat,
                      longitude: lng,
                      priceTier: priceTier,
                      phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                    );
                  } else {
                    await _adminApi.updateRestaurant(existing['id'] as String, {
                      'name': name,
                      'category': category,
                      'address': address,
                      'latitude': lat,
                      'longitude': lng,
                      'price_tier': priceTier,
                      'phone': phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                    });
                  }
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  _showSnack('Save failed: $e', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
              child: Text(
                existing == null ? 'Add' : 'Save',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      _showSnack(existing == null ? 'Restaurant added' : 'Restaurant updated');
      _fetchRestaurants();
    }
  }

  Widget _formField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD700))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD700))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Manage Restaurants', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFD700),
        onPressed: () => _openRestaurantForm(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchRestaurants,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
              child: const Text('Retry', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }
    if (_restaurants.isEmpty) {
      return const Center(
        child: Text('No restaurants yet. Tap + to add one.', style: TextStyle(color: Colors.white54)),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRestaurants,
      color: const Color(0xFFFFD700),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: _restaurants.length,
        itemBuilder: (context, index) {
          final r = _restaurants[index];
          final isActive = r['active'] == true;
          final score = (r['algorithm_score'] as num?)?.toDouble() ?? 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isActive ? Colors.white10 : Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r['name'] ?? 'Unnamed',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('INACTIVE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${r['category'] ?? ''} • ${r['address'] ?? ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                    const SizedBox(width: 4),
                    Text('Score: ${score.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openRestaurantForm(existing: r),
                        icon: const Icon(Icons.edit, size: 16, color: Color(0xFFFFD700)),
                        label: const Text('Edit', style: TextStyle(color: Color(0xFFFFD700))),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFFD700))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleActive(r),
                        icon: Icon(isActive ? Icons.visibility_off : Icons.visibility, size: 16, color: isActive ? Colors.redAccent : Colors.greenAccent),
                        label: Text(
                          isActive ? 'Deactivate' : 'Restore',
                          style: TextStyle(color: isActive ? Colors.redAccent : Colors.greenAccent),
                        ),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: isActive ? Colors.redAccent : Colors.greenAccent)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

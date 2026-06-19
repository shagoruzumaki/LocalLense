import 'package:flutter/material.dart';
import '../../api/admin_api.dart';

/// Admin screen for Dish CRUD.
/// Flow: pick a restaurant first, then manage that restaurant's dishes.
class AdminDishesScreen extends StatefulWidget {
  const AdminDishesScreen({super.key});

  @override
  State<AdminDishesScreen> createState() => _AdminDishesScreenState();
}

class _AdminDishesScreenState extends State<AdminDishesScreen> {
  final AdminApi _adminApi = AdminApi();

  bool _isLoadingRestaurants = true;
  List<Map<String, dynamic>> _restaurants = [];
  Map<String, dynamic>? _selectedRestaurant;

  bool _isLoadingDishes = false;
  List<Map<String, dynamic>> _dishes = [];

  @override
  void initState() {
    super.initState();
    _fetchRestaurants();
  }

  Future<void> _fetchRestaurants() async {
    setState(() => _isLoadingRestaurants = true);
    try {
      final data = await _adminApi.getAllRestaurants();
      if (mounted) setState(() => _restaurants = data);
    } catch (e) {
      _showSnack('Failed to load restaurants: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingRestaurants = false);
    }
  }

  Future<void> _fetchDishes(String restaurantId) async {
    setState(() => _isLoadingDishes = true);
    try {
      final data = await _adminApi.getDishesByRestaurant(restaurantId);
      if (mounted) setState(() => _dishes = data);
    } catch (e) {
      _showSnack('Failed to load dishes: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingDishes = false);
    }
  }

  void _selectRestaurant(Map<String, dynamic> restaurant) {
    setState(() {
      _selectedRestaurant = restaurant;
      _dishes = [];
    });
    _fetchDishes(restaurant['id'] as String);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFFFFD700),
    ));
  }

  Future<void> _confirmDelete(Map<String, dynamic> dish) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Dish?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete "${dish['name']}" and its reviews. This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminApi.deleteDish(dish['id'] as String);
        _showSnack('Dish deleted');
        if (_selectedRestaurant != null) _fetchDishes(_selectedRestaurant!['id'] as String);
      } catch (e) {
        _showSnack('Delete failed: $e', isError: true);
      }
    }
  }

  Future<void> _toggleAvailability(Map<String, dynamic> dish) async {
    final newValue = !(dish['is_available'] == true);
    try {
      await _adminApi.toggleDishAvailability(dish['id'] as String, newValue);
      if (_selectedRestaurant != null) _fetchDishes(_selectedRestaurant!['id'] as String);
    } catch (e) {
      _showSnack('Update failed: $e', isError: true);
    }
  }

  Future<void> _openDishForm({Map<String, dynamic>? existing}) async {
    if (_selectedRestaurant == null) return;
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final descController = TextEditingController(text: existing?['description'] ?? '');
    final priceController = TextEditingController(text: existing?['price']?.toString() ?? '');
    final categoryController = TextEditingController(text: existing?['category'] ?? '');
    bool isAvailable = existing != null ? (existing['is_available'] ?? true) : true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            existing == null ? 'Add Dish' : 'Edit Dish',
            style: const TextStyle(color: Colors.white, fontFamily: 'serif'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _formField(nameController, 'Dish Name'),
                const SizedBox(height: 12),
                _formField(descController, 'Description', maxLines: 2),
                const SizedBox(height: 12),
                _formField(priceController, 'Price', isNumber: true),
                const SizedBox(height: 12),
                _formField(categoryController, 'Category (optional)'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Available', style: TextStyle(color: Colors.white70)),
                    const Spacer(),
                    Switch(
                      value: isAvailable,
                      activeColor: const Color(0xFFFFD700),
                      onChanged: (val) => setDialogState(() => isAvailable = val),
                    ),
                  ],
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
                final price = double.tryParse(priceController.text.trim());

                if (name.isEmpty) {
                  _showSnack('Please enter a dish name', isError: true);
                  return;
                }

                try {
                  if (existing == null) {
                    await _adminApi.addDish(
                      restaurantId: _selectedRestaurant!['id'] as String,
                      name: name,
                      description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                      price: price,
                      category: categoryController.text.trim().isEmpty ? null : categoryController.text.trim(),
                      isAvailable: isAvailable,
                    );
                  } else {
                    await _adminApi.updateDish(existing['id'] as String, {
                      'name': name,
                      'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                      'price': price,
                      'category': categoryController.text.trim().isEmpty ? null : categoryController.text.trim(),
                      'is_available': isAvailable,
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
      _showSnack(existing == null ? 'Dish added' : 'Dish updated');
      if (_selectedRestaurant != null) _fetchDishes(_selectedRestaurant!['id'] as String);
    }
  }

  Widget _formField(TextEditingController controller, String label, {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
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
          onPressed: () {
            if (_selectedRestaurant != null) {
              setState(() {
                _selectedRestaurant = null;
                _dishes = [];
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _selectedRestaurant == null ? 'Manage Dishes' : _selectedRestaurant!['name'] ?? 'Dishes',
          style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      floatingActionButton: _selectedRestaurant == null
          ? null
          : FloatingActionButton(
        backgroundColor: const Color(0xFFFFD700),
        onPressed: () => _openDishForm(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: _selectedRestaurant == null ? _buildRestaurantPicker() : _buildDishList(),
    );
  }

  Widget _buildRestaurantPicker() {
    if (_isLoadingRestaurants) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }
    if (_restaurants.isEmpty) {
      return const Center(child: Text('No restaurants found.', style: TextStyle(color: Colors.white54)));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Select a restaurant to manage its menu',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchRestaurants,
            color: const Color(0xFFFFD700),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: _restaurants.length,
              itemBuilder: (context, index) {
                final r = _restaurants[index];
                return GestureDetector(
                  onTap: () => _selectRestaurant(r),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_outlined, color: Colors.white70, size: 20),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r['name'] ?? 'Unnamed', style: const TextStyle(color: Colors.white, fontSize: 15)),
                              Text(r['category'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white38),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDishList() {
    if (_isLoadingDishes) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }
    if (_dishes.isEmpty) {
      return const Center(
        child: Text('No dishes yet. Tap + to add one.', style: TextStyle(color: Colors.white54)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchDishes(_selectedRestaurant!['id'] as String),
      color: const Color(0xFFFFD700),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: _dishes.length,
        itemBuilder: (context, index) {
          final d = _dishes[index];
          final isAvailable = d['is_available'] == true;
          final price = d['price'];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isAvailable ? Colors.white10 : Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d['name'] ?? 'Unnamed',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (price != null)
                      Text('৳${price.toString()}', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                  ],
                ),
                if ((d['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(d['description'], style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isAvailable ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                        style: TextStyle(color: isAvailable ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openDishForm(existing: d),
                        icon: const Icon(Icons.edit, size: 16, color: Color(0xFFFFD700)),
                        label: const Text('Edit', style: TextStyle(color: Color(0xFFFFD700))),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFFD700))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleAvailability(d),
                        icon: Icon(isAvailable ? Icons.visibility_off : Icons.visibility, size: 16, color: Colors.white70),
                        label: Text(isAvailable ? 'Hide' : 'Show', style: const TextStyle(color: Colors.white70)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _confirmDelete(d),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                      child: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
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

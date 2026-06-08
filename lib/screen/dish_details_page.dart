import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/dish.dart';

class DishDetailsPage extends StatefulWidget {
  final Dish dish;
  const DishDetailsPage({super.key, required this.dish});

  @override
  State<DishDetailsPage> createState() => _DishDetailsPageState();
}

class _DishDetailsPageState extends State<DishDetailsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _fetchDishReviews();
  }

  Future<void> _fetchDishReviews() async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('*, users(name, profile_photo_url)')
          .contains('dish_mentions', [widget.dish.name])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(response);
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF0D0D0D),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.dish.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.white10),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          const Color(0xFF0D0D0D),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.dish.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif',
                          ),
                        ),
                      ),
                      Text(
                        'Tk ${widget.dish.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFFD70F64),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: widget.dish.restaurantId),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.restaurant, size: 16, color: Color(0xFFD70F64)),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.dish.restaurantName ?? 'Restaurant',
                                    style: const TextStyle(
                                      color: Color(0xFFD70F64),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.dish.restaurantAddress ?? 'Location not available',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.dish.restaurantRating != null)
                          Row(
                            children: [
                              const Icon(Icons.star, color: Color(0xFFFFD700), size: 18),
                              const SizedBox(width: 4),
                              Text(
                                widget.dish.restaurantRating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (widget.dish.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        widget.dish.category!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: Color(0xFFE5D8B0),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.dish.description ?? 'No description available.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 35),
                  const Text(
                    'Reviews',
                    style: TextStyle(
                      color: Color(0xFFE5D8B0),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isLoadingReviews)
                    const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
                  else if (_reviews.isEmpty)
                    const Text(
                      'No reviews for this dish yet.',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _reviews.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 30),
                      itemBuilder: (context, index) {
                        final review = _reviews[index];
                        final user = review['users'] as Map<String, dynamic>? ?? {};
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white10,
                                  backgroundImage: user['profile_photo_url'] != null
                                      ? NetworkImage(user['profile_photo_url'])
                                      : null,
                                  child: user['profile_photo_url'] == null 
                                      ? const Icon(Icons.person, size: 18, color: Colors.white38) 
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['name'] ?? 'Anonymous',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Row(
                                        children: List.generate(5, (i) => Icon(
                                          Icons.star,
                                          size: 12,
                                          color: i < (review['rating'] ?? 0) ? const Color(0xFFFFD700) : Colors.white10,
                                        )),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatDate(review['created_at']),
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              review['body'] ?? '',
                              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}

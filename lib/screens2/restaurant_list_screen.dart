import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'promotion_model.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'PromotionDetailScreen.dart';
import 'about_us_screen.dart';
import 'cart_screen.dart';
import 'menu_screen.dart';
import 'change_user_info_screen.dart';
import 'order_screen.dart';
import 'theme_provider.dart';
import 'package:dw_app/constants/api_constants.dart';

class RestaurantListScreen extends StatefulWidget {
  final String username;
  final int userId;

  const RestaurantListScreen({
    Key? key,
    required this.username,
    required this.userId,
  }) : super(key: key);

  @override
  _RestaurantListScreenState createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  List<Map<String, dynamic>> restaurants = [];
  List<Map<String, dynamic>> promotions = []; // Changed to empty list
  bool isLoading = true;
  bool hasError = false;
  bool isLoadingPromotions = true; // Added loading state for promotions
  int _currentIndex = 0;
  String location = 'Loading location...';
  String? errorMessage;
  bool isLoadingFamousFoods = true;
  http.Response? response; // Make sure you have 'import 'package:http/http.dart' as http;' at the top
  List<Map<String, dynamic>> featuredFoods = [
    // initial dummy data
  ];

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchPromotions(); // Fetch promotions when screen loads
    _fetchFamousFoods();
  }
  Future<void> _fetchPromotions() async {
    final url = '${ApiConstants.baseUrl}get_promotions.php';
    debugPrint('Fetching promotions from: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded['success'] == true) {
          final List<dynamic> promoData = decoded['promotions'] ?? [];

          debugPrint('Received ${promoData.length} promotions');

          setState(() {
            promotions = promoData.map((json) {
              return {
                'id': json['id'],
                'title': json['title'] ?? 'No Title',
                'description': json['description'] ?? '',
                'image_url': json['image_url'],
                'current_price': json['current_price'] ?? 0.0,
                'original_price': json['original_price'] ?? 0.0,
                'restaurant_name': json['restaurant_name'] ?? 'Unknown Restaurant',
                'tag': json['tag'] ?? ''
              };
            }).toList();
            hasError = false;
          });
        } else {
          throw Exception(decoded['error'] ?? 'Failed to load promotions');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching promotions: $e');
      setState(() {
        hasError = true;
        errorMessage = e.toString();
      });
    } finally {
      setState(() => isLoadingPromotions = false);
    }
  }


  void _handleError(String message) {
    debugPrint(message);
    setState(() {
      hasError = true;
      errorMessage = message;
    });
    // Optional: Show error to user via snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }


  String? _validateImageUrl(dynamic url) {
    if (url == null || url.toString().isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(url.toString());
    return (uri != null && (uri.scheme == 'http' || uri.scheme == 'https'))
        ? url.toString()
        : null;
  }

  Future<void> _fetchFamousFoods() async {
    final url = '${ApiConstants.baseUrl}get_famous_foods.php';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final List<dynamic> foods = data['famous_foods'] ?? [];

          setState(() {
            featuredFoods = foods.map((food) {
              double price = 0;
              // Safe parsing of price:
              try {
                price = double.parse(food['price'].toString());
              } catch (_) {}

              return {
                'name': food['name'] ?? 'Unknown',
                'price': '${price.toStringAsFixed(2)} Br',
                'image': food['image_url'] ?? '',
                'tag': 'Famous',
              };
            }).toList();
          });
        } else {
          _handleError(data['error'] ?? 'Failed to fetch famous foods');
        }
      } else {
        _handleError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _handleError('Network error: $e');
    }
  }


  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          location = 'Location services disabled';
          hasError = true;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            location = 'Location permissions denied';
            hasError = true;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          location = 'Location permissions permanently denied';
          hasError = true;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        location = 'Current Location';
      });
      await fetchRestaurants(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
        location = 'Error getting location';
      });
    }
  }

  Future<void> fetchRestaurants(double latitude, double longitude) async {
    try {
      final response = await http.get(Uri.parse(
        '${ApiConstants.baseUrl}get_restaurants.php?latitude=$latitude&longitude=$longitude',
      ));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            restaurants = List<Map<String, dynamic>>.from(data['restaurants']);
            hasError = false;
          });
        } else {
          setState(() {
            hasError = true;
          });
        }
      } else {
        setState(() {
          hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildPromotionsSection() {
    if (isLoadingPromotions) {
      return Container(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (promotions.isEmpty) {
      return SizedBox.shrink(); // Don't show section if no promotions
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Special Promotions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 10),
        Container(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: promotions.length,
            itemBuilder: (context, index) {
              final promo = promotions[index];
              return PromotionCard(
                promotion: promo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PromotionDetailScreen(
                        title: promo['title'] ?? 'No Title',
                        description: promo['description'] ?? '',
                        currentPrice: (promo['current_price'] ?? 0).toDouble(),
                        originalPrice: (promo['original_price'] ?? 0).toDouble(),
                        imageUrl: promo['image_url'] ?? '',
                        restaurantName: promo['restaurant_name'] ?? 'Unknown',
                        restaurantImage: promo['restaurant_image'] ?? '', // Make sure you have this field from backend
                        deliveryTime: promo['delivery_time'] ?? 'N/A', // If you have this info
                      ),
                    ),
                  );
                },

              );
            },
          ),
        ),

        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFeaturedFoodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Famous Food',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 10),
        Container(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: featuredFoods.length,
            itemBuilder: (context, index) {
              return FeaturedFoodCard(food: featuredFoods[index]);
            },
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRestaurantsSection() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load restaurants'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  hasError = false;
                });
                _determinePosition();
              },
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (restaurants.isEmpty) {
      return Center(child: Text('No restaurants found.'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: restaurants.length,
      itemBuilder: (context, index) {
        return RestaurantCard(
          restaurant: restaurants[index],
          userId: widget.userId, // Add this line to pass the userId
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MenuScreen(
                  restaurantId: int.tryParse(restaurants[index]['id']?.toString() ?? '0') ?? 0,
                  userId: widget.userId,
                  restaurantName: restaurants[index]['name']?.toString() ?? 'Restaurant',
                  restaurantImage: restaurants[index]['image_url']?.toString() ?? '',
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(location),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme(!isDarkMode);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search for food...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
            ),

            if (promotions.isNotEmpty) _buildPromotionsSection(),

            if (featuredFoods.isNotEmpty) _buildFeaturedFoodsSection(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'All lounges nearby',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 10),
            _buildRestaurantsSection(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          setState(() => _currentIndex = index);
          switch (index) {
            case 1:
              Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen(userId: widget.userId,)));
              break;
            case 2:
              Navigator.push(context, MaterialPageRoute(
                  builder: (context) => OrderScreen(userId: widget.userId)));
              break;
            case 3:
              Navigator.push(context, MaterialPageRoute(
                  builder: (context) => ChangeUserInfoScreen(
                    username: widget.username,
                    userId: widget.userId,
                  )));
              break;
          }
        },
      ),
    );
  }
}

class PromotionCard extends StatelessWidget {
  final Map<String, dynamic> promotion;
  final VoidCallback? onTap;

  const PromotionCard({
    Key? key,
    required this.promotion,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        margin: EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey[200], // Fallback background color
        ),
        child: Stack(
          children: [
            // Image with error handling
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                promotion['image_url'] ?? '',
                height: double.infinity,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Center(
                      child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey[500]),
                    ),
                  );
                },
              ),
            ),
            if (promotion['tag'] != null)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    promotion['tag'],
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promotion['title'] ?? 'Promotion',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (promotion['restaurant_name'] != null)
                      Text(
                        promotion['restaurant_name'],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    if (promotion['current_price'] != null && promotion['original_price'] != null)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Text(
                              '${promotion['current_price']} Br',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${promotion['original_price']} Br',
                              style: TextStyle(
                                color: Colors.white54,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class FeaturedFoodCard extends StatelessWidget {
  final Map<String, dynamic> food;

  const FeaturedFoodCard({Key? key, required this.food}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      margin: EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              color: Colors.grey[200], // Fallback background
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              child: Image.network(
                food['image'] ?? '',
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(Icons.fastfood, size: 40, color: Colors.grey[500]),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food['name'] ?? 'Food Item',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  food['price'] ?? '',
                  style: TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class RestaurantCard extends StatefulWidget {
  final Map<String, dynamic> restaurant;
  final int userId;
  final VoidCallback onTap;

  const RestaurantCard({
    Key? key,
    required this.restaurant,
    required this.userId,
    required this.onTap,
  }) : super(key: key);

  @override
  _RestaurantCardState createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<RestaurantCard> {
  late double _currentRating;
  bool _isSubmitting = false;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _currentRating = double.tryParse(widget.restaurant['rating']?.toString() ?? '0') ?? 0;
    _loadUserRating();
  }

  Future<void> _loadUserRating() async {
    try {
      final ratings = await RatingService.getRatings(
        restaurantId: int.parse(widget.restaurant['id'].toString()),
        userId: widget.userId,
      );

      if (mounted) {
        setState(() {
          _currentRating = ratings['user_rating'] ?? 0.0;
          _loadError = false;
          widget.restaurant['rating'] = ratings['average_rating'];
          widget.restaurant['total_reviews'] = ratings['total_reviews'];
        });
      }
    } catch (e) {
      debugPrint('Error loading rating: $e');
      if (mounted) {
        setState(() {
          _loadError = true;
        });
      }
    }
  }

  Future<void> _submitRating(double rating) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final restaurantId = int.parse(widget.restaurant['id'].toString());
      final userId = widget.userId;

      debugPrint('Submitting rating: $rating for restaurant $restaurantId');

      await RatingService.submitRating(
        restaurantId: restaurantId,
        userId: userId,
        rating: rating,
      );

      // Refresh the ratings after successful submission
      await _loadUserRating();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating submitted successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Rating submission failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                widget.restaurant['image_url'] ?? '',
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Image load error: $error');
                  return Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 50),
                        Text('Failed to load image'),
                        Text(widget.restaurant['image_url'] ?? 'No URL'),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant name
                  Text(
                    widget.restaurant['name'] ?? 'Restaurant',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Restaurant description if available
                  if (widget.restaurant['description'] != null)
                    Text(
                      widget.restaurant['description']!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),

                  // Rating and distance row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Rating section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_loadError)
                              const Text(
                                'Error loading ratings',
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              )
                            else
                              Column(
                                children: [
                                  RatingBar.builder(
                                    initialRating: _currentRating,
                                    minRating: 1,
                                    direction: Axis.horizontal,
                                    allowHalfRating: true,
                                    itemCount: 5,
                                    itemSize: 20,
                                    itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                                    itemBuilder: (context, _) => const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                    ),
                                    onRatingUpdate: _submitRating,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${widget.restaurant['total_reviews'] ?? 0} reviews',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                          ],
                        )
                      ),

                      // Distance information
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.restaurant['distance']?.toStringAsFixed(1) ?? '0'} km',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class RatingService {
  static Future<Map<String, dynamic>> submitRating({
    required int restaurantId,
    required int userId,
    required double rating,
    String review = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}submit_rating.php'), // Verify this path
        body: {
          'restaurant_id': restaurantId.toString(),
          'user_id': userId.toString(),
          'rating': rating.toString(),
          'review': review,
        },
      );
      // ... rest of the code

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to submit rating: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error submitting rating: $e');
    }
  }

  static Future<Map<String, dynamic>> getRatings({
    required int restaurantId,
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}get_restaurant_ratings.php?restaurant_id=$restaurantId&user_id=$userId',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Debug print to verify response
        debugPrint('Rating API Response: $data');

        // Ensure the response has the expected structure
        if (data is Map<String, dynamic> && data['success'] == true) {
          return {
            'average_rating': data['average_rating']?.toDouble() ?? 0.0,
            'total_reviews': data['total_reviews'] ?? 0,
            'user_rating': data['user_rating']?.toDouble() ?? 0.0,
          };
        } else {
          throw Exception(data['error'] ?? 'Invalid rating data structure');
        }
      } else {
        throw Exception('Failed to load ratings: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('RatingService Error: $e');
      rethrow;
    }
  }
}
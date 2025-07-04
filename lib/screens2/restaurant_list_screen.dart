import 'dart:convert';
import 'package:flutter/material.dart';
import 'shop_items_screen.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'about_us_screen.dart';
import 'cart_screen.dart';
import 'menu_screen.dart';
import 'change_user_info_screen.dart';
import 'order_screen.dart';
import 'theme_provider.dart'; // Import your ThemeProvider
import 'dart:async';
import 'package:dw_app/constants/api_constants.dart';  // Import the constants file
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:carousel_slider/carousel_slider.dart';

class RestaurantListScreen extends StatefulWidget {
  final String username;
  final int userId;

  RestaurantListScreen({required this.username, required this.userId});

  @override
  _RestaurantListScreenState createState() => _RestaurantListScreenState();
}
class _RestaurantListScreenState extends State<RestaurantListScreen> {
  List<Map<String, dynamic>> restaurants = [];
  List<Map<String, dynamic>> categories = [
    {'id': 1, 'name': 'Clothes'},
    {'id': 2, 'name': 'Shoes'},
    {'id': 3, 'name': 'Electronics'},
    {'id': 4, 'name': 'Others'},
  ];

  List<Map<String, dynamic>> shops = []; // Add this line to declare shops
  bool isLoadingShops = false;
  bool isLoading = true;
  PageController _pageController = PageController(); // Page controller for sliding between pages
  int _currentIndex = 0; // To track the current page index
  int selectedCategoryId = 1; // Default to the Clothes category
  final List<String> _pages = ['Restaurants', 'Market']; // List of views (like Telegram)
  String searchQuery = ''; // For storing the search query
  List<Map<String, dynamic>> searchResults = []; // For storing search results
  bool isSearching = false; // To track if a search is in progress
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    fetchShops(selectedCategoryId); // Fetch shops for the default category on initialization
  }

  Future<Position> _determinePosition() async {
    // Your existing location code
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied.');
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied.');
      return Future.error('Location permissions are permanently denied');
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      print('User location: latitude: ${position.latitude}, longitude: ${position.longitude}');
      fetchRestaurants(position.latitude, position.longitude);
      return position;
    } catch (e) {
      print('Error fetching location: $e');
      return Future.error('Failed to determine location');
    }
  }

  Future<void> fetchRestaurants(double latitude, double longitude) async {
    // Your existing fetchRestaurants code
    try {
      final response = await http.get(Uri.parse(
        '${ApiConstants.baseUrl}get_restaurants.php?&latitude=${latitude}&longitude=${longitude}',
      ));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);

        if (data['success'] == true) {
          setState(() {
            restaurants = List<Map<String, dynamic>>.from(data['restaurants']);
          });
        } else {
          print('Unexpected response format: $data');
        }
      } else {
        print('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception caught: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode; // Get current theme mode

    return Scaffold(
      appBar: AppBar(
        title: Text('M Delivery'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _determinePosition(); // Reload the restaurant page
              });
            },
          ),
        ],
      ),

      drawer: Drawer(
        // Your existing Drawer code
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.deepOrange,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${widget.username}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Dark Mode', style: TextStyle(color: Colors.white)),
                    value: isDarkMode,
                    onChanged: (bool value) {
                      themeProvider.toggleTheme(value); // Call toggleTheme to switch themes
                    },
                    secondary: Icon(
                      isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text('About Us'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AboutUsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangeUserInfoScreen(
                      username: widget.username,
                      userId: widget.userId,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.receipt_long),
              title: Text('Orders'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderScreen(
                      userId: widget.userId,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.shopping_cart),
              title: Text('Cart'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CartScreen(
                      userId: widget.userId,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          _buildPageHeader(), // Page header with current view indicator
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index; // Update current index on page swipe
                });
              },
              children: [
                _buildRestaurantListPage(),
                _buildMarketPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_pages.length, (index) {
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Text(
              _pages[index],
              style: TextStyle(
                fontSize: 18,
                fontWeight: _currentIndex == index ? FontWeight.bold : FontWeight.normal,
                color: _currentIndex == index ? Colors.blue : Colors.black,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRestaurantListPage() {
    return isLoading
        ? Center(child: CircularProgressIndicator())
        : restaurants.isEmpty
        ? Center(child: Text('No restaurants found.'))
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          color: Colors.blueAccent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome ${widget.username}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please choose the restaurant you want to order from:',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              return FutureBuilder<Map<String, dynamic>>(
                future: fetchRestaurantRating(
                  int.parse(restaurants[index]['id']),
                  widget.userId, // Pass the user ID
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        title: Text(
                          restaurants[index]['name'],
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Loading rating...'),
                        trailing: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        title: Text(
                          restaurants[index]['name'],
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Error loading rating'),
                        trailing: Icon(Icons.error, color: Colors.red),
                      ),
                    );
                  }

                  double averageRating = (snapshot.data?['average_rating'] ?? 0.0).toDouble();
                  int totalRatings = snapshot.data?['total_reviews'] ?? 0;
                  double userRating = (snapshot.data?['user_rating'] ?? 0.0).toDouble(); // User's rating

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              restaurants[index]['name'],
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          RatingBar.builder(
                            initialRating: userRating, // Use user's previous rating
                            minRating: 1,
                            direction: Axis.horizontal,
                            allowHalfRating: true,
                            itemCount: 5,
                            itemSize: 20,
                            itemPadding: EdgeInsets.symmetric(horizontal: 2.0),
                            itemBuilder: (context, _) =>
                                Icon(Icons.star, color: Colors.amber),
                            onRatingUpdate: (newRating) {
                              submitRating(
                                widget.userId,
                                int.parse(restaurants[index]['id']),
                                newRating,
                              );
                            },
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 5),
                          Text(
                            'Distance: ${restaurants[index]['distance']} km\n${restaurants[index]['description']}\npackaging: ${restaurants[index]['packaging']}',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 5),
                          Text(
                            '⭐ ${averageRating.toStringAsFixed(1)} ( $totalRatings reviews)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MenuScreen(
                              restaurantId: int.parse(restaurants[index]['id']),
                              userId: widget.userId,
                            ),
                          ),
                        );
                      },
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


  Future<Map<String, dynamic>> fetchRestaurantRating(int restaurantId, int userId) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}get_restaurant_ratings.php?restaurant_id=$restaurantId&user_id=$userId'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load restaurant ratings");
    }
  }

  Future<void> submitRating(int userId, int restaurantId, double rating) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}submit_rating.php'),
      body: {
        'user_id': userId.toString(),
        'restaurant_id': restaurantId.toString(),
        'rating': rating.toString(),
      },
    );

    final data = json.decode(response.body);
    print(data);
  }

  Future<void> fetchShops(int categoryId) async {
    setState(() {
      isLoadingShops = true; // Set loading state
      shops = []; // Clear the previous shops list
    });

    try {
      // Get current position
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      final response = await http.get(Uri.parse(
        '${ApiConstants.baseUrl}get_shops.php?category=$categoryId&user_lat=${position.latitude}&user_lng=${position.longitude}',
      ));


      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}'); // Log the response body
      print("Shops retrieved for Category ID 4: ${shops}");

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) { // Check for success in response
          setState(() {
            shops = List<Map<String, dynamic>>.from(jsonResponse['shops']); // Properly cast the response
          });
        } else {
          print("Error: ${jsonResponse['message']}");
        }
      } else {
        print("Failed to load shops: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching shops: $e");
    } finally {
      setState(() {
        isLoadingShops = false; // Reset loading state
      });
    }
  }

  Future<void> searchItems(String query) async {
    setState(() {
      isSearching = true;
      searchResults = [];
    });

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      print("Searching for items with query: $query");
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}search_items.php?query=$query&user_id=${widget.userId}&user_lat=${position.latitude}&user_lng=${position.longitude}',));
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        print('Response body: $jsonResponse');

        if (jsonResponse['success']) {
          setState(() {
            searchResults = List<Map<String, dynamic>>.from(jsonResponse['items']).map((item) {
              item['images'] = (item['images'] != null && item['images'] is List)
                  ? List<String>.from(item['images'])
                  : [];
              return item;
            }).toList();
          });
        } else {
          print("Error: ${jsonResponse['message']}");
        }
      } else {
        print("Failed to load search results: ${response.statusCode}");
      }
    } catch (e) {
      print("Error searching items: $e");
    } finally {
      setState(() {
        isSearching = false;
      });
    }
  }



  void _showFullScreenImage(String imagePath) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.network(imagePath),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQuantityDialog(BuildContext context, int userId, int itemId) {
    TextEditingController quantityController = TextEditingController(text: "1");

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Quantity'),
          content: TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: "Enter quantity"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog without adding
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (quantityController.text.isNotEmpty &&
                    int.tryParse(quantityController.text) != null) {
                  int quantity = int.parse(quantityController.text);
                  if (quantity > 0) {
                    addToCart(userId, itemId, quantity);
                    Navigator.of(context).pop(); // Close the dialog after adding
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added to Cart')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Quantity must be greater than zero')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a valid quantity')),
                  );
                }
              },
              child: Text('Add to Cart'),
            ),
          ],
        );
      },
    );
  }
  Future<void> addToCart(int userId, int itemId, int quantity) async {
    try {
      print('UserId: $userId, ItemId: $itemId, Quantity: $quantity');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}shop_add_to_cart.php'),
        body: {
          'userId': userId.toString(),
          'itemId': itemId.toString(),
          'quantity': quantity.toString(),
        },
      );

      print('Response: ${response.body}'); // Print the response for debugging

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['success'] == true) {
          print('Item added to cart successfully');
        } else {
          print('Failed to add item to cart: ${responseBody['message']}');
        }
      } else {
        print('Failed to connect to the server');
      }
    } catch (e) {
      print('Error adding item to cart: $e');
    }
  }
  Future<Map<String, dynamic>> fetchShopRating(int shopId) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}get_shop_ratings.php?shop_id=$shopId'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load shop ratings");
    }
  }
  Future<void> submitShopRating(int userId, int shopId, double rating) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}submit_shop_rating.php'),
      body: {
        'user_id': userId.toString(),
        'shop_id': shopId.toString(),
        'rating': rating.toString(),
      },
    );

    if (response.statusCode == 200) {
      print("Rating submitted successfully");
    } else {
      print("Failed to submit rating");
    }
  }


  Widget _buildMarketPage() {
    return Column(
      children: [
        // Search Field
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Search for items',
              suffixIcon: IconButton(
                icon: Icon(Icons.search),
                onPressed: () {},
              ),
            ),
            onChanged: (value) {
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () {
                setState(() {
                  searchQuery = value;
                });
                searchItems(searchQuery);
              });
            },
          ),
        ),
        // Display search results if searching, else categories
        Expanded(
          child: isSearching
              ? Center(child: CircularProgressIndicator())
              : searchResults.isNotEmpty
              ? ListView.builder(
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              List<String> images = searchResults[index]['images'] ?? [];

              return Card(
                margin: EdgeInsets.symmetric(vertical: 5, horizontal: 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full-width auto-sliding image slider
                    if (images.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CarouselSlider(
                        options: CarouselOptions(
                          height: 150,
                          autoPlay: true,
                          enlargeCenterPage: true,
                          aspectRatio: 16 / 9,
                          viewportFraction: 0.8,
                          ),
                          items: images.map((imageUrl) {
                            return Image.network(
                              imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.broken_image, color: Colors.white),                            );
                          }).toList(),
                        ),
                      ),

                    // Item details below image
                    Padding(
                      padding: const EdgeInsets.all(12.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            searchResults[index]['name'],
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            searchResults[index]['description'],
                            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Price: ETB ${searchResults[index]['price']}",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Shop: ${searchResults[index]['shop_name']} - ${searchResults[index]['distance']} km away",
                            style: TextStyle(fontSize: 16, color: Colors.blueAccent),
                          ),
                        ],
                      ),
                    ),

                    // Add to cart button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, right: 10),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showQuantityDialog(context, widget.userId, searchResults[index]['id']);
                          },
                          icon: Icon(Icons.add_shopping_cart),
                          label: Text("Add to Cart"),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          )
              : Column(
            children: [
              // Display categories
              Container(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    bool isSelected = categories[index]['id'] == selectedCategoryId;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedCategoryId = categories[index]['id'];
                          isLoadingShops = true;
                        });
                        fetchShops(selectedCategoryId);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blueAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          categories[index]['name'],
                          style: TextStyle(
                            fontSize: 18,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Display shops under selected category with ratings
              Expanded(
                child: isLoadingShops
                    ? Center(child: CircularProgressIndicator())
                    : shops.isEmpty
                    ? Center(child: Text('No shops available in this category. Please try another category.'))
                    : ListView.builder(
                  itemCount: shops.length,
                  itemBuilder: (context, index) {
                    return FutureBuilder<Map<String, dynamic>>(
                      future: fetchShopRating(shops[index]['id']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return ListTile(
                            title: Text(shops[index]['name']),
                            subtitle: Text('Loading rating...'),
                            trailing: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return ListTile(
                            title: Text(shops[index]['name']),
                            subtitle: Text('Error loading rating'),
                            trailing: Icon(Icons.error, color: Colors.red),
                          );
                        }

                        double averageRating = (snapshot.data?['average_rating'] ?? 0.0).toDouble();
                        int totalRatings = snapshot.data?['total_reviews'] ?? 0;

                        return ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  shops[index]['name'],
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              RatingBar.builder(
                                initialRating: averageRating,
                                minRating: 1,
                                direction: Axis.horizontal,
                                allowHalfRating: true,
                                itemCount: 5,
                                itemSize: 20,
                                itemPadding: EdgeInsets.symmetric(horizontal: 2.0),
                                itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
                                onRatingUpdate: (newRating) {
                                  submitShopRating(widget.userId, shops[index]['id'], newRating);
                                },
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Distance: ${shops[index]['distance']} km\n${shops[index]['description']}'),
                              SizedBox(height: 5),
                              Text('⭐ ${averageRating.toStringAsFixed(1)} ($totalRatings reviews)'),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ShopItemsScreen(
                                  shopId: shops[index]['id'],
                                  userId: widget.userId,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

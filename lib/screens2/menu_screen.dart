import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:dw_app/constants/api_constants.dart';
import 'cart_provider.dart';
import 'cart_screen.dart';
import 'current_restaurant_provider.dart';

class MenuScreen extends StatefulWidget {
  final int restaurantId;
  final String restaurantName;
  final String restaurantImage;
  final String rating;
  final String deliveryInfo;
  final int userId;

  const MenuScreen({
    Key? key,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantImage,
    required this.userId,
    this.rating = "4.5",
    this.deliveryInfo = "20-30 min • 15 Br delivery",
  }) : super(key: key);

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List menuItems = [];
  bool isLoading = true;
  int _selectedCategoryIndex = 0;
  List<String> categories = ["All", "ERTB", "Pasta"];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final restaurant = Provider.of<CurrentRestaurantProvider>(context, listen: false);
      restaurant.setRestaurant(
        widget.restaurantId.toString(),
        widget.restaurantName,
      );
    });
    fetchMenu();
  }

  Future<void> fetchMenu() async {
    try {
      final response = await http.get(Uri.parse(
          '${ApiConstants.baseUrl}get_menu.php?restaurant_id=${widget.restaurantId}'));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            menuItems = jsonResponse['data'];
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
          Fluttertoast.showToast(msg: "No menu found.");
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(
        msg: "Failed to load menu",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }


  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                widget.restaurantImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.restaurant, size: 50),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.restaurantName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        widget.rating,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        widget.deliveryInfo,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(categories[index]),
                            selected: _selectedCategoryIndex == index,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategoryIndex = index;
                              });
                            },
                            selectedColor: Colors.orange,
                            labelStyle: TextStyle(
                              color: _selectedCategoryIndex == index
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final item = menuItems[index];
                return MenuItemCard(
                  id: item['id'].toString(),
                  name: item['name'],
                  description: item['description'],
                  price: item['price'].toString(),
                  discountPrice: item['discount_price']?.toString(),
                  discountPercent: item['discount_percent']?.toString(),
                  imageUrl: item['image_url'] ?? '',
                  restaurantId: widget.restaurantId.toString(),
                  restaurantName: widget.restaurantName,
                );
              },
              childCount: menuItems.length,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.shopping_cart),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CartScreen(userId: widget.userId),
            ),
          );
        },
      ),
    );
  }
}

class MenuItemCard extends StatelessWidget {
  final String id;
  final String name;
  final String description;
  final String price;
  final String? discountPrice;
  final String? discountPercent;
  final String imageUrl;
  final String restaurantId;
  final String restaurantName;

  const MenuItemCard({
    Key? key,
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.restaurantId,
    required this.restaurantName,
    this.discountPrice,
    this.discountPercent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 100,
                height: 100,
                color: Colors.grey[200],
                child: const Icon(Icons.fastfood),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Food details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (discountPrice != null)
                      Text(
                        "ETB $price",
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    if (discountPrice != null) const SizedBox(width: 8),
                    Text(
                      "ETB ${discountPrice ?? price}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    if (discountPercent != null) const SizedBox(width: 8),
                    if (discountPercent != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "$discountPercent% OFF",
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Add button
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.favorite_border, size: 20),
                onPressed: () {},
              ),
              ElevatedButton(
                onPressed: () {
                  final cart = Provider.of<CartProvider>(context, listen: false);
                  cart.addItem(
                    id,
                    name,
                    double.parse(price),
                    imageUrl,
                    restaurantId,
                    restaurantName,
                  );
                  Fluttertoast.showToast(
                    msg: "$name added to cart",
                    toastLength: Toast.LENGTH_SHORT,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
                child: const Text("Add"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
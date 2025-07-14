import 'package:flutter/material.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;
  final String imageUrl;
  final String restaurantId;
  final String restaurantName;
  bool isUnavailable;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.restaurantId,
    required this.restaurantName,
    this.isUnavailable = false,
  });

  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    String? restaurantId,
    String? restaurantName,
    bool? isUnavailable,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      isUnavailable: isUnavailable ?? this.isUnavailable,
    );
  }
}

class CartProvider with ChangeNotifier {
  List<CartItem> _items = [];

  List<CartItem> get items => [..._items];

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _items.fold(
    0,
        (sum, item) => sum + (item.price * item.quantity),
  );

  void addItem(
      String id,
      String name,
      double price,
      String imageUrl,
      String restaurantId,
      String restaurantName, {
        bool isUnavailable = false,
      }) {
    final existingIndex = _items.indexWhere(
          (item) => item.id == id && item.restaurantId == restaurantId,
    );

    if (existingIndex >= 0) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + 1,
      );
    } else {
      _items.add(
        CartItem(
          id: id,
          name: name,
          price: price,
          quantity: 1,
          imageUrl: imageUrl,
          restaurantId: restaurantId,
          restaurantName: restaurantName,
          isUnavailable: isUnavailable,
        ),
      );
    }
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void removeSingleItem(String id) {
    final existingIndex = _items.indexWhere((item) => item.id == id);
    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity > 1) {
        _items[existingIndex] = _items[existingIndex].copyWith(
          quantity: _items[existingIndex].quantity - 1,
        );
      } else {
        _items.removeAt(existingIndex);
      }
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
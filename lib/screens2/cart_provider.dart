// lib/cart_provider.dart
import 'package:flutter/foundation.dart';

class CartItem {
  final int id;
  final String name;
  final double price;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });
}

class CartProvider extends ChangeNotifier {
  List<CartItem> _cartItems = [];

  List<CartItem> get cartItems => _cartItems;

  void addToCart(CartItem item) {
    final index = _cartItems.indexWhere((element) => element.id == item.id);
    if (index != -1) {
      _cartItems[index].quantity += item.quantity;
    } else {
      _cartItems.add(item);
    }
    notifyListeners();
  }

  void removeFromCart(int id) {
    _cartItems.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  double get totalAmount {
    return _cartItems.fold(0.0, (total, item) => total + item.price * item.quantity);
  }
}

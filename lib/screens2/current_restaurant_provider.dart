import 'package:flutter/material.dart';

class CurrentRestaurantProvider with ChangeNotifier {
  String _id = '';
  String _name = '';

  String get id => _id;
  String get name => _name;

  void setRestaurant(String id, String name) {
    _id = id;
    _name = name;
    notifyListeners();
  }
}
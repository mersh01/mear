import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Restaurant {
  final int id;
  final String name;
  final String? imageUrl;
  final String? description;
  final String? deliveryTime;
  final double? rating;
  final int? totalReviews;
  final double? distance;

  Restaurant({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
    this.deliveryTime,
    this.rating,
    this.totalReviews,
    this.distance,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: int.parse(json['id'].toString()),
      name: json['name'].toString(),
      imageUrl: json['image_url']?.toString(),
      description: json['description']?.toString(),
      deliveryTime: json['delivery_time']?.toString(),
      rating: json['rating']?.toDouble(),
      totalReviews: json['total_reviews'] != null ? int.parse(json['total_reviews'].toString()) : null,
      distance: json['distance']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'image_url': imageUrl,
    'description': description,
    'delivery_time': deliveryTime,
    'rating': rating,
    'total_reviews': totalReviews,
    'distance': distance,
  };
}

// promotion_model.dart
class Promotion {
  final int id;
  final String title;
  final String description;
  final String imageUrl;
  final double price;
  final String restaurant;

  Promotion({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.restaurant,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['image_url'] as String,
      price: (json['price'] as num).toDouble(),
      restaurant: json['restaurant'] as String,
    );
  }
}
class MenuItem {
  final int id;
  final String name;
  final double price;
  final String? imageUrl;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: int.parse(json['id'].toString()),
      name: json['name'].toString(),
      price: json['price']?.toDouble() ?? 0.0,
      imageUrl: json['image_url']?.toString(),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'cart_provider.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  final int userId;

  const CartScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final restaurantGroups = groupBy(cart.items, (item) => item.restaurantId);
    final hasUnavailableItems = cart.items.any((item) => item.isUnavailable);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        backgroundColor: Colors.deepOrange,
        actions: [
          if (cart.itemCount > 0)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                cart.clearCart();
              },
            ),
        ],
      ),
      body: cart.itemCount == 0
          ? const Center(
        child: Text(
          'Your cart is empty',
          style: TextStyle(fontSize: 20, color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: restaurantGroups.length,
        itemBuilder: (ctx, restaurantIndex) {
          final restaurantId = restaurantGroups.keys.elementAt(restaurantIndex);
          final restaurantItems = restaurantGroups[restaurantId]!;
          final firstItem = restaurantItems.first;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  firstItem.restaurantName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
              ),
              ...restaurantItems.map((item) => Dismissible(
                key: ValueKey(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  cart.removeItem(item.id);
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: item.imageUrl.isNotEmpty
                            ? NetworkImage(item.imageUrl)
                            : AssetImage('assets/placeholder.png') as ImageProvider,
                        child: item.imageUrl.isEmpty ? Icon(Icons.fastfood) : null,
                      ),
                      title: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: item.isUnavailable
                              ? Colors.red
                              : Colors.black,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ETB ${item.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          if (item.isUnavailable)
                            const Text(
                              'Currently unavailable',
                              style: TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove),
                            onPressed: () {
                              cart.removeSingleItem(item.id);
                            },
                          ),
                          Text(
                            '${item.quantity}x',
                            style: const TextStyle(fontSize: 18),
                          ),
                          IconButton(
                            icon: Icon(Icons.add),
                            onPressed: () {
                              cart.addItem(
                                item.id,
                                item.name,
                                item.price,
                                item.imageUrl,
                                item.restaurantId,
                                item.restaurantName,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )).toList(),
              Divider(height: 20, thickness: 2),
            ],
          );
        },
      ),
      bottomNavigationBar: cart.itemCount > 0
          ? Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Price:',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ETB ${cart.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: hasUnavailableItems
                  ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Please remove unavailable items before checkout'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutScreen(
                      totalPrice: cart.totalAmount,
                      userId: userId,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment),
                  SizedBox(width: 10),
                  Text(
                    'Proceed to Checkout',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          : null,
    );
  }
}
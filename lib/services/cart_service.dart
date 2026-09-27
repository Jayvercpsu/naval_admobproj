import 'package:flutter/foundation.dart';
import '../models/cart.dart';
import '../models/product.dart';

class CartService extends ChangeNotifier {
  // Private constructor so we can make this service a singleton.
  CartService._internal();

  // Only one CartService instance is shared throughout the app.
  static final CartService _instance = CartService._internal();

  // Whenever CartService() is called, return the same instance.
  factory CartService() {
    return _instance;
  }

  // This is where the products currently in the cart are stored.
  final List<CartProduct> _localCartItems = [];

  // Give other screens access to the cart without letting them modify the list directly.
  List<CartProduct> get localCartItems {
    return List.unmodifiable(_localCartItems);
  }

  // Add a product to the cart.
  void addToCart(Product product) {
    // Check if this product is already in the cart.
    final existingIndex = _localCartItems.indexWhere(
      (item) => item.id == product.id,
    );

    if (existingIndex != -1) {
      // If it already exists, just increase its quantity.
      final item = _localCartItems[existingIndex];
      final newQuantity = item.quantity + 1;

      // Replace the old item with its updated quantity and totals.
      _localCartItems[existingIndex] = CartProduct(
        id: item.id,
        title: item.title,
        description: item.description,
        category: item.category,
        price: item.price,
        quantity: newQuantity,
        total: item.price * newQuantity,
        discountPercentage: item.discountPercentage,
        discountedTotal: _calculateDiscountedTotal(
          item.price,
          newQuantity,
          item.discountPercentage,
        ),
        thumbnail: item.thumbnail,
        brand: item.brand,
      );
    } else {
      // If it is a new product, add it with a quantity of 1.
      _localCartItems.add(
        CartProduct(
          id: product.id,
          title: product.title,
          description: product.description,
          category: product.category,
          price: product.price,
          quantity: 1,
          total: product.price,
          discountPercentage: product.discountPercentage,
          discountedTotal: _calculateDiscountedTotal(
            product.price,
            1,
            product.discountPercentage,
          ),
          thumbnail: product.thumbnail,
          brand: product.brand,
        ),
      );
    }

    // Tell the widgets listening to this service that the cart changed.
    notifyListeners();
  }

  // Increase the quantity of a cart item.
  void incrementQuantity(int index) {
    // Make sure the index actually exists before doing anything.
    if (index < 0 || index >= _localCartItems.length) {
      return;
    }

    final item = _localCartItems[index];
    final newQuantity = item.quantity + 1;

    // Replace the item with its updated quantity and price totals.
    _localCartItems[index] = CartProduct(
      id: item.id,
      title: item.title,
      description: item.description,
      category: item.category,
      price: item.price,
      quantity: newQuantity,
      total: item.price * newQuantity,
      discountPercentage: item.discountPercentage,
      discountedTotal: _calculateDiscountedTotal(
        item.price,
        newQuantity,
        item.discountPercentage,
      ),
      thumbnail: item.thumbnail,
      brand: item.brand,
    );

    // Refresh the screens using the cart.
    notifyListeners();
  }

  // Decrease the quantity of a cart item.
  void decrementQuantity(int index) {
    // Make sure the index actually exists.
    if (index < 0 || index >= _localCartItems.length) {
      return;
    }

    final item = _localCartItems[index];

    // If only one is left, remove the product completely.
    if (item.quantity <= 1) {
      _localCartItems.removeAt(index);
    } else {
      // Otherwise, simply decrease the quantity by one.
      final newQuantity = item.quantity - 1;

      // Replace the item with its updated quantity and totals.
      _localCartItems[index] = CartProduct(
        id: item.id,
        title: item.title,
        description: item.description,
        category: item.category,
        price: item.price,
        quantity: newQuantity,
        total: item.price * newQuantity,
        discountPercentage: item.discountPercentage,
        discountedTotal: _calculateDiscountedTotal(
          item.price,
          newQuantity,
          item.discountPercentage,
        ),
        thumbnail: item.thumbnail,
        brand: item.brand,
      );
    }

    // Update anything listening to the cart.
    notifyListeners();
  }

  // Remove a specific product from the cart completely.
  void removeFromCart(int index) {
    // Check that the index is valid first.
    if (index < 0 || index >= _localCartItems.length) {
      return;
    }

    _localCartItems.removeAt(index);

    // Let the UI know the cart changed.
    notifyListeners();
  }

  // Empty the entire cart.
  void clearCart() {
    _localCartItems.clear();

    // Refresh the UI after clearing everything.
    notifyListeners();
  }

  // Calculate the total price of all products in the cart.
  double get subtotal {
    double total = 0;

    // Add each product's price multiplied by its quantity.
    for (final item in _localCartItems) {
      total += item.price * item.quantity;
    }

    return total;
  }

  // Calculate the total number of individual items in the cart.
  int get totalQuantity {
    int total = 0;

    // Add the quantity of every product.
    for (final item in _localCartItems) {
      total += item.quantity;
    }

    return total;
  }

  // Check if a specific product is already in the cart.
  bool isInCart(int productId) {
    return _localCartItems.any(
      (item) => item.id == productId,
    );
  }

  // Get the current quantity of a specific product.
  int getQuantity(int productId) {
    final index = _localCartItems.indexWhere(
      (item) => item.id == productId,
    );

    // Return 0 if the product isn't in the cart.
    if (index == -1) {
      return 0;
    }

    return _localCartItems[index].quantity;
  }

  // Calculate the price after applying the product's discount.
  double _calculateDiscountedTotal(
    double price,
    int quantity,
    double discountPercentage,
  ) {
    // First get the original total before the discount.
    final originalTotal = price * quantity;

    // Calculate how much money the discount takes off.
    final discount = originalTotal * (discountPercentage / 100);

    // Return the final price after the discount.
    return originalTotal - discount;
  }
}
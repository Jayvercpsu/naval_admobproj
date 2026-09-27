import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import 'detail_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
  });

  @override
  State<CartScreen> createState() => CartScreenState();
}

class CartScreenState extends State<CartScreen>
    with AutomaticKeepAliveClientMixin<CartScreen> {
  // This handles the cart data and all the cart actions.
  final CartService _cartService = CartService();

  // Keeps the cart screen alive when switching between screens/tabs.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // Required when using AutomaticKeepAliveClientMixin.
    super.build(context);

    // Rebuilds the screen whenever the cart service changes.
    return AnimatedBuilder(
      animation: _cartService,
      builder: (context, child) {
        // Get the products currently stored in the cart.
        final cartItems = _cartService.localCartItems;

        // Show this when there are no products in the cart.
        if (cartItems.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 70,
                  color: Colors.grey,
                ),
                SizedBox(height: 15),
                Text(
                  'Your cart is empty.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        // If the cart has products, show the list and order section.
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: cartItems.length,
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 8.h,
                ),
                itemBuilder: (context, index) {
                  // Get the current product from the cart.
                  final item = cartItems[index];

                  return Card(
                    margin: EdgeInsets.only(
                      bottom: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),

                      // Tapping a cart item opens its product details.
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              return DetailScreen(
                                product: Product(
                                  id: item.id,
                                  title: item.title,
                                  description: item.description,
                                  category: item.category,
                                  price: item.price,
                                  discountPercentage:
                                      item.discountPercentage,
                                  rating: 5.0,
                                  stock: 10,
                                  tags: const [],
                                  brand: item.brand,
                                  thumbnail: item.thumbnail,
                                  images: [item.thumbnail],
                                ),
                              );
                            },
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.all(12.w),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Product image shown on the left.
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: Image.network(
                                item.thumbnail,
                                width: 55.w,
                                height: 55.h,
                                fit: BoxFit.cover,

                                // Show a simple icon if the image fails to load.
                                errorBuilder:
                                    (context, error, stackTrace) {
                                  return Container(
                                    width: 55.w,
                                    height: 55.h,
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.shopping_bag,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),

                            SizedBox(width: 12.w),

                            // Product information goes in the middle.
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  SizedBox(height: 4.h),

                                  // Original price of the product.
                                  Text(
                                    '₱${item.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12.sp,
                                    ),
                                  ),

                                  SizedBox(height: 2.h),

                                  // Shows how much discount the product has.
                                  Text(
                                    '${item.discountPercentage}% off',
                                    style: TextStyle(
                                      color: Colors.amber.shade700,
                                      fontSize: 11.sp,
                                    ),
                                  ),

                                  SizedBox(height: 2.h),

                                  // Shows the total price for the current quantity.
                                  Text(
                                    'Total: ₱${item.total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(width: 8.w),

                            // These buttons control the product quantity.
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Minus button decreases the quantity.
                                InkWell(
                                  onTap: () {
                                    _cartService.decrementQuantity(index);
                                  },
                                  child: Container(
                                    width: 28.w,
                                    height: 28.h,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      size: 16,
                                    ),
                                  ),
                                ),

                                // Displays the current quantity.
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                  ),
                                  child: Text(
                                    '${item.quantity}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ),

                                // Plus button increases the quantity.
                                InkWell(
                                  onTap: () {
                                    _cartService.incrementQuantity(index);
                                  },
                                  child: Container(
                                    width: 28.w,
                                    height: 28.h,
                                    decoration: const BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom section showing the subtotal and order button.
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Displays the current cart subtotal.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal:',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '₱${_cartService.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12.h),

                  // Confirm Order button.
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(
                          vertical: 12.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      onPressed: () {
                        // Don't do anything if the cart is empty.
                        if (_cartService.localCartItems.isEmpty) {
                          return;
                        }

                        // Get the current cart total before confirming.
                        final total = _cartService.subtotal;

                        // Show a confirmation dialog after ordering.
                        showDialog(
                          context: context,
                          builder: (dialogContext) {
                            return AlertDialog(
                              title: const Text(
                                'Order Confirmed',
                              ),
                              content: Text(
                                'Total: ₱${total.toStringAsFixed(2)}',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    // Close the dialog and clear the cart.
                                    Navigator.pop(dialogContext);
                                    _cartService.clearCart();
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Text(
                        'Confirm Order',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
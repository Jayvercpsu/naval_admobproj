import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/product.dart';
import '../services/cart_service.dart';

class DetailScreen extends StatefulWidget {
  // This holds the product that was selected.
  final Product product;

  const DetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  // This handles adding and managing products in the cart.
  final CartService _cartService = CartService();

  @override
  Widget build(BuildContext context) {
    // Get the product passed from the previous screen.
    final product = widget.product;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
      ),

      // Makes the whole product page scrollable.
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image at the top of the page.
            SizedBox(
              width: double.infinity,
              height: 300.h,
              child: Image.network(
                product.thumbnail,
                fit: BoxFit.contain,

                // Show an icon if the product image can't be loaded.
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 80,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),

            // Product information goes below the image.
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name.
                  Text(
                    product.title,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  // Product price.
                  Text(
                    '₱${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  // Shows the product's discount.
                  Text(
                    '${product.discountPercentage}% OFF',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Description title.
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  // Actual product description.
                  Text(
                    product.description,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade700,
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Shows the product rating.
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        product.rating.toString(),
                      ),
                    ],
                  ),

                  SizedBox(height: 30.h),

                  // Rebuilds this section whenever the cart changes.
                  AnimatedBuilder(
                    animation: _cartService,
                    builder: (context, child) {
                      // Check how many of this product are already in the cart.
                      final quantity =
                          _cartService.getQuantity(product.id);

                      // If quantity is greater than zero, the product is already in the cart.
                      final isInCart = quantity > 0;

                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(
                              vertical: 15.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10.r),
                            ),
                          ),

                          // Add the product to the cart when pressed.
                          onPressed: () {
                            _cartService.addToCart(product);

                            // Remove any previous cart message first.
                            ScaffoldMessenger.of(context)
                                .hideCurrentSnackBar();

                            // Show a quick message confirming the product was added.
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Added ${product.title} to cart! Total in cart: ${_cartService.getQuantity(product.id)}',
                                ),
                                duration:
                                    const Duration(seconds: 1),
                              ),
                            );
                          },

                          // Change the button text depending on whether
                          // the product is already in the cart.
                          child: Text(
                            isInCart
                                ? 'Add More ($quantity in cart)'
                                : 'Add to Cart',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 15.h),

                  // Button to return to the previous screen.
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Back'),
                    ),
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
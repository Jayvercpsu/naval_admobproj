import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../services/cart_service.dart';
import '../widgets/custom_text.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ProductService _productService = ProductService();

  final ScrollController _scrollController = ScrollController();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMoreProducts = true;
  String _errorMessage = '';

  int _skip = 0;
  final int _limit = 10;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchInitialProducts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMoreProducts &&
          _currentQuery.isEmpty) {
        _fetchMoreProducts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _fetchInitialProducts() async {
    try {
      final products = await _productService.getAllProducts();

      setState(() {
        _allProducts = products;
        _filteredProducts = products;
        _isLoadingInitial = false;
        _skip = products.length;

        if (products.length < _limit) {
          _hasMoreProducts = false;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingInitial = false;
      });
    }
  }

  void _fetchMoreProducts() async {
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newProducts = await _productService.getAllProducts();

      setState(() {
        if (newProducts.isEmpty) {
          _hasMoreProducts = false;
        } else {
          _allProducts.addAll(newProducts);
          _filteredProducts = _allProducts;
          _skip += newProducts.length;
        }

        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _currentQuery = query;

      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((product) {
          return product.title.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
              product.category.toLowerCase().contains(
                    query.toLowerCase(),
                  );
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInitial) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: CustomText(
          text: _errorMessage,
          fontSize: 16.sp,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12.w,
        vertical: 8.h,
      ),
      child: Column(
        children: [
          TextField(
            onChanged: _filterProducts,
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: EdgeInsets.symmetric(
                vertical: 12.h,
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(
                    child: Text('No products found.'),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        _filteredProducts.length +
                            (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _filteredProducts.length) {
                        return Padding(
                          padding: EdgeInsets.all(16.h),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final product = _filteredProducts[index];

                      return Container(
                        margin: EdgeInsets.only(
                          bottom: 12.h,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16.r),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) {
                                  return ProductDetailScreen(
                                    product: product,
                                  );
                                },
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(12.w),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(12.r),
                                  child: Image.network(
                                    product.thumbnail,
                                    width: 80.w,
                                    height: 80.h,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) {
                                      return Container(
                                        width: 80.w,
                                        height: 80.h,
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.shopping_bag,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.category.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          color: Colors.indigo,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      CustomText(
                                        text: product.title,
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 14.sp,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 6.h),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        children: [
                                          CustomText(
                                            text:
                                                '₱${product.price.toStringAsFixed(2)}',
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 15.sp,
                                            color:
                                                Colors.green[700],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState
    extends State<ProductDetailScreen> {
  final CartService _cartService = CartService();

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 8.h,
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.black87,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  CustomText(
                    text: 'Product Details',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.favorite_border,
                      color: Colors.black87,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Image.network(
                    product.thumbnail,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (context, error, stackTrace) {
                      return Icon(
                        Icons.shopping_bag,
                        size: 100.sp,
                        color: Colors.indigo,
                      );
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30.r),
                    topRight: Radius.circular(30.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 24.h,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 6.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.indigo
                                      .withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(8.r),
                                ),
                                child: CustomText(
                                  text: product.category
                                      .toUpperCase(),
                                  fontSize: 11.sp,
                                  fontWeight:
                                      FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              CustomText(
                                text: product.title,
                                fontSize: 20.sp,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                              SizedBox(height: 12.h),
                              CustomText(
                                text:
                                    '₱${product.price.toStringAsFixed(2)}',
                                fontSize: 22.sp,
                                fontWeight:
                                    FontWeight.bold,
                                color: Colors.green[700],
                              ),
                              SizedBox(height: 20.h),
                              CustomText(
                                text: 'Description',
                                fontSize: 16.sp,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                              SizedBox(height: 6.h),
                              CustomText(
                                text: product.description,
                                fontSize: 13.sp,
                                color: Colors.grey[700],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12.r),
                            ),
                          ),
                          onPressed: () {
                            _cartService.addToCart(product);

                            final quantity =
                                _cartService.getQuantity(
                              product.id,
                            );

                            ScaffoldMessenger.of(context)
                                .hideCurrentSnackBar();

                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${product.title} added to cart. Quantity: $quantity',
                                ),
                                duration:
                                    const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: CustomText(
                            text: 'Add to Cart',
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
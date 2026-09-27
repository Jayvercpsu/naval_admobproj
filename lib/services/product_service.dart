import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/product.dart';

// The network service layer — handles fetching and parsing product data from the backend API
class ProductService {
  // It fetches the full list of products asynchronously from the server endpoint
  Future<List<Product>> getAllProducts() async {
    final response = await http.get(Uri.parse('$host/products'));

    if (response.statusCode == 200) {
      // It decodes the JSON response body into a Dart map structure
      final Map<String, dynamic> data = jsonDecode(response.body);
      
      // It extracts the 'products' array from the payload safely
      final List productsJson = data['products'] ?? [];
      
      // It maps every JSON product object into a strongly-typed Product model instance
      return productsJson.map((json) => Product.fromJson(json)).toList();
    } else {
      // It throws an exception if the server returns any status other than HTTP 200 OK
      throw Exception('Failed to load products');
    }
  }
}
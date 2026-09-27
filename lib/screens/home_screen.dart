import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/user.dart';
import '../widgets/custom_text.dart';
import 'cart_screen.dart';
import 'product_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, this.username = ''});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final GlobalKey<CartScreenState> cartKey = GlobalKey<CartScreenState>();

  // Enhancement 3: filled in once ProfileScreen loads the saved user, so
  // the app bar can greet them by name while on the Profile tab.
  User? _currentUser;

  void _onTappedBar(int value) {
    setState(() {
      _selectedIndex = value;
    });
    _pageController.jumpToPage(value);
  }

  @override
  Widget build(BuildContext context) {
    // Enhancement 2: Check if current tab is CartScreen
    final bool isCartScreen = _selectedIndex == 1;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 2,
          title: (_selectedIndex == 0)
              ? Image.asset(
                  'assets/images/A_logo.png',
                  scale: 11.sp,
                )
              : CustomText(
                  text: (_selectedIndex == 1)
                      ? 'Cart'
                      : (_selectedIndex == 2)
                          ? (_currentUser?.firstName.isNotEmpty == true
                              ? _currentUser!.firstName
                              : 'Profile')
                          : 'Home',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings, size: 24.sp),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: _pageController,
          onPageChanged: (page) {
            setState(() {
              _selectedIndex = page;
            });
          },
          children: <Widget>[
            const ProductScreen(),
            // Enhancement 1: Render new CartScreen without redundant appbar
            CartScreen(key: cartKey),
            // Enhancement 3: Render the profile UI backed by user.dart
            ProfileScreen(
              onUserLoaded: (user) {
                setState(() {
                  _currentUser = user;
                });
              },
            ),
          ],
        ),
        // Enhancement 2: Chat bottom navigation transformed as FloatingActionButton
        // Enhancement 2: Hidden when on CartScreen
        floatingActionButton: isCartScreen
            ? null
            : FloatingActionButton(
                backgroundColor: Colors.indigo,
                onPressed: () {
                  // Lab Activity 6: FAB now opens the Chat List UI
                  Navigator.pushNamed(context, '/chat');
                },
                child: const Icon(Icons.chat, color: Colors.white),
              ),
        bottomNavigationBar: BottomNavigationBar(
          showSelectedLabels: false,
          showUnselectedLabels: false,
          currentIndex: _selectedIndex,
          onTap: _onTappedBar,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.shop_2),
              label: 'Shop',
            ),
            // Enhancement 1: Replaced Chat tab with Cart tab
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
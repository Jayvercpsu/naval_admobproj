import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Show splash screen logo
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // replacement to the sign-in screen
    Navigator.of(context).pushReplacementNamed('/sign');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/A_logo.png',
              width: 120.w,
              height: 120.w,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.storefront,
                  size: 90.sp,
                  color: Colors.indigo,
                );
              },
            ),

            SizedBox(height: 16.h),

            Text(
              'Anne Mariel',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade900,
              ),
            ),

            SizedBox(height: 40.h),

            SizedBox(
              width: 26.w,
              height: 26.w,
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.indigo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
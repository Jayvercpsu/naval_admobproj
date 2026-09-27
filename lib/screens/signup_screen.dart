import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/user_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController =
      TextEditingController();

  final TextEditingController _lastNameController =
      TextEditingController();

  final TextEditingController _ageController =
      TextEditingController();

  final TextEditingController _contactController =
      TextEditingController();

  final TextEditingController _usernameController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final UserService _userService = UserService();

  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  String _loginType = 'User';

  static const Color _primaryColor = Colors.indigo;
  static const Color _buttonColor = Colors.indigo;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _contactController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Start creating the account
  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Always create the account through Firebase Auth
      await _userService.createAccountFirebase(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        contactNo: _contactController.text.trim(),
        username: _usernameController.text.trim(),
        emailAddress: _emailController.text.trim(),
        password: _passwordController.text,
        loginType: _loginType,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Account Created'),
            content: const Text(
              'The account was created successfully. You can now log in using the same username and password.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      // Send the user back to Sign In
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/sign',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      String message = e.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Basic required-field check
  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    return null;
  }

  // Keep names simple and clean
  String? _nameValidator(String? value) {
    final required = _required(value);

    if (required != null) {
      return required;
    }

    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value!.trim())) {
      return 'Please enter letters only';
    }

    return null;
  }

  // Make sure the age makes sense
  String? _ageValidator(String? value) {
    final required = _required(value);

    if (required != null) {
      return required;
    }

    final age = int.tryParse(value!.trim());

    if (age == null) {
      return 'Please enter a valid age';
    }

    if (age < 1 || age > 120) {
      return 'Please enter a valid age';
    }

    return null;
  }

  // Check the contact number
  String? _contactValidator(String? value) {
    final required = _required(value);

    if (required != null) {
      return required;
    }

    if (!RegExp(r'^[0-9+\-\s]{7,20}$')
        .hasMatch(value!.trim())) {
      return 'Please enter a valid contact number';
    }

    return null;
  }

  // Username needs a simple format
  String? _usernameValidator(String? value) {
    final required = _required(value);

    if (required != null) {
      return required;
    }

    if (!RegExp(r'^[a-zA-Z0-9_.]{3,30}$')
        .hasMatch(value!.trim())) {
      return 'Use 3-30 letters or numbers';
    }

    return null;
  }

  // Check the email format
  String? _emailValidator(String? value) {
    final required = _required(value);

    if (required != null) {
      return required;
    }

    if (!RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(value!.trim())) {
      return 'Please enter a valid email';
    }

    return null;
  }

  // Keep passwords long enough
  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  // Make sure both passwords match
  String? _confirmPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  // Keep all text fields looking alike
  InputDecoration _inputDecoration(
    String label,
  ) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(
          color: _primaryColor,
          width: 1.5,
        ),
      ),
    );
  }

  // Reuse the same field setup
  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: _inputDecoration(label).copyWith(
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              24.w,
              10.h,
              24.w,
              30.h,
            ),
            children: [
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 16.h),

              _textField(
                controller: _firstNameController,
                label: 'First Name',
                validator: _nameValidator,
                keyboardType: TextInputType.name,
              ),

              SizedBox(height: 14.h),

              _textField(
                controller: _lastNameController,
                label: 'Last Name',
                validator: _nameValidator,
                keyboardType: TextInputType.name,
              ),

              SizedBox(height: 14.h),

              _textField(
                controller: _ageController,
                label: 'Age',
                validator: _ageValidator,
                keyboardType: TextInputType.number,
              ),

              SizedBox(height: 14.h),

              _textField(
                controller: _contactController,
                label: 'Contact Number',
                validator: _contactValidator,
                keyboardType: TextInputType.phone,
              ),

              SizedBox(height: 26.h),

              Text(
                'Account Information',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 16.h),

              _textField(
                controller: _usernameController,
                label: 'Username',
                validator: _usernameValidator,
                keyboardType: TextInputType.text,
              ),

              SizedBox(height: 14.h),

              _textField(
                controller: _emailController,
                label: 'Email Address',
                validator: _emailValidator,
                keyboardType: TextInputType.emailAddress,
              ),

              SizedBox(height: 14.h),

              _textField(
                controller: _passwordController,
                label: 'Password',
                validator: _passwordValidator,
                obscureText: !_showPassword,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),

              SizedBox(height: 14.h),

              _textField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                validator: _confirmPasswordValidator,
                obscureText: !_showConfirmPassword,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _showConfirmPassword =
                          !_showConfirmPassword;
                    });
                  },
                  icon: Icon(
                    _showConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),

              SizedBox(height: 18.h),

              DropdownButtonFormField<String>(
                value: _loginType,
                decoration: _inputDecoration(
                  'Login Type',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'User',
                    child: Text('User'),
                  ),
                  DropdownMenuItem(
                    value: 'Student',
                    child: Text('Student'),
                  ),
                  DropdownMenuItem(
                    value: 'Teacher',
                    child: Text('Teacher'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _loginType = value;
                  });
                },
              ),

              SizedBox(height: 28.h),

              SizedBox(
                height: 48.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _buttonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10.r),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : _createAccount,
                  child: _isLoading
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child:
                              const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              SizedBox(height: 10.h),

              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.pop(context);
                      },
                child: const Text(
                  'Already have an account? Log In',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

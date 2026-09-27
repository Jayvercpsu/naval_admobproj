import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/user.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';

class ProfileScreen extends StatefulWidget {
  final ValueChanged<User?>? onUserLoaded;

  const ProfileScreen({
    super.key,
    this.onUserLoaded,
  });

  @override
  State<ProfileScreen> createState() =>
      ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();

  User? _user;
  bool _isLoadingUser = true;
  bool _isBusy = false;
  String? _customImageUrl;

  @override
  void initState() {
    super.initState();

    // Load the account as screen opens
    _loadProfile();
  }

  // Pull the saved account information
  Future<void> _loadProfile() async {
    final user = await _userService.getUserData();

    if (!mounted) return;

    setState(() {
      _user = user;
      _isLoadingUser = false;
    });

    widget.onUserLoaded?.call(user);
  }

  // Ask for a new profile image
  Future<void> _editImageUrl() async {
    final TextEditingController urlController =
        TextEditingController(
      text: _customImageUrl ?? _user?.image ?? '',
    );

    final newUrl = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Update Profile Image',
          ),
          content: TextField(
            controller: urlController,
            decoration: const InputDecoration(
              hintText: 'Enter Image URL',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  urlController.text,
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newUrl != null && mounted) {
      setState(() {
        _customImageUrl = newUrl.trim();
      });
    }
  }

  // Ask for the current password
  Future<String?> _askForPassword() async {
    final controller = TextEditingController();

    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Confirm Password',
          ),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current Password',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  controller.text,
                );
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return password;
  }

  // Let the user change their username
  Future<void> _updateUsername() async {
    if (_user == null) return;

    final controller = TextEditingController(
      text: _user!.username,
    );

    final newUsername = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Update Username',
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'New Username',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  controller.text.trim(),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newUsername == null ||
        newUsername.isEmpty ||
        newUsername == _user!.username) {
      return;
    }

    final password = await _askForPassword();

    if (password == null || password.isEmpty) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      final updatedUser =
          await _userService.updateUsername(
        newUsername,
        currentPassword: password,
      );

      if (!mounted) return;

      setState(() {
        _user = updatedUser;
      });

      _showMessage('Username updated.');
    } catch (e) {
      if (mounted) {
        _showError(e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  // Handle password changes from here
  Future<void> _changePassword() async {
    final currentPassword =
        await _askForPassword();

    if (currentPassword == null ||
        currentPassword.isEmpty) {
      return;
    }

    final newPasswordController =
        TextEditingController();

    final confirmPasswordController =
        TextEditingController();

    final passwords = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Change Password',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  [
                    newPasswordController.text,
                    confirmPasswordController.text,
                  ],
                );
              },
              child: const Text('Change'),
            ),
          ],
        );
      },
    );

    newPasswordController.dispose();
    confirmPasswordController.dispose();

    if (passwords == null) {
      return;
    }

    final newPassword = passwords[0];
    final confirmPassword = passwords[1];

    if (newPassword.length < 6) {
      _showError(
        'Password must be at least 6 characters.',
      );
      return;
    }

    if (newPassword != confirmPassword) {
      _showError(
        'Passwords do not match.',
      );
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await _userService
          .resetPasswordFromCurrentPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!mounted) return;

      _showMessage('Password changed.');
    } catch (e) {
      if (mounted) {
        _showError(e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  // Confirm before deleting everything
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Account',
          ),
          content: const Text(
            'Are you sure you want to delete this account?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final password = await _askForPassword();

    if (password == null || password.isEmpty) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await _userService.deleteAccount(
        password: password,
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/sign',
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        _showError(e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  // Finish the current login session
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text(
            'Are you sure you want to log out?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _userService.logout();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/sign',
      (route) => false,
    );
  }

  // Show a quick success message
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // Show an error without crashing
  void _showError(Object error) {
    String message = error.toString();

    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_user == null) {
      return Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Text(
              'No user session found.',
            ),
            SizedBox(height: 12.h),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/sign',
                  (route) => false,
                );
              },
              child: const Text(
                'Go to Sign In',
              ),
            ),
          ],
        ),
      );
    }

    final user = _user!;
    final fullName =
        '${user.firstName} ${user.lastName}'.trim();

    final activeImageUrl =
        _customImageUrl ?? user.image;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadProfile,
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: 12.h,
            ),
            children: [
              SizedBox(height: 10.h),

              // Main profile area starts here
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: 24.h,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius:
                      BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(0.04),
                      blurRadius: 8,
                      offset:
                          const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment:
                          Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 42.r,
                          backgroundColor:
                              Colors.teal.shade50,
                          backgroundImage:
                              activeImageUrl.isNotEmpty
                                  ? NetworkImage(
                                      activeImageUrl,
                                    )
                                  : null,
                          child:
                              activeImageUrl.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: 42.sp,
                                      color:
                                          Colors.teal,
                                    )
                                  : null,
                        ),
                        GestureDetector(
                          onTap: _editImageUrl,
                          child: CircleAvatar(
                            radius: 14.r,
                            backgroundColor:
                                Colors.amber.shade700,
                            child: Icon(
                              Icons.edit,
                              size: 14.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12.h),

                    CustomText(
                      text: fullName.isNotEmpty
                          ? fullName
                          : 'Naval User',
                      fontSize: 18.sp,
                      fontWeight:
                          FontWeight.bold,
                    ),

                    SizedBox(height: 2.h),

                    CustomText(
                      text: '@${user.username}',
                      fontSize: 12.sp,
                      color:
                          Colors.amber.shade800,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 14.h),

              // All saved account details
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .cardColor,
                  borderRadius:
                      BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(0.04),
                      blurRadius: 8,
                      offset:
                          const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _infoRow(
                      icon: Icons.person_outline,
                      label: 'First Name',
                      value: user.firstName,
                    ),
                    const Divider(height: 1),
                    _infoRow(
                      icon: Icons.person_outline,
                      label: 'Last Name',
                      value: user.lastName,
                    ),
                    const Divider(height: 1),
                    _infoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: user.email,
                    ),
                    const Divider(height: 1),
                    _infoRow(
                      icon: Icons.cake_outlined,
                      label: 'Age',
                      value: user.age > 0
                          ? '${user.age}'
                          : '-',
                    ),
                    const Divider(height: 1),
                    _infoRow(
                      icon: Icons.phone_outlined,
                      label: 'Contact No',
                      value:
                          user.contactNo.isNotEmpty
                              ? user.contactNo
                              : '-',
                    ),
                    const Divider(height: 1),
                    _infoRow(
                      icon: Icons.badge_outlined,
                      label: 'Login Type',
                      value: user.loginType,
                    ),
                    const Divider(height: 1),
                    _infoRow(
                      icon: Icons.wc_outlined,
                      label: 'Gender',
                      value: user.gender.isNotEmpty
                          ? user.gender[0]
                                  .toUpperCase() +
                              user.gender.substring(1)
                          : '-',
                    ),
                    const Divider(height: 1),
                    _infoRow(
                      icon: Icons.numbers_outlined,
                      label: 'User ID',
                      value: '#${user.id}',
                    ),
                    const Divider(height: 1),
                    _infoRow(
                      icon: user.isFirebase
                          ? Icons.local_fire_department_outlined
                          : Icons.cloud_outlined,
                      label: 'Signed in via',
                      value: user.isFirebase
                          ? 'Firebase'
                          : 'DummyJSON',
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // Account actions are kept together
              SizedBox(
                height: 46.h,
                child: ElevatedButton(
                  onPressed: _isBusy
                      ? null
                      : _updateUsername,
                  child: const Text(
                    'Update Username',
                  ),
                ),
              ),

              SizedBox(height: 10.h),

              SizedBox(
                height: 46.h,
                child: ElevatedButton(
                  onPressed: _isBusy
                      ? null
                      : _changePassword,
                  child: const Text(
                    'Change Password',
                  ),
                ),
              ),

              SizedBox(height: 10.h),

              SizedBox(
                height: 46.h,
                child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.red.shade700,
                    foregroundColor:
                        Colors.white,
                  ),
                  onPressed: _isBusy
                      ? null
                      : _deleteAccount,
                  child: const Text(
                    'Delete Account',
                  ),
                ),
              ),

              SizedBox(height: 20.h),

              SizedBox(
                height: 46.h,
                child: ElevatedButton.icon(
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFFF5C4D),
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        10.r,
                      ),
                    ),
                  ),
                  onPressed: _isBusy
                      ? null
                      : _handleLogout,
                  icon: const Icon(
                    Icons.logout,
                    size: 18,
                  ),
                  label: Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),

        // Small blocker while an account action runs
        if (_isBusy)
          Container(
            color: Colors.black.withOpacity(0.08),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  // One reusable row for profile details
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 14.w,
        vertical: 12.h,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20.sp,
            color: Colors.amber.shade700,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
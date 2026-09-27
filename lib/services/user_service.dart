import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Aliased so it doesn't collide with our own local `User` model.
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import '../models/user.dart';

class UserService {
  // Local keys used by the login system
  static const String _sessionKey = 'naval_user_session';
  static const String _passwordKey = 'naval_session_password';
  static const String _localAccountsKey = 'naval_local_accounts';

  // Firebase Auth instance (Lab Activity 5 enhancement)
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;

  // Firestore instance (Lab Activity 6 enhancement - chat needs a
  // "Users" collection listing every registered account)
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Put the API address together here
  Uri _uri(String path) {
    return Uri.parse('$host$path');
  }

  // Basic headers for every request
  Map<String, String> _headers({String? accessToken}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  // Read an API response without crashing
  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'message': 'Unexpected server response.',
      };
    } catch (_) {
      return {
        'message': response.body.isNotEmpty
            ? response.body
            : 'Request failed.',
      };
    }
  }

  // Login through DummyJSON first
  Future<User> signIn(
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        _uri('/auth/login'),
        headers: _headers(),
        body: jsonEncode({
          'username': username.trim(),
          'password': password,
        }),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['id'] != null) {
        final user = User.fromJson(data);

        await _saveSession(
          user,
          password: password,
        );

        return user;
      }

      // Try locally-created accounts if API login fails
      final localUser = await _findLocalAccount(username);

      if (localUser != null) {
        final savedPassword =
            await _getLocalPassword(username);

        if (savedPassword == password) {
          await _saveSession(
            localUser,
            password: password,
          );

          return localUser;
        }
      }

      throw Exception(
        data['message']?.toString() ??
            'Invalid username or password.',
      );
    } catch (e) {
      // Local signup accounts can still login offline
      final localUser = await _findLocalAccount(username);

      if (localUser != null) {
        final savedPassword =
            await _getLocalPassword(username);

        if (savedPassword == password) {
          await _saveSession(
            localUser,
            password: password,
          );

          return localUser;
        }
      }

      if (e is Exception) {
        rethrow;
      }

      throw Exception('Login failed.');
    }
  }

  // Keep login available under the old method name
  Future<User> login(
    String username,
    String password,
  ) async {
    return signIn(username, password);
  }

  // Create and save a new account
  Future<User> createAccount({
    required String firstName,
    required String lastName,
    required int age,
    required String contactNo,
    required String username,
    required String emailAddress,
    required String password,
    required String loginType,
  }) async {
    User? apiUser;

    try {
      final response = await http.post(
        _uri('/users/add'),
        headers: _headers(),
        body: jsonEncode({
          'firstName': firstName,
          'lastName': lastName,
          'age': age,
          'phone': contactNo,
          'username': username,
          'email': emailAddress,
          'password': password,
        }),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['id'] != null) {
        apiUser = User.fromJson(data);
      }
    } catch (_) {
      // Local saving still keeps signup usable
    }

    final user = User(
      id: apiUser?.id ??
          DateTime.now().millisecondsSinceEpoch,
      username: username,
      email: emailAddress,
      firstName: firstName,
      lastName: lastName,
      gender: apiUser?.gender ?? '',
      image: apiUser?.image ?? '',
      age: age,
      contactNo: contactNo,
      loginType: loginType,
      accessToken: apiUser?.accessToken,
      refreshToken: apiUser?.refreshToken,
      authProvider: 'dummyjson',
    );

    // DummyJSON creation is simulated, so save locally
    await _saveLocalAccount(
      user,
      password,
    );

    await _saveSession(
      user,
      password: password,
    );

    return user;
  }

  // ---------------------------------------------------------------------
  // Firebase Authentication (Lab Activity 5 enhancement)
  // ---------------------------------------------------------------------

  // Login using Firebase Auth (email + password)
  Future<User> signInFirebase(
    String email,
    String password,
  ) async {
    try {
      final credential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final fbUser = credential.user;

      if (fbUser == null) {
        throw Exception('Firebase sign in failed.');
      }

      // Merge with any profile details saved locally for this
      // account (firstName, lastName, age, contactNo, etc.)
      final existing = await _findLocalAccount(fbUser.uid);
      final displayParts =
          (fbUser.displayName ?? '').split(' ');

      final user = (existing ?? User(
        id: fbUser.uid.hashCode,
        username: fbUser.email ?? fbUser.uid,
        email: fbUser.email ?? '',
        firstName: displayParts.isNotEmpty
            ? displayParts.first
            : '',
        lastName: displayParts.length > 1
            ? displayParts.sublist(1).join(' ')
            : '',
        gender: '',
        image: fbUser.photoURL ?? '',
      ))
          .copyWith(
        email: fbUser.email ?? existing?.email,
        firebaseUid: fbUser.uid,
        authProvider: 'firebase',
      );

      await _saveSession(user, password: password);
      await _saveLocalAccount(user, password, key: fbUser.uid);

      // Lab Activity 6: keep the "Users" doc in sync in case this
      // account was created before the chat feature was added.
      await _saveUserProfileToFirestore(user);

      return user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e));
    }
  }

  // Create an account using Firebase Auth (email + password)
  Future<User> createAccountFirebase({
    required String firstName,
    required String lastName,
    required int age,
    required String contactNo,
    required String username,
    required String emailAddress,
    required String password,
    required String loginType,
  }) async {
    try {
      final credential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: emailAddress.trim(),
        password: password,
      );

      final fbUser = credential.user;

      if (fbUser == null) {
        throw Exception('Firebase account creation failed.');
      }

      // Keep the display name in sync with Firebase itself
      await fbUser.updateDisplayName(
        '$firstName $lastName'.trim(),
      );
      await fbUser.reload();

      final user = User(
        id: fbUser.uid.hashCode,
        username: username,
        email: emailAddress,
        firstName: firstName,
        lastName: lastName,
        gender: '',
        image: fbUser.photoURL ?? '',
        age: age,
        contactNo: contactNo,
        loginType: loginType,
        authProvider: 'firebase',
        firebaseUid: fbUser.uid,
      );

      // Firebase Auth alone doesn't store firstName/age/contactNo,
      // so keep those extra fields locally, keyed by the uid.
      await _saveLocalAccount(user, password, key: fbUser.uid);
      await _saveSession(user, password: password);

      // Lab Activity 6: mirror the profile into Firestore's "Users"
      // collection (doc id = uid) so the chat feature can list every
      // registered account and look people up by email.
      await _saveUserProfileToFirestore(user);

      return user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e));
    }
  }

  // Mirrors a Firebase-backed profile into Firestore's "Users" collection.
  // Safe to call repeatedly - it just overwrites the same doc (uid).
  Future<void> _saveUserProfileToFirestore(User user) async {
    if (user.firebaseUid == null || user.firebaseUid!.isEmpty) return;

    try {
      await _firestore.collection('Users').doc(user.firebaseUid).set({
        'uid': user.firebaseUid,
        'email': user.email,
        'username': user.username,
        'firstName': user.firstName,
        'lastName': user.lastName,
        'image': user.image,
      }, SetOptions(merge: true));
    } catch (_) {
      // Chat listing will just be missing this user if this fails;
      // it shouldn't block sign up / sign in.
    }
  }

  String _firebaseErrorMessage(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-not-found':
      case 'invalid-credential':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      default:
        return e.message ?? 'Firebase authentication error.';
    }
  }

  // ---------------------------------------------------------------------

  // Get whichever account is currently signed in
  Future<User?> getUserData() async {
    final savedUser = await getSavedUser();

    if (savedUser == null) {
      return null;
    }

    // Firebase-backed session: refresh straight from FirebaseAuth
    if (savedUser.authProvider == 'firebase') {
      final fbUser = _firebaseAuth.currentUser;

      if (fbUser == null) {
        return savedUser;
      }

      final updatedUser = savedUser.copyWith(
        email: fbUser.email ?? savedUser.email,
        image: fbUser.photoURL ?? savedUser.image,
      );

      await _saveSession(
        updatedUser,
        password: await _getSavedPassword() ?? '',
      );

      return updatedUser;
    }

    final token = savedUser.accessToken;

    if (token == null || token.isEmpty) {
      return savedUser;
    }

    try {
      final response = await http.get(
        _uri('/auth/me'),
        headers: _headers(
          accessToken: token,
        ),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['id'] != null) {
        final apiUser = User.fromJson(data);

        final updatedUser = savedUser.copyWith(
          id: apiUser.id,
          username: apiUser.username.isNotEmpty
              ? apiUser.username
              : savedUser.username,
          email: apiUser.email.isNotEmpty
              ? apiUser.email
              : savedUser.email,
          firstName: apiUser.firstName.isNotEmpty
              ? apiUser.firstName
              : savedUser.firstName,
          lastName: apiUser.lastName.isNotEmpty
              ? apiUser.lastName
              : savedUser.lastName,
          gender: apiUser.gender.isNotEmpty
              ? apiUser.gender
              : savedUser.gender,
          image: apiUser.image.isNotEmpty
              ? apiUser.image
              : savedUser.image,
        );

        // _getSavedPassword() returns String?, so use an
        // empty string when there is no saved password.
        await _saveSession(
          updatedUser,
          password: await _getSavedPassword() ?? '',
        );

        return updatedUser;
      }
    } catch (_) {
      // Saved data can still be shown
    }

    return savedUser;
  }

  // Get the locally saved session
  Future<User?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_sessionKey);

    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is Map<String, dynamic>) {
        return User.fromJson(decoded);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // Check if there is a saved login
  Future<bool> hasSavedSession() async {
    final user = await getSavedUser();
    return user != null;
  }

  // Check the current saved session
  Future<bool> validateSession() async {
    final user = await getSavedUser();
    return user != null;
  }

  // Refresh the DummyJSON token when available
  Future<User?> refreshToken() async {
    final savedUser = await getSavedUser();

    if (savedUser == null ||
        savedUser.refreshToken == null ||
        savedUser.refreshToken!.isEmpty) {
      return savedUser;
    }

    try {
      final response = await http.post(
        _uri('/auth/refresh'),
        headers: _headers(),
        body: jsonEncode({
          'refreshToken': savedUser.refreshToken,
          'expiresInMins': 30,
        }),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final updatedUser = savedUser.copyWith(
          accessToken:
              data['accessToken']?.toString() ??
                  savedUser.accessToken,
          refreshToken:
              data['refreshToken']?.toString() ??
                  savedUser.refreshToken,
        );

        // _getSavedPassword() returns String?, so use an
        // empty string when there is no saved password.
        await _saveSession(
          updatedUser,
          password: await _getSavedPassword() ?? '',
        );

        return updatedUser;
      }
    } catch (_) {
      // Keep the existing session if refresh fails
    }

    return savedUser;
  }

  // Change the current username
  Future<User> updateUsername(
    String newUsername, {
    required String currentPassword,
  }) async {
    final user = await getSavedUser();

    if (user == null) {
      throw Exception('No user session found.');
    }

    final validPassword =
        await _checkCurrentPassword(currentPassword);

    if (!validPassword) {
      throw Exception('Current password is incorrect.');
    }

    // Firebase-backed accounts: update the display name in Firebase
    if (user.authProvider == 'firebase') {
      try {
        await _firebaseAuth.currentUser
            ?.updateDisplayName(newUsername);
      } on firebase_auth.FirebaseAuthException catch (e) {
        throw Exception(_firebaseErrorMessage(e));
      }

      final updatedUser = user.copyWith(username: newUsername);

      await _saveSession(updatedUser, password: currentPassword);
      await _updateLocalAccount(
        updatedUser,
        key: user.firebaseUid,
      );
      await _saveUserProfileToFirestore(updatedUser);

      return updatedUser;
    }

    try {
      final response = await http.put(
        _uri('/users/${user.id}'),
        headers: _headers(
          accessToken: user.accessToken,
        ),
        body: jsonEncode({
          'username': newUsername,
        }),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final updatedUser = user.copyWith(
          username: newUsername,
        );

        await _saveSession(
          updatedUser,
          password: currentPassword,
        );

        await _updateLocalAccount(updatedUser);

        return updatedUser;
      }

      if (data['message'] != null) {
        throw Exception(data['message']);
      }
    } catch (e) {
      if (e is Exception &&
          e.toString().contains('Current password')) {
        rethrow;
      }
    }

    // DummyJSON updates are simulated, so keep it locally
    final updatedUser = user.copyWith(
      username: newUsername,
    );

    await _saveSession(
      updatedUser,
      password: currentPassword,
    );

    await _updateLocalAccount(updatedUser);

    return updatedUser;
  }

  // Change password after checking the old one
  Future<User> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = await getSavedUser();

    if (user == null) {
      throw Exception('No user session found.');
    }

    final validPassword =
        await _checkCurrentPassword(currentPassword);

    if (!validPassword) {
      throw Exception('Current password is incorrect.');
    }

    // Firebase-backed accounts: reauthenticate, then updatePassword
    if (user.authProvider == 'firebase') {
      try {
        final fbUser = _firebaseAuth.currentUser;

        if (fbUser == null) {
          throw Exception('No Firebase session found.');
        }

        final credential = firebase_auth.EmailAuthProvider.credential(
          email: user.email,
          password: currentPassword,
        );

        await fbUser.reauthenticateWithCredential(credential);
        await fbUser.updatePassword(newPassword);
      } on firebase_auth.FirebaseAuthException catch (e) {
        throw Exception(_firebaseErrorMessage(e));
      }

      await _saveSession(user, password: newPassword);
      await _updateLocalAccount(
        user,
        password: newPassword,
        key: user.firebaseUid,
      );

      return user;
    }

    try {
      await http.put(
        _uri('/users/${user.id}'),
        headers: _headers(
          accessToken: user.accessToken,
        ),
        body: jsonEncode({
          'password': newPassword,
        }),
      );
    } catch (_) {
      // Local password update still works
    }

    await _saveSession(
      user,
      password: newPassword,
    );

    await _updateLocalAccount(
      user,
      password: newPassword,
    );

    return user;
  }

  // Remove the current account
  Future<void> deleteAccount({
    required String password,
  }) async {
    final user = await getSavedUser();

    if (user == null) {
      throw Exception('No user session found.');
    }

    final validPassword =
        await _checkCurrentPassword(password);

    if (!validPassword) {
      throw Exception('Password is incorrect.');
    }

    // Firebase-backed accounts: reauthenticate, then delete
    if (user.authProvider == 'firebase') {
      try {
        final fbUser = _firebaseAuth.currentUser;

        if (fbUser != null) {
          final credential = firebase_auth.EmailAuthProvider.credential(
            email: user.email,
            password: password,
          );

          await fbUser.reauthenticateWithCredential(credential);
          await fbUser.delete();

          try {
            await _firestore
                .collection('Users')
                .doc(user.firebaseUid)
                .delete();
          } catch (_) {
            // Non-fatal - the auth account is already gone either way.
          }
        }
      } on firebase_auth.FirebaseAuthException catch (e) {
        throw Exception(_firebaseErrorMessage(e));
      }

      await _removeLocalAccount(user.firebaseUid ?? user.username);
      await logout();
      return;
    }

    try {
      await http.delete(
        _uri('/users/${user.id}'),
        headers: _headers(
          accessToken: user.accessToken,
        ),
      );
    } catch (_) {
      // Local removal still finishes the deletion
    }

    await _removeLocalAccount(user.username);

    await logout();
  }

  // Another name for logging out
  Future<void> signOut() async {
    await logout();
  }

  // Clear only the current login
  Future<void> logout() async {
    // Sign out of Firebase too, if a Firebase session was active.
    // Calling this when there's no Firebase user is a harmless no-op.
    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      // Ignore - there may not have been a Firebase session at all.
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_sessionKey);
    await prefs.remove(_passwordKey);
  }

  // Store the current session locally
  Future<void> _saveSession(
    User user, {
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _sessionKey,
      jsonEncode(user.toJson()),
    );

    await prefs.setString(
      _passwordKey,
      password,
    );
  }

  // Remember a signup account locally.
  // `key` lets Firebase accounts be looked up by uid instead of username.
  Future<void> _saveLocalAccount(
    User user,
    String password, {
    String? key,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final accounts = await _getLocalAccounts();

    accounts[key ?? user.username] = {
      'user': user.toJson(),
      'password': password,
    };

    await prefs.setString(
      _localAccountsKey,
      jsonEncode(accounts),
    );
  }

  // Update a saved signup account
  Future<void> _updateLocalAccount(
    User user, {
    String? password,
    String? key,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final accounts = await _getLocalAccounts();

    final lookupKey = key ?? user.username;
    final oldEntry = accounts[lookupKey];

    if (oldEntry is Map) {
      final updated =
          Map<String, dynamic>.from(oldEntry);

      updated['user'] = user.toJson();

      if (password != null) {
        updated['password'] = password;
      }

      accounts[lookupKey] = updated;

      await prefs.setString(
        _localAccountsKey,
        jsonEncode(accounts),
      );
    } else {
      final existingPassword =
          password ??
              await _getLocalPassword(lookupKey) ??
              '';

      accounts[lookupKey] = {
        'user': user.toJson(),
        'password': existingPassword,
      };

      await prefs.setString(
        _localAccountsKey,
        jsonEncode(accounts),
      );
    }
  }

  // Look for a locally registered user (by username or Firebase uid)
  Future<User?> _findLocalAccount(
    String key,
  ) async {
    final accounts = await _getLocalAccounts();

    final entry = accounts[key.trim()];

    if (entry is Map) {
      final userData = entry['user'];

      if (userData is Map) {
        return User.fromJson(
          Map<String, dynamic>.from(userData),
        );
      }
    }

    return null;
  }

  // Get the password saved for an account
  Future<String?> _getLocalPassword(
    String key,
  ) async {
    final accounts = await _getLocalAccounts();

    final entry = accounts[key.trim()];

    if (entry is Map) {
      return entry['password']?.toString();
    }

    return null;
  }

  // Read every locally saved account
  Future<Map<String, dynamic>> _getLocalAccounts() async {
    final prefs = await SharedPreferences.getInstance();

    final value = prefs.getString(
      _localAccountsKey,
    );

    if (value == null || value.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Start fresh if saved data is broken
    }

    return {};
  }

  // Remove one local account
  Future<void> _removeLocalAccount(
    String key,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final accounts = await _getLocalAccounts();

    accounts.remove(key);

    await prefs.setString(
      _localAccountsKey,
      jsonEncode(accounts),
    );
  }

  // Check the password used by this session
  Future<bool> _checkCurrentPassword(
    String password,
  ) async {
    final user = await getSavedUser();

    if (user == null) {
      return false;
    }

    // Firebase accounts: verify by reauthenticating
    if (user.authProvider == 'firebase') {
      try {
        final fbUser = _firebaseAuth.currentUser;

        if (fbUser == null) {
          return false;
        }

        final credential = firebase_auth.EmailAuthProvider.credential(
          email: user.email,
          password: password,
        );

        // This throws if the password is wrong - it doesn't
        // change any state, just confirms the credential.
        await fbUser.reauthenticateWithCredential(credential);

        return true;
      } catch (_) {
        return false;
      }
    }

    final savedPassword = await _getSavedPassword();

    if (savedPassword != null && savedPassword == password) {
      return true;
    }

    try {
      final response = await http.post(
        _uri('/auth/login'),
        headers: _headers(),
        body: jsonEncode({
          'username': user.username,
          'password': password,
        }),
      );

      return response.statusCode >= 200 &&
          response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // Get the password from the active session
  Future<String?> _getSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_passwordKey);
  }
}

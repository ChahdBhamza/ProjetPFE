import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/api_exception.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  bool _isLoading = false;
  String? _userEmail;
  String? _fullName;
  bool _isAdmin = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get userEmail => _userEmail;
  String? get fullName => _fullName;
  bool get isAdmin => _isAdmin;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _userEmail != null;

  AuthProvider() {
    _loadSession();
  }

  /// Load session from Secure Storage
  Future<void> _loadSession() async {
    const storage = FlutterSecureStorage();
    _userEmail = await storage.read(key: 'user_email');
    _fullName = await storage.read(key: 'full_name');
    final adminStr = await storage.read(key: 'is_admin');
    _isAdmin = adminStr == 'true';
    if (_userEmail != null) {
      print("[Auth] Session restored for: $_userEmail, isAdmin: $_isAdmin");
      notifyListeners();
    }
  }

  /// Save session to Secure Storage
  Future<void> _saveSession(String email, String name, String token, bool isAdmin) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'user_email', value: email);
    await storage.write(key: 'full_name', value: name);
    await storage.write(key: 'jwt_token', value: token);
    await storage.write(key: 'is_admin', value: isAdmin ? 'true' : 'false');
  }

  /// Register a new user in MongoDB
  Future<bool> signUp(String email, String password, String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.signUp(email, password, name);
      
      _isLoading = false;
      if (result["success"] == true) {
        _userEmail = email;
        _fullName = name;
        final token = result["token"];
        final isAdmin = result["user"]["is_admin"] == true;
        _isAdmin = isAdmin;
        await _saveSession(email, name, token, isAdmin);
        notifyListeners();
        return true;
      }
      return false;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Log in to an existing account
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.signIn(email, password);
      
      _isLoading = false;
      if (result["success"] == true) {
        _userEmail = result["user"]["email"];
        _fullName = result["user"]["full_name"];
        final token = result["token"];
        final isAdmin = result["user"]["is_admin"] == true;
        _isAdmin = isAdmin;
        await _saveSession(_userEmail!, _fullName!, token, isAdmin);
        notifyListeners();
        return true;
      }
      return false;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Log in using Google OAuth
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Force account picker by signing out first
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("[Auth] Google Sign-In cancelled by user.");
        _isLoading = false;
        notifyListeners();
        return false; 
      }

      print("[Auth] Google User detected: ${googleUser.email}");

      // Send Google details to backend for synchronization
      final result = await _apiService.googleSignIn(
        googleUser.email,
        googleUser.displayName ?? "Google User",
      );

      if (result["success"] == true) {
        _userEmail = googleUser.email;
        _fullName = googleUser.displayName;
        final token = result["token"];
        final isAdmin = result["user"]["is_admin"] == true;
        _isAdmin = isAdmin;
        await _saveSession(_userEmail!, _fullName ?? "Google Operator", token, isAdmin);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = "Google synchronization failed.";
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      print("GOOGLE PLUGIN ERROR: $e");
      _isLoading = false;
      _errorMessage = "Google login failed: $e";
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
    await _googleSignIn.signOut();
    _userEmail = null;
    _fullName = null;
    _isAdmin = false;
    _errorMessage = null;
    notifyListeners();
  }
}

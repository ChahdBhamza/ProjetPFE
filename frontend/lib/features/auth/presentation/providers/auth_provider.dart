import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/network/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  bool _isLoading = false;
  String? _userEmail;
  String? _fullName;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get userEmail => _userEmail;
  String? get fullName => _fullName;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _userEmail != null;

  /// Register a new user in MongoDB
  Future<bool> signUp(String email, String password, String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _apiService.signUp(email, password, name);
    
    _isLoading = false;
    if (result["success"] == true) {
      _userEmail = email;
      _fullName = name;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result["detail"] ?? "Sign up failed.";
      notifyListeners();
      return false;
    }
  }

  /// Log in to an existing account
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _apiService.signIn(email, password);
    
    _isLoading = false;
    if (result["success"] == true) {
      _userEmail = result["user"]["email"];
      _fullName = result["user"]["full_name"];
      notifyListeners();
      return true;
    } else {
      _errorMessage = result["detail"] ?? "Login failed.";
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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false; 
      }

      // Send Google details to backend for synchronization
      final result = await _apiService.googleSignIn(
        googleUser.email,
        googleUser.displayName ?? "Google User",
      );

      if (result["success"] == true) {
        _userEmail = googleUser.email;
        _fullName = googleUser.displayName;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result["detail"] ?? "Google synchronization failed.";
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print("GOOGLE PLUGIN ERROR: $e");
      _isLoading = false;
      _errorMessage = "Google login failed: $e";
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _userEmail = null;
    _fullName = null;
    _errorMessage = null;
    notifyListeners();
  }
}

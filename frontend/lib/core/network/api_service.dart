import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equipment_detection_app/features/app/data/models/detection_result_model.dart';

class ApiService {
  final Dio _dio;

  ApiService() : _dio = Dio(BaseOptions(
    baseUrl: _getBaseUrl(),
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  )) {
    // Interceptor to automatically attach the JWT token to every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  /// Send image for detection and RAG processing
  Future<DetectionResult?> detectEquipment(XFile imageFile) async {
    try {
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(imageFile.path, filename: "upload.jpg"),
      });

      Response response = await _dio.post("/api/search", data: formData);

      if (response.statusCode == 200) {
        return DetectionResult.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print("Detection API Error: $e");
      return null;
    }
  }

  /// Send video for key frame extraction and search
  Future<DetectionResult?> detectFromVideo(XFile videoFile) async {
    try {
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(videoFile.path, filename: "upload.mp4"),
        "auto_search": "true",
      });

      Response response = await _dio.post("/api/video/extract-frames", data: formData);

      if (response.statusCode == 200 && response.data["success"] == true) {
        if (response.data["auto_search_result"] != null) {
          return DetectionResult.fromJson(response.data["auto_search_result"]);
        }
      }
      return null;
    } catch (e) {
      print("Video Detection API Error: $e");
      return null;
    }
  }

  /// Save detection to user's MongoDB inventory
  Future<bool> saveToInventory(DetectionResult result) async {
    try {
      final item = result.vectorMatch?.item;
      if (item == null) return false;

      Response response = await _dio.post(
        "/api/auth/inventory/save",
        data: {
          "brand": item.brand,
          "model": item.modelName,
          "btu": item.btu,
          "metadata": result.verifiedDetails ?? {},
        },
      );
      return response.data["success"] == true;
    } catch (e) {
      print("Inventory Save Error: $e");
      return false;
    }
  }

  /// Fetch user's inventory from MongoDB
  Future<List<dynamic>> fetchInventory() async {
    try {
      Response response = await _dio.get("/api/auth/inventory/list");
      if (response.data["success"] == true) {
        return response.data["inventory"] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Inventory Fetch Error: $e");
      return [];
    }
  }

  /// Authentication: Create a new account
  Future<Map<String, dynamic>> signUp(String email, String password, String fullName) async {
    try {
      Response response = await _dio.post(
        "/api/auth/signup",
        data: {
          "email": email,
          "password": password,
          "full_name": fullName,
        },
      );
      return response.data;
    } on DioException catch (e) {
      final detail = e.response?.data?["detail"] ?? e.message;
      return {"success": false, "detail": detail};
    } catch (e) {
      return {"success": false, "detail": "Neural Link failed: $e"};
    }
  }

  /// Authentication: Log in to existing account
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      Response response = await _dio.post(
        "/api/auth/login",
        data: {
          "email": email,
          "password": password,
        },
      );
      return response.data;
    } on DioException catch (e) {
      // Extract the specific "detail" from FastAPI if available
      final detail = e.response?.data?["detail"] ?? "Neural verification failed.";
      return {"success": false, "detail": detail};
    } catch (e) {
      return {"success": false, "detail": "Connection failed. Is the backend running?"};
    }
  }

  /// Authentication: Log in using Google OAuth
  Future<Map<String, dynamic>> googleSignIn(String email, String fullName) async {
    try {
      print("DEBUG: Calling Backend at ${_dio.options.baseUrl}/api/auth/google");
      Response response = await _dio.post(
        "/api/auth/google",
        data: {
          "email": email,
          "full_name": fullName,
        },
      );
      return response.data;
    } catch (e) {
      print("GOOGLE AUTH ERROR: $e");
      return {"success": false, "detail": "Google synchronization failed."};
    }
  }

  static String _getBaseUrl() {
    // We use localhost:8000 for both Windows and Android (via ADB Reverse).
    // If you are using a physical device, ensure you run:
    // 'adb reverse tcp:8000 tcp:8000'
    return "http://localhost:8000";
  }
}

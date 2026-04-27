import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:equipment_detection_app/features/app/data/models/detection_result_model.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: "http://192.168.11.19:5000",
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

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

  /// Save detection to user's MongoDB inventory
  Future<bool> saveToInventory(DetectionResult result) async {
    try {
      final item = result.vectorMatch?.item;
      if (item == null) return false;

      Response response = await _dio.post(
        "/api/inventory/save",
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
    } catch (e) {
      return {"success": false, "detail": e.toString()};
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
    } catch (e) {
      return {"success": false, "detail": "Connection failed. Is the backend running?"};
    }
  }

  /// Authentication: Log in using Google OAuth
  Future<Map<String, dynamic>> googleSignIn(String email, String fullName) async {
    try {
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
}

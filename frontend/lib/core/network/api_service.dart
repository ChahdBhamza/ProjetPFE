import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equipment_detection_app/features/app/data/models/detection_result_model.dart';

class ApiService {
  final Dio _dio;

  ApiService() : _dio = Dio(BaseOptions(
    baseUrl: _getBaseUrl(),
    connectTimeout: const Duration(seconds: 600),
    receiveTimeout: const Duration(seconds: 600),
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

  /// Script Lab: Extract and deduplicate frames
  Future<Map<String, dynamic>?> scriptProcessVideo(XFile videoFile) async {
    try {
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(videoFile.path, filename: "lab_video.mp4"),
      });

      Response response = await _dio.post("/api/video/script-process", data: formData);
      return response.data;
    } catch (e) {
      print("Script Lab Extraction Error: $e");
      return null;
    }
  }

  /// Script Lab: Run AI on specific frame filenames
  Future<Map<String, dynamic>?> processSelectedFrames(String sessionId, List<String> filenames) async {
    try {
      Response response = await _dio.post(
        "/api/video/process-selected-frames",
        data: {
          "session_id": sessionId,
          "filenames": filenames,
        },
      );
      return response.data;
    } catch (e) {
      print("Script Lab AI Error: $e");
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
    // Optional: flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      return fromEnv.endsWith('/')
          ? fromEnv.substring(0, fromEnv.length - 1)
          : fromEnv;
    }
    // Physical phone + USB: run `adb reverse tcp:8000 tcp:8000` then 127.0.0.1 reaches the PC.
    // Some Android builds resolve "localhost" oddly; 127.0.0.1 is more reliable with reverse.
    // Android emulator (no reverse): flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
    if (Platform.isAndroid) {
      return 'http://127.0.0.1:8000';
    }
    return 'http://localhost:8000';
  }

  Future<Map<String, dynamic>> getSpecs(String brand, String model, String type) async {
    final response = await _dio.post('/api/video/get-specs', data: {
      'brand': brand,
      'model': model,
      'equipment_type': type,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> processVideoScript(File video) async {
    String fileName = video.path.split('/').last;
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(video.path, filename: fileName),
    });

    try {
      final response = await _dio.post(
        '/api/video/script-process',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 600),
          receiveTimeout: const Duration(seconds: 600),
        ),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {'success': false, 'error': 'Unexpected response from server'};
    } on DioException catch (e) {
      final msg = e.message ?? 'Network error';
      final detail = e.response?.data;
      final backend = detail is Map ? detail['error'] ?? detail['detail'] : detail;
      return {
        'success': false,
        'error': backend?.toString() ?? msg,
        'hint':
            'Phone cannot reach the API. USB: run `adb reverse tcp:8000 tcp:8000`. Wi‑Fi: set --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}

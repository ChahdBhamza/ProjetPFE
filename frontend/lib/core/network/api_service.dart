import 'dart:io';
import 'package:dio/dio.dart';

class ApiService {
  // Use your local IP so the mobile device/emulator can reach the backend
  static const String baseUrl = "http://192.168.100.5:8000";
  
  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Uploads an image to the /search endpoint and returns the detection results.
  Future<Map<String, dynamic>> searchEquipment(File imageFile) async {
    try {
      String fileName = imageFile.path.split('/').last;
      
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          imageFile.path, 
          filename: fileName,
        ),
        "use_vlm": "true", // Enable high-accuracy mode
        "use_openai": "false", // Use Gemini by default
      });

      Response response = await _dio.post(
        "/api/search",
        data: formData,
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      print("API Error: ${e.message}");
      rethrow;
    }
  }
}

import 'dart:io';
import 'package:dio/dio.dart';
import '../data/models/detection_result_model.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://192.168.100.5:8000',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  /// Uploads an image to the backend and returns the parsed detection result
  Future<DetectionResponse> searchEquipment(File imageFile) async {
    try {
      String fileName = imageFile.path.split('/').last;
      
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(imageFile.path, filename: fileName),
        "use_vlm": false,
        "use_openai": false,
      });

      Response response = await _dio.post(
        "/api/search",
        data: formData,
      );

      if (response.statusCode == 200) {
        return DetectionResponse.fromJson(response.data);
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to backend: $e');
    }
  }
}

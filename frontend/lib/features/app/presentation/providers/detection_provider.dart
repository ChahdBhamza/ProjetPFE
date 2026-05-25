import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:equipment_detection_app/core/network/api_service.dart';
import 'package:equipment_detection_app/features/app/data/models/detection_result_model.dart';

enum DetectionStatus { idle, loading, success, error }

class DetectionProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  DetectionStatus _status = DetectionStatus.idle;
  DetectionResult? _result;
  File? _capturedFile;
  String? _errorMessage;

  DetectionStatus get status => _status;
  DetectionResult? get result => _result;
  File? get capturedFile => _capturedFile;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == DetectionStatus.loading;

  /// Initiate video-based equipment detection
  Future<void> detectFromVideo(File file) async {
    _status = DetectionStatus.loading;
    _capturedFile = file;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.detectFromVideo(XFile(file.path));
      
      if (response != null) {
        _result = response;
        _status = DetectionStatus.success;
      } else {
        _status = DetectionStatus.error;
        _errorMessage = "Key frame extraction failed to identify product.";
      }
    } catch (e) {
      _status = DetectionStatus.error;
      _errorMessage = "Connection to Cloud Cluster lost: $e";
    }
    notifyListeners();
  }

  /// Save the currently detected item to the user's MongoDB inventory
  Future<bool> saveCurrentToInventory() async {
    if (_result == null) return false;

    try {
      final success = await _apiService.saveToInventory(_result!);
      return success;
    } catch (e) {
      print("Inventory Save Error: $e");
      return false;
    }
  }

  void reset() {
    _status = DetectionStatus.idle;
    _result = null;
    _capturedFile = null;
    _errorMessage = null;
    notifyListeners();
  }
}

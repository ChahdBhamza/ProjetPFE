import 'dart:convert';

class DetectionResult {
  final bool success;
  final VectorMatch? vectorMatch;
  final String? ocrText;
  final Map<String, dynamic>? webGrounding;
  final Map<String, dynamic>? verifiedDetails;

  DetectionResult({
    required this.success,
    this.vectorMatch,
    this.ocrText,
    this.webGrounding,
    this.verifiedDetails,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      success: json['success'] ?? false,
      vectorMatch: json['vector_match'] != null 
          ? VectorMatch.fromJson(json['vector_match']) 
          : null,
      ocrText: json['ocr_text'],
      webGrounding: json['web_grounding'],
      verifiedDetails: json['verified_details'],
    );
  }
}

class VectorMatch {
  final EquipmentItem item;
  final double confidence;

  VectorMatch({required this.item, required this.confidence});

  factory VectorMatch.fromJson(Map<String, dynamic> json) {
    return VectorMatch(
      item: EquipmentItem.fromJson(json['item']),
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

class EquipmentItem {
  final String? filename;
  final String brand;
  final String? btu;
  final String? modelName;
  final String? normalizedReference;
  final String? price;

  EquipmentItem({
    this.filename,
    required this.brand,
    this.btu,
    this.modelName,
    this.normalizedReference,
    this.price,
  });

  factory EquipmentItem.fromJson(Map<String, dynamic> json) {
    return EquipmentItem(
      filename: json['filename'],
      brand: json['brand'] ?? 'Unknown',
      btu: json['btu']?.toString(),
      modelName: json['model_name'],
      normalizedReference: json['normalized_reference'],
      price: json['price']?.toString(),
    );
  }
}

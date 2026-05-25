import 'dart:convert';

class DetectionResult {
  final bool success;
  final VectorMatch? vectorMatch;
  final String? ocrText;
  final Map<String, dynamic>? webGrounding;
  final Map<String, dynamic>? verifiedDetails;
  final EquipmentResult? equipmentResult;

  DetectionResult({
    required this.success,
    this.vectorMatch,
    this.ocrText,
    this.webGrounding,
    this.verifiedDetails,
    this.equipmentResult,
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
      equipmentResult: json['equipment_result'] != null
          ? EquipmentResult.fromJson(json['equipment_result'])
          : null,
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

class EquipmentResult {
  final EquipmentIdentity identity;
  final Map<String, dynamic> specs;
  final EquipmentMeta meta;

  EquipmentResult({
    required this.identity,
    required this.specs,
    required this.meta,
  });

  factory EquipmentResult.fromJson(Map<String, dynamic> json) {
    return EquipmentResult(
      identity: EquipmentIdentity.fromJson(json['identity'] ?? {}),
      specs: json['specs'] ?? {},
      meta: EquipmentMeta.fromJson(json['meta'] ?? {}),
    );
  }
}

class EquipmentIdentity {
  final String equipmentCategory;
  final String brand;
  final String topModel;
  final int confidence;
  final List<dynamic> allCandidates;
  final List<String> visualCues;
  final int? pass1TypeConfidence;

  EquipmentIdentity({
    required this.equipmentCategory,
    required this.brand,
    required this.topModel,
    required this.confidence,
    required this.allCandidates,
    required this.visualCues,
    this.pass1TypeConfidence,
  });

  factory EquipmentIdentity.fromJson(Map<String, dynamic> json) {
    return EquipmentIdentity(
      equipmentCategory: json['equipment_category'] ?? 'unknown',
      brand: json['brand'] ?? 'Unknown',
      topModel: json['top_model'] ?? 'Unknown Model',
      confidence: json['confidence'] ?? 0,
      allCandidates: json['all_candidates'] ?? [],
      visualCues: List<String>.from(json['visual_cues'] ?? []),
      pass1TypeConfidence: json['pass1_type_confidence'],
    );
  }
}

class EquipmentMeta {
  final String? sourceQuality;
  final int? fieldsFound;
  final List<String> sourceUrls;
  final String? pipeline;
  final String? summary;
  final bool verified;

  EquipmentMeta({
    this.sourceQuality,
    this.fieldsFound,
    required this.sourceUrls,
    this.pipeline,
    this.summary,
    required this.verified,
  });

  factory EquipmentMeta.fromJson(Map<String, dynamic> json) {
    return EquipmentMeta(
      sourceQuality: json['source_quality'],
      fieldsFound: json['fields_found'],
      sourceUrls: List<String>.from(json['source_urls'] ?? []),
      pipeline: json['pipeline'],
      summary: json['summary'],
      verified: json['verified'] ?? false,
    );
  }
}

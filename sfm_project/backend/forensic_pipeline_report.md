# Technical Report: Intelligent Forensic Ingestion Engine
**Project:** Forensic Object Identification & Specification Retrieval (PFE)
**Date:** May 14, 2026
**Version:** 3.5 (Production Optimized)

## 1. Overview
The Intelligent Forensic Ingestion Engine is a high-precision video analysis pipeline designed to automate technical inventory and forensic documentation. Unlike standard object detectors, this engine utilizes spatial-temporal optimization to extract the highest-quality "Hero Shots" from a raw video stream.

## 2. Core Architecture: The "Tri-Model" Orchestration
The system utilizes three distinct AI layers to ensure accuracy:
1. **Local Localization (YOLOv5):** Fast, local processing for broad object tracking and initial scene understanding.
2. **Specialized Cloud Experts (Roboflow Workflows):** High-precision identification using the `custom-workflow-3` model for specialized forensic equipment (Air Conditioners, Microwaves, Refrigerators).
3. **Reasoning & Validation (Gemini):** A final intelligence layer that validates detections and retrieves technical specifications based on visual evidence.

## 3. Key Innovations

### 3.1 Temporal Consistency (Stability)
To eliminate "flickering" detections and false positives caused by motion blur, the engine implements a **Sliding Window Algorithm**:
* **Window Size:** 5 frames.
* **Verification Threshold:** 3/5 hits.
* **Logic:** An object is only "Verified" as forensic evidence if it is consistently detected across multiple timestamps.

### 3.2 Spatial "Hero Shot" Optimization
The engine does not save every detection; it saves only the "Winner" for each category based on a **Quality Score (Q)**:
$$Q = (0.6 \times Confidence) + (0.4 \times Centering)$$
* **Confidence:** Probability score from the AI models.
* **Centering:** A mathematical calculation of the object's proximity to the center of the frame (prioritizing clear, non-cropped views).

### 3.3 Forensic Traceability
Every exported image is a "Legal-Ready" document:
* **Unique Bounding Boxes:** Visual proof of detection.
* **Frame Tracking:** The filename includes the original video frame index for auditability.
* **Whitelist Filtering:** Automated removal of non-forensic "noise" (chairs, bottles, etc.) using robust keyword matching.

## 4. Operational Workflow
1. **Input:** Raw video recording (MP4/MOV).
2. **Scan:** Intelligent interval-based scanning (Interval 8).
3. **Verify:** Temporal stability check (3 out of 5 voting).
4. **Rank:** Real-time leaderboard updates for the "Hero" frame based on Quality Score.
5. **Export:** Generation of annotated, traceable forensic images in the `final_shots` directory.

## 5. Conclusion
By transitioning from "Frame-by-Frame Detection" to "Scene-Aware Ingestion," this pipeline guarantees that the forensic report contains only verified, high-quality, and centered evidence, significantly reducing manual data entry for the investigator.

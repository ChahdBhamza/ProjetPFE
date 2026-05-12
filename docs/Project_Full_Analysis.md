# Project Analysis: Cybersight - Multimodal Visual RAG

## 1. Project Overview & Vision
**Cybersight** is an advanced AI system designed to bridge the gap between physical hardware and digital technical data. The project enables users to identify complex equipment (specifically Air Conditioners) and retrieve verified technical specifications simply by taking a photo.

### The Problematic (The Challenges)
*   **Cryptic Model Identifiers**: Standard users cannot easily interpret industrial model codes.
*   **Inconsistent Data Sources**: Retailers provide unstructured and often duplicate data.
*   **Visual Ambiguity**: Many different hardware models share identical external chassis.
*   **AI Hallucination**: General-purpose LLMs lack specific, local Tunisian product knowledge.

---

## 2. The Solution: Multimodal Visual RAG
The project implements a **Retrieval-Augmented Generation (RAG)** architecture specialized for Computer Vision.

1.  **Visual Retrieval**: Uses vector similarity to find the most likely product matches from a curated database.
2.  **Metadata Augmentation**: Retrieves the exact technical specs associated with the visual match.
3.  **Forensic Verification**: A Vision-Language Model (Gemini) compares the user's photo against the retrieved metadata to confirm the match with high confidence.

---

## 3. Data Engineering & ETL Pipeline
The system relies on a robust, high-fidelity data foundation.

*   **Deep Scraping**: Automated concurrent collection of data from major Tunisian retailers (Spacenet, MyTek, etc.).
*   **Technical Identity Standard**: Implementation of a unique fingerprinting system `(Brand + BTU + Inverter + Mode)`.
*   **Intelligent Deduplication**: Use of fuzzy matching to reduce a noisy dataset of 398 records into **336 unique technical identities**.
*   **Hierarchical Storage**: Data is organized into a clean `[Brand]/[Category]/[Specs+Images]` structure for traceability.

---

## 4. Technical Architecture (The AI Stack)

| Layer | Component | Role |
| :--- | :--- | :--- |
| **Detection** | YOLOv5 / Roboflow | Isolates the equipment and removes background noise. |
| **Embedding** | OpenAI CLIP (ViT-B/32) | Generates a 512-dimensional "Visual DNA" vector. |
| **Vector Store** | Qdrant | High-speed Cosine Similarity search for visual matches. |
| **Reasoning** | Gemini 2.0 Flash | Performs "Forensic Validation" (Logo, Vents, Labels). |
| **Grounding** | Google Search / DDGS | Cross-references DB info with live web data. |
| **Edge Fallback** | Moondream2 (Local VLM) | Enables offline/private visual reasoning. |

---

## 5. Advanced Implementation Concepts

### Hybrid Search & Reranking
The system uses a **Dual-Path Search**:
*   **Path A**: Visual Similarity (CLIP + Qdrant).
*   **Path B**: Keyword Matching (OCR Text + Metadata).
*   **Result**: The system reranks vector results based on OCR evidence (e.g., if the text "GREE" is detected, GREE products are boosted).

### Dual-Vision Forensic Protocol
The `VisionRAGService` processes two distinct views:
1.  **Color View**: Analyzes brand design language and color-coded logos.
2.  **High-Contrast View**: Optimizes pixel data for reading technical alphanumeric labels.

### Robust API Design
*   **Lazy Loading**: Models are loaded on-demand to optimize memory usage.
*   **Exponential Backoff**: Advanced retry logic handles API rate limits (429/503 errors).
*   **Asynchronous Orchestration**: Parallel processing of detection and retrieval.

---

## 6. System Modeling
*   **Backend**: FastAPI (Python) - High-performance asynchronous API.
*   **Frontend**: Flutter (Dart) - Premium, HUD-inspired mobile interface.
*   **Database**: Qdrant (Vector) for similarity and MongoDB for detection logging and user favorites.

---

## 7. Conclusion
**DetectionAppPFE (Cybersight)** represents a full-cycle AI Engineering project. It successfully combines data mining, vector mathematics, and large language models into a cohesive industrial tool. The architecture is modular, scalable to new equipment categories, and optimized for both accuracy and performance.

---
*Generated for Cybersight PFE Analysis - May 2026*

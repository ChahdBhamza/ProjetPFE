# Project Documentation: Multimodal Visual RAG for AC Detection

This document provides a comprehensive, step-by-step breakdown of the "DetectionAppPFE" project, designed for identifying air conditioning units and retrieving their technical specifications using advanced AI techniques.

## 1. Project Overview
The objective of this project is to build an intelligent system that allows a user to take a photo of an Air Conditioning (AC) unit and instantly receive verified technical specifications (Brand, BTU, Energy Rating, etc.). The system combines **Computer Vision**, **Vector Databases**, and **Large Language Models (LLMs)** with **Web Search Grounding**.

---

## 2. System Architecture
The project follows a modern decoupled architecture:
*   **Mobile Frontend**: React Native (Expo) app for the user interface.
*   **Backend API**: FastAPI (Python) managing the logic and AI pipelines.
*   **Vector Database**: Qdrant for storing and searching high-dimensional image features.
*   **AI Models**: 
    *   **CLIP (OpenAI)**: For multimodal (image-to-image) embeddings.
    *   **Gemini 2.0 Flash**: For visual reasoning, data extraction, and search grounding.

---

## 3. Step-by-Step Implementation

### Step 1: Data Acquisition & Deep Scraping
The foundation of the project is a rich, high-fidelity dataset of AC units. This was achieved through a custom-built data extraction engine.
*   **Target Selection**: The engine focuses on major Tunisian electronics retailers (e.g., Spacenet) to ensure the data is local and relevant.
*   **Technical Implementation**:
    1.  **Automated Crawling & Pagination**: The scraper automatically navigates through multiple category pages, dynamically discovering individual product URLs.
    2.  **Concurrent Processing**: Using Python's `ThreadPoolExecutor`, the scraper visits multiple product pages simultaneously. This significantly reduces data collection time while maintaining a stable connection.
    3.  **Deep Parsing**: For each product, the system uses `BeautifulSoup` to extract:
        *   **Identity**: Full product name and category.
        *   **Financials**: Current price and availability.
        *   **Technical Specs (Fiche Technique)**: The scraper specifically targets specification tables (e.g., BTU capacity, energy class, compressor type).
        *   **Visual Assets**: High-resolution image URLs for the embedding pipeline.
    4.  **Intelligent Brand Mapping**: An automated keyword-matching algorithm detects and groups products by brand (Gree, Samsung, LG, etc.) during extraction.

### Step 2: Data Extraction & Organization (ETL)
Once raw data is collected, it undergoes an extract-transform-load (ETL) process to prepare it for the Visual RAG pipeline.
*   **Sanitization**: Filenames are cleaned as per OS standards to ensure robust storage.
*   **Hierarchical Storage**: Data is organized into a structured directory tree:
    *   `dataequipment/climatiseurs/[Brand]/images/`: Containing the visual reference for CLIP.
    *   `dataequipment/climatiseurs/[Brand]/text/`: Containing sanitized `.txt` files with full technical specifications.
*   **Asset Management**: An automated downloader captures images, validates their integrity, and maps them to their corresponding specification files. This mapping is what allows the "Retrieval" part of RAG to work.

### Step 3: Generating Multimodal Embeddings (CLIP)
To compare a user's photo with our database, we convert images into mathematical vectors (embeddings).
*   **Model**: `openai/clip-vit-base-patch32` (Vision Transformer).
*   **Technical Implementation**:
    *   **Preprocessing**: Input images are converted to RGB and resized/normalized using the CLIP processor.
    *   **Feature Extraction**: The model outputs a high-dimensional feature vector.
    *   **Vector Normalization**: Vectors are L2-normalized (`features / features.norm`). This ensures that the dot product calculation in the vector store is equivalent to Cosine Similarity, which is the gold standard for comparing visual semantic similarity.
    *   **Multimodal Capability**: By using CLIP, the system can potentially support "Text-to-Image" search (e.g., searching "Gree 12000 BTU") in addition to "Image-to-Image" search.

### Step 4: Vector Indexing (Qdrant)
We need a way to search through thousands of vectors instantly.
*   **Tooling**: Qdrant Vector Database.
*   **Process**:
    1.  The product database (from Step 2) is iterated over.
    2.  Each product image is passed through the normalized CLIP pipeline.
    3.  The resulting vector + Metadata (Name, Price, Brand, Technical Specs) are stored as a "Point" in Qdrant.
    4.  **Metric**: Space is configured for `Distance.COSINE` to maximize accuracy for feature-based comparisons.

### Step 5: The Visual RAG Pipeline & FastAPI Setup
The backend is powered by **FastAPI**, chosen for its high performance and native support for asynchronous operations.
1.  **Endpoints**:
    *   `POST /api/step3_search`: Accepts an `UploadFile` (the photo).
    *   `GET /`: Serves the system dashboard/demo page.
2.  **Pipeline Flow**:
    *   **Query Embedding**: User photo is processed via `CLIPEmbedder`.
    *   **Vector Search**: Qdrant retrieves the top match with a similarity score (typically > 0.8 for strong matches).
    *   **Multi-Stage Verification (Gemini)**:
        *   **Visual Logic**: Gemini analyzes the uploaded image's pixels.
        *   **Contextual RAG**: The product metadata from Qdrant is injected into the LLM prompt as context.
        *   **Grounding**: Google Search is called via GenAI tools to verify if the BTU or energy class cited in the database is consistent with current official records.
3.  **JSON Response**: The API returns a strictly formatted JSON including `retrieved_item`, `cosine_similarity`, and the `gemini_json_response`.

### Step 6: Reliability & Error Handling
*   **API Stability**: Implemented **Exponential Backoff** (retry logic) for Gemini API calls to handle network issues or service spikes (`503 UNAVAILABLE` errors).
*   **Modularity**: Services are separated into `clip_embedder.py`, `vector_store.py`, and `scraper_services.py` for maintainability.

---

## 4. Summary of Key Technologies
| Component | Technology | Role |
| :--- | :--- | :--- |
| **Backend** | FastAPI / Uvicorn | High-performance API hosting |
| **Embeddings** | OpenAI CLIP (ViT-B/32) | Image-to-vector transformation |
| **Vector DB** | Qdrant | Similarity search engine |
| **LLM / Vision** | Google Gemini (GenAI) | Visual reasoning & Grounding |
| **Scraper** | BeautifulSoup / HTTPX | Automated data collection |
| **Frontend** | React Native / Expo | Cross-platform mobile app |

---

## 5. Repository Structure
```text
DetectionAppPFE/
├── backend/
│   ├── app/
│   │   ├── services/           # CLIP, Qdrant, and Scraper logic
│   │   └── api/                # FastAPI routes
│   ├── data_exporter.py        # Logic to move data to index
│   ├── demo_pipeline.py        # Main entry point for RAG
│   └── scraper_results.json    # The knowledge base
├── frontend/                   # React Native mobile app
└── dataequipment/              # Local storage for images/specs
```

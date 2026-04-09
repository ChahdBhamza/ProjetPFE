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
    1.  **Automated Crawling & Pagination**: The scraper automatically navigates through multiple category pages.
    2.  **Concurrent Processing**: Using Python's `ThreadPoolExecutor`, the scraper visits multiple product pages simultaneously.
    3.  **Deep Parsing**: For each product, the system uses `BeautifulSoup` to extract Identity, Financials, technical specs (Fiche Technique), and Visual Assets.

### Step 2: Data Extraction & Organization (ETL)
Once raw data is collected, it undergoes an extract-transform-load (ETL) process.
*   **Hierarchical Storage**: Data is organized into a structured directory tree:
    *   `dataequipment/climatiseurs/[Brand]/images/`: Containing the visual reference for CLIP.
    *   `dataequipment/climatiseurs/[Brand]/text/`: Containing sanitized `.txt` files with full technical specifications.

### Step 3: Generating Multimodal Embeddings (CLIP)
To compare a user's photo with our database, we convert images into mathematical vectors (embeddings).
*   **Model**: `openai/clip-vit-base-patch32` (Vision Transformer).
*   **Vector Normalization**: Vectors are L2-normalized to ensure that similarity is calculated via Cosine Similarity, maximizing accuracy for visual semantic comparisons.

### Step 4: Vector Indexing (Qdrant)
*   **Process**:
    1.  The product database is iterated over.
    2.  Each product image is passed through the normalized CLIP pipeline.
    3.  The resulting vector + Metadata (Name, Price, Brand, Technical Specs) are stored as a "Point" in Qdrant.

### Step 5: Metadata Enrichment & Standardization
To transition from "raw scraped text" to a "structured knowledge base," a local **Heuristic Pattern Matching (Regex)** engine was implemented. 
*   **Purpose**: Extract technical fields (BTU, Gas, Inverter, Price, Color, Surface Area) at zero cost.
*   **Result**: 133 product records now have structured JSON metadata, enabling precise filtering and verification.

### Step 6: Multi-Source Web Grounding Architecture
An "Open World" verification mode was developed to solve the "Limited Database" problem.
*   **Vision Translator (Gemini)**: Extracts Brand/Model identifiers from upload.
*   **Heuristic Researcher (DuckDuckGo)**: Free, real-time web search for the detected model.
*   **Grounding Logic**: Cross-references local DB, Visual detection, and Web evidence to reach a "Truth-Based" conclusion.

---

## 4. Key Technologies Summary
| Component | Technology | Role |
| :--- | :--- | :--- |
| **Backend** | FastAPI / Uvicorn | High-performance API hosting |
| **Embeddings** | OpenAI CLIP (ViT-B/32) | Image-to-vector transformation |
| **Vector DB** | Qdrant | Similarity search engine |
| **LLM / Vision** | Google Gemini (GenAI) | Visual reasoning & Grounding |
| **Web Research**| DuckDuckGo-Search API | Free external grounding evidence |
| **Scraper** | BeautifulSoup / HTTPX | Automated data collection |

---

## 5. Appendix: Key Research Questions & Design Rationale

| Question | Research Rationale |
| :--- | :--- |
| **Why have structured JSON?** | To act as a "Ground Truth." Even if the image match is found, the system needs clean data to verify against real-world evidence. |
| **Do we still need raw TXT files?** | Yes. For **Data Lineage**. Keeping the original source allows for future re-processing without re-scraping. |
| **Why use a Search Library instead of Gemini's built-in Search?** | Cost and Token Efficiency. Offloading the search to a free Python library saves massive token quotas. |
| **Private Catalog vs. Global Search?** | The system supports a **Dual-Mode Engine**. Private Catalog for controlled local searches, and Open World for identifying any AC unit globally via web-bridge. |

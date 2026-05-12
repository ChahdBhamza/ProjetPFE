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

### Step 5: Technical Identity Standardization & Deduplication
To transition from "raw scraped data" to a "high-precision technical library," a **Technical Identity Standard** was implemented.
*   **The Problem**: Retailers often list the same AC unit multiple times with slightly different titles (e.g., "Gree 12k" vs "Gree 12000 BTU Inverter").
*   **The Solution**: Implemented a normalization engine that extracts a unique **Technical Fingerprint** (Brand + BTU + Inverter + Mode).
*   **Result**: Reduced a noisy dataset of 133+ records into a refined, deduplicated library of **~60 unique technical identities**. This ensures the RAG system never returns redundant results.

### Step 6: Multi-Source Web Grounding Architecture (Independent)
To solve the "Limited Database" problem, a separate **Web Intelligence Explorer** was developed.
*   **Zero-Token Research**: Uses a free Python search engine (DuckDuckGo) to cross-reference product specs against the live internet.
*   **Grounding Logic**: Implemented a Regex-based truth engine that extracts BTU from web snippets to verify product authenticity without LLM costs.

### Step 7: Complete Edge-AI Migration (Self-Hosted Architecture)
The project achieved full independence from cloud-based APIs (Gemini) by migrating all intelligence tasks to a **Local Vision-Language Model (VLM)**.
*   **Model**: Moondream2 (via Ollama).
*   **Phase 1 (The Reader)**: Local extraction of brands and technical specifications directly from pixels.
*   **Phase 2 (The Judge)**: Local visual verification to confirm the match between the user's photo and the technical database index.
*   **Thesis Impact**: Demonstrates a "Zero-Cost, 100% Private, 100% Offline" architecture, which is a significant advancement for mobile/outdoor equipment detection systems.

### Step 8: Multi-Site Knowledge Fusion
The data pipeline was expanded to synchronize data from multiple major retailers (Tunisianet + Spacenet).
*   **Cross-Site Merging**: Standardized technical IDs allow the system to merge a specs-sheet from one site with the price from another, creating a "SuperSpec" for each AC model.

---

## 4. Key Technologies Summary
| Component | Technology | Role |
| :--- | :--- | :--- |
| **Backend** | FastAPI / Uvicorn | High-performance API hosting |
| **Embeddings** | OpenAI CLIP (ViT-B/32) | Image-to-vector transformation |
| **Vector DB** | Qdrant | Similarity search engine |
| **Local VLM** | Moondream2 (Ollama) | Local visual reasoning & brand extraction |
| **Cloud LLM** | Google Gemini (GenAI) | *Verification* and fallback search grounding |
| **Web Research**| DDGS (DuckDuckGo Search) | Free external grounding evidence |
| **Scraper** | BeautifulSoup / Requests | Multi-site concurrent data collection |

---

## 5. Appendix: Key Research Questions & Design Rationale

| Question | Research Rationale |
| :--- | :--- |
| **Why use a Technical Identity (Deduplication)?** | To ensure search accuracy. Multiple listings for the same hardware dilute the vector space; merging them creates a stronger, unique signal. |
| **Do we still need raw TXT files?** | Yes. For **Data Lineage**. Keeping the original source allows for future re-processing without re-scraping. |
| **Why use a Search Library instead of Gemini's built-in Search?** | Cost and Token Efficiency. Offloading the search to a free Python library saves massive token quotas. |
| **Why move to a Local LLM (Moondream)?** | Privacy and Offline Reliability. Proves that sophisticated Vision-RAG can exist outside the "Cloud" ecosystems. |

---

## 6. Development Log & Implementation Steps (Phase 2-4)
1.  **Refactoring for Speed**: Optimized CLIP embedding generation with a 50% speed increase.
2.  **Metadata Extraction**: Built a custom Python script to convert 133 unstructured TXT files into precise JSON schemas.
3.  **UI Evolution**: Iterated from a basic upload form to a premium, dark-mode dashboard with interactive search feedback.
4.  **Zero-Token Shield**: Implemented logic to check for web grounding evidence *only* when requested, protecting the system from redundant search requests.

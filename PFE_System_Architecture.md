# PFE Project: Multi-Category Equipment Detection & RAG
**Architecture & Scalability Plan**

## 1. Current Dataset Status (Post-Cleanup)
*   **Total Products:** 336 (Air Conditioners).
*   **Unique Brands:** 35.
*   **Data Sources:** 4 Web Scrapers (Jumbo, Zoom, Mega, Tunisianet) + Local Ground Truth (`dataequipment`).
*   **Key Achievement:** Successfully deduplicated 398 entries into 336 unique units using "Fuzzy Brand+BTU Matching."
*   **Multimodal Storage:** Every product has a dedicated folder in `Equipment/` containing:
    *   `images/`: Cleaned product photo.
    *   `text/`: Human-readable tech summary.
    *   `json/`: Full machine-readable metadata.

## 2. Technical Architecture (The "Fast RAG" Stack)

### A. The AI Engine (Qdrant)
*   **Vector Space:** CLIP (openai/clip-vit-base-patch32).
*   **Collection:** `climatiseurs_v2`.
*   **Strategy:** Stores **Image Embeddings** (512-dim). 
*   **Benefit:** Enables both **Visual Search** (Photo -> Product) and **Semantic Search** (Text -> Product) in one database.

### B. The Memory (MongoDB Atlas)
*   **Role:** Dynamic Storage.
*   **Collections:**
    *   `detections`: Logs every search event (Timestamp, Image URL, Result).
    *   `products` (Planned): Migration of the JSON catalog to MongoDB for faster retrieval and cloud scalability.
    *   `users`: Accounts and favorites.

### C. The Knowledge Base (Cloud Storage)
*   **Role:** High-speed asset delivery.
*   **Suggestion:** Move `Equipment/` photos to **Cloudinary** or **S3**.
*   **Optimization:** Use **WebP** format and **CDN** caching to ensure instant image loading on Flutter.

## 3. High-Performance Video Workflow (Flutter)
To make the detection "feel" real-time:
1.  **Frame Extraction:** Flutter app extracts 3-5 clear keyframes from the video stream.
2.  **Parallel Upload:** Frames are sent to the Backend asynchronously.
3.  **Gemini 1.5 Flash:** Used for rapid multimodal verification of the Qdrant matches.
4.  **Async RAG:** The specs are retrieved from Mongo/Local-Files while the AI is still "thinking," saving precious milliseconds.

## 4. Scalability for New Categories
As the project expands to Fridges, Washing Machines, etc.:
*   **Qdrant:** Use separate collections (e.g., `refrigerateurs`, `machines_a_laver`).
*   **MongoDB:** Use a `category` field in the `products` collection.
*   **Storage:** Cloud storage scales automatically without filling up server disk space.

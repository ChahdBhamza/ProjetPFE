# Cybersight — Complete Technical Codebase Explanation

## 1. What the Project Does

**Cybersight** is a mobile AI system for forensic equipment detection and specification extraction.
A user films household appliances (AC, fridge, microwave, laptop, monitor) with their phone. The app automatically:

1. Extracts the sharpest, most relevant frames from the video
2. Detects what equipment is present using two AI models (YOLO + Roboflow)
3. Identifies the brand and model using a vision LLM (Groq Llama 4 Scout)
4. Searches the web and extracts full technical specifications using another LLM (Groq Llama 3.3)
5. Saves everything to a MongoDB inventory accessible from the app

---

## 2. Architecture Overview

```
Flutter App (Android/iOS)
        │  HTTP via Dio  (USB/ADB or WiFi)
        ▼
FastAPI Backend  ──► MongoDB (sessions, inventory, spec cache)
        │
        ├─ [1] FFmpeg          → extracts 1 frame/sec from video
        ├─ [2] YOLOv5 (local)  → fast scan: which frames contain equipment?
        ├─ [3] Roboflow (cloud) → high-quality detection on best frames
        ├─ [4] Groq Vision LLM → brand + model identification (2-pass)
        └─ [5] DuckDuckGo + BeautifulSoup + Groq LLM → spec extraction
```

---

## 3. Backend — File by File

### `backend/main.py` — Entry Point

- Creates the FastAPI app named *"Cybersight Forensic API v2.0.0"*
- On startup (`lifespan`), loads the YOLOv5 model **once** into memory (expensive operation, done once and reused)
- Adds **CORS middleware** so the Flutter app can call it from any origin (important for mobile dev via ADB reverse USB on port 8000)
- Mounts all routes under `/api`

---

### `backend/app/api/routers/video.py` — Main API Router

4 key endpoints:

| Endpoint | What it does |
|---|---|
| `POST /video/script-process` | Receives the video file, runs the full pipeline |
| `POST /video/process-selected-frames` | Runs Roboflow + brand ID on already-extracted frames |
| `POST /video/get-specs` | Runs the spec extraction pipeline for a known brand/model |
| `POST /video/extract-frames` | Simpler frame extraction with optional auto-search |

The main `script-process` flow:
1. Saves the uploaded video to `sessions/<session_id>/`
2. Runs **FFmpeg** to extract 1 frame per second → `sessions/<session_id>/raw/frame_XXXX.jpg`
3. Deletes `video.mp4` immediately after extraction to save disk space
4. Calls `smart_extract()` to pick the best "hero" frames
5. Returns those hero frames as base64 images to Flutter

---

### `backend/app/scripts/smart_extract.py` — Intelligent Frame Selector

The most algorithmically complex part of the project.

#### Pass 1 — YOLO Local Scan (fast, free)
- Scans all extracted frames using the local YOLOv5 model with 6 threads in parallel
- Tags each detection with a **composite quality score**:
  ```
  score = 0.38 × object_sharpness
        + 0.22 × frame_sharpness
        + 0.22 × confidence
        + 0.10 × centering
        + 0.08 × area
  ```
- Builds a candidate pool of all detected equipment

#### Pass 2 — Roboflow Cloud Probe (slower, higher quality)
- Sends only the **best ~12 frames** to Roboflow (those YOLO liked + sharpest + temporal spread)
- This saves money and latency vs sending all frames
- Roboflow returns higher-quality bounding boxes and annotated images

#### Hero Selection
- Picks the best 1–2 "hero" frames per category (e.g., 1 fridge, 2 laptops max)
- Applies IoU deduplication: if two detected boxes overlap >50% on the same frame, keeps only the better one
- Applies a **YOLO safeguard**: if Roboflow labels something "air conditioner" but YOLO clearly saw a "laptop" overlapping it (IoU > 0.55), the YOLO label wins
- Saves heroes as `hero_1_air_conditioner_f0023.png` — the filename encodes both the class and the original frame number for downstream use

---

### `backend/app/services/workflow_service.py` — Roboflow Workflow Runner

Runs the Roboflow cloud workflow on a single hero image then calls the brand identifier:

1. Extracts the equipment type hint from the filename (`hero_1_tv_monitor_f0023.png` → `"monitor"`)
2. Finds the **clean, unannotated** raw frame to send to Roboflow (avoids green annotation boxes confusing the LLM)
3. Calls the Roboflow `custom-workflow-3` workflow with **retry logic** (exponential backoff: 2s, 4s, 6s on 503 errors)
4. Filters detections by confidence threshold (AC: ≥45%, all others: ≥60%)
5. Keeps only the single highest-confidence detection and redraws one clean bounding box using OpenCV
6. Calls `frame_detector.process_frame()` for brand/model identification

---

### `backend/app/services/frame_detector.py` — Forensic Vision Pipeline

Uses Groq's Llama 4 Scout multimodal LLM for brand and model identification.

#### Step 1 — Classical CV Preprocessing
- `detect_dominant_object()`: uses Canny edge detection + morphological dilation + contour finding to locate the largest object in the frame (filtered to 8%–97% of frame area to exclude tiny noise and full-frame fills)
- `enhance_crop_for_ocr()`: upscales the crop to ≥600px, applies **CLAHE** (Contrast-Limited Adaptive Histogram Equalization) for better brand/label visibility, then sharpens with a Laplacian kernel

#### Pass 1 — Fast Type Detection (1 LLM call)
- Sends 1 image to Groq Llama 4 Scout
- Asks: what type of equipment? Is a brand logo visible? What is the preliminary brand/model?
- Uses `response_format: json_object` → parsed into a `Pass1Result` Pydantic model for strict validation
- **Skipped entirely** when a YOLO type hint is available (saves one API call)

#### Pass 2 — Forensic Identification (1 LLM call, 2 images)
- Sends **2 images** to Groq: the full frame + the enhanced crop
- Builds an equipment-specific prompt — different instructions per type (AC, fridge, laptop, etc.) telling the model exactly where to look for model numbers (stickers, engraving, molded plastic, front badges)
- Forces the model to state "READ from Image 1/2: [exact text]" OR "DEDUCED from: [visual features]" — ensures transparency about whether it read a label or inferred from training
- Returns: brand, model candidates with confidence scores, visual cues observed

---

### `backend/app/services/spec_service.py` — Specification Extraction Pipeline

A 4-step pipeline to find and extract technical specifications from the web.

#### Step 0 — MongoDB Cache Lookup
- If specs for this brand+model are already stored, return them instantly — no search, no scrape, no LLM needed

#### Step 1 — DuckDuckGo Multi-Query Search
- Runs 3 targeted queries:
  1. Technical specifications / fiche technique
  2. Official manufacturer / datasheet page
  3. Tunisian retailers (tunisianet.com, mega.tn, mytek.tn)
- Deduplicates by URL → up to 9 unique candidate URLs

#### Step 2 — Parallel BeautifulSoup Scraping
- Scrapes up to 4 URLs **concurrently** (ThreadPoolExecutor, 6 workers)
- Removes DOM noise (scripts, nav, footer, ads, SVGs)
- Prioritizes `<table>` and `<dl>` spec tables, then spec-class divs
- Caps each page at 6,000 chars, assembles content from the best 3 pages

#### Step 3 — Groq LLM Extraction
- Sends scraped text (capped at 2,000 chars) to Groq Llama 3.3 70B
- Uses a **canonical schema** per equipment category — the model is told exactly which fields to fill
- `response_format: json_object` → structured extraction, no hallucination
- Key rule: `exact_model_reference` can ONLY be copied from the scraped text, never invented

#### Step 4 — Normalization & Quality Scoring
- Coerces field types: `capacity_btu` → `int`, `weight_kg` → `float`, `smart_wifi` → `bool`
- Fills all schema keys with `null` if not found
- Detects and corrects annual energy values reported monthly or daily (scales by ×12 or ×365)
- Scores quality: ≥7 fields = "high", ≥4 = "medium", <4 = "low"
- Caches the result to MongoDB for future lookups

---

### `backend/app/database.py` — MongoDB Interface

Key collections:

| Collection | Purpose |
|---|---|
| `users` | Accounts, hashed passwords, JWT tokens |
| `sessions` | Scan sessions (start time, user, device, status, hero frame) |
| `detections` | Raw AI detection logs per session |
| `inventory` | Saved equipment items |
| `spec_cache` | Cached specs by brand + model + category |

---

## 4. Frontend — File by File

### `frontend/lib/main.dart` — Flutter Entry Point
- Loads `.env` (API base URL, feature flags)
- Wraps the whole app in `MultiProvider` with 2 providers:
  - `DetectionProvider` — manages detection state and results
  - `AuthProvider` — manages login/logout state
- Configures named routes with animated page transitions (fade + subtle slide + scale, 460ms with `easeInOutCubicEmphasized`)

---

### `frontend/lib/features/app/presentation/providers/detection_provider.dart`
The **state machine for detection**:

- States: `idle → loading → success / error`
- `detectFromVideo(File)`: calls `ApiService.detectFromVideo()`, stores result, notifies all listening widgets
- `saveCurrentToInventory()`: calls `ApiService.saveToInventory()` with the current result
- Uses `ChangeNotifier` — all widgets listening via `context.watch<DetectionProvider>()` rebuild automatically when state changes

---

### `frontend/lib/core/network/api_service.dart` — HTTP Client (Dio)
- Base URL loaded from `.env`
- `detectFromVideo()`: sends video as multipart form data to `/api/video/script-process`
- `saveToInventory()`: POST to `/api/inventory/save`
- Attaches JWT Bearer token to all authenticated requests

---

### `frontend/lib/features/auth/` — Authentication Pages
| File | Purpose |
|---|---|
| `splash_page.dart` | Launch screen, checks existing session |
| `sign_in_page.dart` | Email + password login |
| `sign_up_page.dart` | Account creation |
| `forgot_password_page.dart` | Password reset request |
| `check_email_page.dart` | "Check your inbox" confirmation |
| `reset_password_page.dart` | Set new password via token |
| `auth_success_page.dart` | Redirect after successful login |

---

### `frontend/lib/features/app/presentation/pages/` — Main App Pages
| File | Purpose |
|---|---|
| `app_shell.dart` | Bottom nav shell wrapping all main tabs |
| `equipment_page.dart` | Video upload + detection trigger |
| `equipment_detail_page.dart` | Full spec display for a detected item |
| `inventory_page.dart` | User's saved equipment list |
| `profile_page.dart` | User account info |
| `admin_dashboard_page.dart` | Admin controls |
| `script_lab_page.dart` | Developer testing sandbox |
| `save_success_page.dart` | Confirmation after saving to inventory |

---

## 5. Full End-to-End Flow (One Scan Session)

```
User films appliance with phone
        │
        ▼
Flutter picks video file (ImagePicker or Camera)
        │
        ▼
DetectionProvider.detectFromVideo() called
        │  multipart POST /api/video/script-process
        ▼
Backend:
  1. Saves video.mp4 to sessions/lab_XXXXXXXX/
  2. FFmpeg: extracts frames at 1 fps → raw/frame_0001.jpg...
  3. Deletes video.mp4 to free disk space
  4. smart_extract():
     a. YOLO scans all frames in 6 threads (local, ~0.02s/frame)
     b. Builds quality-scored candidate pool
     c. Selects ~12 best frames to send to Roboflow
     d. Roboflow returns annotated detections (cloud accuracy)
     e. YOLO safeguard: overrides wrong Roboflow labels via IoU check
     f. Hero selection: best 1–2 frames per equipment category
     g. Saves: hero_N_CLASS_fXXXX.png
  5. Returns hero frames as base64 to Flutter
        │
        ▼
Flutter shows hero frames to user
User taps "Analyse" on a frame
        │
        ▼
POST /api/video/process-selected-frames
  For each hero frame (up to 6 concurrent):
    WorkflowService.run_specialized_workflow():
      - Finds clean raw frame (unannotated)
      - Calls Roboflow custom-workflow-3 (with retry on 503)
      - frame_detector.process_frame():
          • Classical CV: detect dominant object bounding box
          • Crop + CLAHE enhancement
          • Groq Llama 4 Scout Pass 1: equipment type (skipped if YOLO hint)
          • Groq Llama 4 Scout Pass 2: brand + model (2 images sent)
      - Returns forensic_data: {brand, model_candidates, visual_cues}
  Logs detection to MongoDB
  Returns per-frame results to Flutter
        │
        ▼
Flutter shows brand + model to user
User taps "Get Specifications"
        │
        ▼
POST /api/video/get-specs
  SpecService.get_full_identity():
    0. MongoDB cache lookup → instant return if hit
    1. DuckDuckGo: 3 queries → up to 9 URLs
    2. BeautifulSoup: scrape 4 URLs in parallel, keep best 3
    3. Groq Llama 3.3 70B: extract specs against canonical schema
    4. Normalize types + score quality
    5. Cache result to MongoDB
  Returns full spec dict
        │
        ▼
Flutter displays specification card
User taps "Save to Inventory"
        │
        ▼
POST /api/inventory/save → stored in MongoDB inventory
```

---

## 6. Key Technical Decisions

| Decision | Why |
|---|---|
| **YOLOv5 local + Roboflow cloud hybrid** | YOLO is free and fast for filtering; Roboflow is slower/costly so only the best frames are sent |
| **Hero filename encodes class + frame ID** | `hero_1_tv_monitor_f0023.png` lets downstream code recover equipment type and find the clean raw frame without reprocessing |
| **Pass 1 skipped when YOLO hint exists** | Saves one LLM API call per frame — YOLO already confirmed the equipment type |
| **Two images sent to Pass 2** | Full frame has stickers/labels; enhanced crop has the brand logo — the LLM sees both for maximum information |
| **Groq Llama 4 Scout for vision** | Fastest available multimodal model on Groq — low latency is critical for mobile UX |
| **Groq Llama 3.3 70B for text extraction** | Larger model is better at reading and structuring scraped web spec tables |
| **Parallel scraping with ThreadPoolExecutor** | Was sequential with 10s waits before — parallelism cut the spec pipeline from ~30s to ~5s |
| **MongoDB spec cache** | Same model (e.g. Samsung AR12TX) may be scanned multiple times — cache avoids redundant search+scrape+LLM |
| **CLAHE + Laplacian sharpening** | Standard forensic image enhancement technique to make barely-visible brand logos readable by the LLM |
| **Provider pattern in Flutter** | Simple reactive state management without over-engineering; `ChangeNotifier` + `context.watch` is idiomatic Flutter |
| **YOLO safeguard via IoU** | Roboflow occasionally mislabels a laptop as an AC — if YOLO saw a laptop overlapping that box (IoU > 0.55), YOLO's label wins |
| **Composite quality score for hero selection** | Prevents a sharp but low-confidence frame from beating a blurry but high-confidence one; balances 5 signals |

---

## 7. Technology Stack Summary

### Backend
| Layer | Technology |
|---|---|
| Web framework | FastAPI + Uvicorn |
| Object detection (local) | YOLOv5 (PyTorch) |
| Object detection (cloud) | Roboflow inference SDK |
| Vision LLM | Groq — meta-llama/llama-4-scout-17b-16e-instruct |
| Text LLM | Groq — llama-3.3-70b-versatile |
| Web scraping | BeautifulSoup4 + requests |
| Web search | DuckDuckGo Search (ddgs) |
| Image processing | OpenCV, Pillow |
| Video processing | FFmpeg via imageio-ffmpeg |
| Database | MongoDB (PyMongo) |
| Authentication | JWT (python-jose) + passlib (bcrypt) |

### Frontend
| Layer | Technology |
|---|---|
| Framework | Flutter (Dart 3.0+) |
| State management | Provider (ChangeNotifier) |
| HTTP client | Dio |
| Media input | image_picker |
| Secure storage | flutter_secure_storage |
| Theming | Google Fonts + Material 3 |

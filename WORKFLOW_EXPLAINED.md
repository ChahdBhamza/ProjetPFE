# Cybersight — File-by-File Workflow Explanation

## Where it Starts — Flutter Side

### `main.dart`
App boots, loads `.env`, creates the two providers (`DetectionProvider`, `AuthProvider`), and shows the splash screen.

### `detection_provider.dart`
The user picks a video file. The provider calls `ApiService.detectFromVideo()` and sets state to `loading` — all UI widgets listening rebuild to show a spinner.

### `api_service.dart`
Wraps the video in a multipart HTTP request and sends it to `POST http://localhost:8000/api/video/script-process`. This is the hand-off to the backend.

---

## Backend Entry — FastAPI

### `main.py`
Receives every request. The `lifespan` function already loaded YOLOv5 into memory on startup. Routes the request to the video router.

### `app/api/router.py`
Just a router aggregator — forwards `/video/*` requests to `video.py`.

---

## Stage 1 — Frame Extraction

### `app/api/routers/video.py` → `script_process_endpoint()`

1. Saves the video to `sessions/lab_XXXXXXXX/video.mp4`
2. Runs **FFmpeg** via subprocess — extracts 1 frame/sec into `sessions/.../raw/frame_0001.jpg`, `frame_0002.jpg` ...
3. Deletes `video.mp4` immediately to save disk space
4. Hands off to `smart_extract()`

---

## Stage 2 — Smart Frame Selection

### `app/scripts/smart_extract.py` → `smart_extract()`

This is the core intelligence of the pipeline. It runs in two passes:

**Pass 1 — YOLO (local, 6 threads)**
- Reads every raw frame from disk
- Resizes to 640px, sends to `YOLOv5Service.detect()`
- Each hit gets a composite quality score (sharpness + confidence + centering + area)
- Builds a pool of all candidate detections

### `app/services/yolov5_service.py`
- Wraps the locally loaded YOLOv5 model
- Returns bounding boxes + class names + confidence scores

**Pass 2 — Roboflow (cloud, 5 threads)**
- Picks the ~12 best frames from the YOLO pool
- Sends each to `RoboflowService.detect()`

### `app/services/roboflow_service.py`
- Calls the Roboflow cloud API
- Returns higher-quality detections + an annotated image

**Back in `smart_extract()`:**
- Applies the YOLO safeguard (IoU check to override wrong Roboflow labels)
- Runs hero selection — best 1–2 frames per equipment category
- Saves them as `sessions/.../final_shots/hero_1_air_conditioner_f0023.png`

**Back in `video.py`** — returns all hero frames as base64 to Flutter.

---

## Stage 3 — Brand & Model Identification

Flutter shows the hero frames. User taps "Analyse". Flutter calls `POST /api/video/process-selected-frames`.

### `app/api/routers/video.py` → `process_selected_frames_endpoint()`
- Runs up to 6 hero frames concurrently (asyncio semaphore)
- For each frame calls `WorkflowService.run_specialized_workflow()`

### `app/services/workflow_service.py`
1. Extracts the equipment type from the hero filename (`tv_monitor`, `laptop`, etc.) as a hint
2. Finds the clean unannotated raw frame (so the LLM doesn't see the green box)
3. Calls Roboflow one more time on the clean frame for final detection
4. Calls `frame_detector.process_frame()` passing the hint

### `app/services/frame_detector.py`
1. OpenCV reads the image, finds the dominant object bounding box (Canny edges + contours)
2. Crops and enhances the region (CLAHE + Laplacian sharpening)
3. **Pass 1** — skipped if YOLO hint exists (saves one API call)
4. **Pass 2** — sends 2 images (full frame + enhanced crop) to Groq Llama 4 Scout
5. Returns: `{ brand, model_candidates, visual_cues }`

### `app/services/rate_limiter.py`
Called before every Groq request — token bucket that paces calls to avoid hitting the rate limit.

**Back in `video.py`:**
- Wraps results into a standardised `equipment_result` dict
- Logs the detection to MongoDB via `app/database.py`
- Returns everything to Flutter

---

## Stage 4 — Specification Extraction

Flutter shows brand + model. User taps "Get Specs". Flutter calls `POST /api/video/get-specs`.

### `app/api/routers/video.py` → `get_specs_endpoint()`
Calls `SpecService.get_full_identity()`

### `app/services/spec_service.py` → `get_full_identity()`

| Step | What happens |
|---|---|
| Step 0 | Checks MongoDB cache via `database.py` → instant return if hit |
| Step 1 | `search_product_urls()`: 3 DuckDuckGo queries → up to 9 URLs |
| Step 2 | `scrape_page_content()`: scrapes 4 URLs in parallel (ThreadPoolExecutor), assembles up to 3 good pages |
| Step 3 | `extract_and_verify_specs()`: sends 2,000 chars of scraped text to Groq Llama 3.3 70B with the canonical schema for the equipment type → structured JSON back |
| Step 4 | `_normalize_specs()`: coerces types, fills missing fields, scores quality, caches result to MongoDB |

### `app/services/equipment_schemas.py`
Referenced throughout `spec_service.py` — holds the canonical field schemas per equipment category (what fields a fridge has vs a laptop vs an AC).

Returns full spec dict to Flutter.

---

## Where it Ends — Flutter Side

### `detection_provider.dart`
Receives the final `equipment_result`, sets state to `success`, notifies all listeners.

### `equipment_detail_page.dart`
Rebuilds and displays the full spec card — brand, model, all spec fields, source quality badge, annotated image.

### `inventory_page.dart`
User taps "Save" → `DetectionProvider.saveCurrentToInventory()` → `ApiService.saveToInventory()` → `POST /api/inventory/save` → stored in MongoDB.

---

## Full File Flow Map

```
main.dart
  └─► detection_provider.dart
        └─► api_service.dart
              └─► video.py  (POST /video/script-process)
                    ├─► FFmpeg — extracts frames to raw/
                    └─► smart_extract.py
                          ├─► yolov5_service.py     Pass 1 — local scan (6 threads)
                          └─► roboflow_service.py   Pass 2 — cloud probe (5 threads)
                          └─► saves hero_N_CLASS_fXXXX.png
                    └─► returns base64 hero frames to Flutter
                                    │
              video.py  (POST /video/process-selected-frames)
                    └─► workflow_service.py
                          └─► frame_detector.py
                                ├─► rate_limiter.py
                                ├─► OpenCV  (bbox + CLAHE crop)
                                ├─► Groq Llama 4 Scout  Pass 1  (skipped if YOLO hint)
                                └─► Groq Llama 4 Scout  Pass 2  (2 images → brand + model)
                    └─► database.py  (log detection)
                    └─► returns forensic_data to Flutter
                                    │
              video.py  (POST /video/get-specs)
                    └─► spec_service.py
                          ├─► database.py          Step 0 — cache lookup
                          ├─► DuckDuckGo           Step 1 — 3 search queries
                          ├─► BeautifulSoup        Step 2 — scrape 4 URLs in parallel
                          ├─► equipment_schemas.py Step 3 — canonical field schema
                          ├─► rate_limiter.py
                          ├─► Groq Llama 3.3 70B   Step 3 — structured extraction
                          └─► database.py          Step 4 — cache result
                    └─► returns full spec dict to Flutter
                                    │
        detection_provider.dart  (state → success)
              └─► equipment_detail_page.dart  (renders spec card)
                    └─► inventory_page.dart  (save to MongoDB)
```

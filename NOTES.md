# Dev Notes

---

## Concepts

### CORS — Cross-Origin Resource Sharing

**The problem it solves:** Browsers block JavaScript from making requests to a *different origin* (Same-Origin Policy).
An "origin" = `scheme + domain + port`. `http://localhost:3000` vs `http://localhost:8000` → different origins.

**What CORS does:** Lets the server tell the browser which origins are allowed, via response headers.
**Key point:** CORS is browser-only. Native mobile apps and Postman are not affected.

---

### ADB — Android Debug Bridge

A command-line tool that lets your PC talk to an Android device.

- `adb logcat` — real-time logs from the device
- `adb reverse tcp:8000 tcp:8000` — makes `localhost:8000` on the **phone** point to `localhost:8000` on the **PC**, so Flutter can reach FastAPI without needing your IP address

---

---

# Backend

## `backend/main.py` — App Entry Point

Creates the FastAPI app, adds CORS middleware, mounts all routes under `/api`.
On **startup**: loads the YOLOv5 model into memory so the first scan request doesn't have a cold-start delay.
Runs on port `8000` via uvicorn.

---

## `backend/app/api/router.py` — Route Aggregator

Collects the 3 routers and registers them into one `api_router`:

| Router | Prefix |
|---|---|
| `auth.router` | `/auth` |
| `inventory.router` | `/inventory` |
| `video.router` | `/video` |

`main.py` mounts this at `/api`, so all final paths are `/api/auth/...`, `/api/inventory/...`, `/api/video/...`

---

## `backend/app/api/dependencies.py` — JWT Guard

A reusable FastAPI dependency (`verify_token`) that protects any endpoint.
Any route with `Depends(verify_token)` automatically:
1. Reads the `Authorization: Bearer <token>` header
2. Decodes and validates the JWT using the secret key
3. Returns the user's email from the token payload

If the token is missing, expired, or tampered → returns `401` immediately.

---

## `backend/app/api/routers/auth.py` — Authentication Router

All routes under `/api/auth`. Uses JWT tokens (1-week expiry) and pbkdf2_sha256 password hashing.

| Endpoint | What it does |
|---|---|
| `POST /auth/signup` | Creates user, hashes password, returns JWT |
| `POST /auth/login` | Verifies password, returns JWT. Rejects Google-only accounts |
| `POST /auth/google` | Creates or finds Google user (stores `"GOOGLE_OAUTH_USER"` as hash), returns JWT |
| `POST /auth/forgot-password` | Generates 6-digit OTP, saves to MongoDB, sends via Gmail SMTP |
| `POST /auth/verify-otp` | Validates OTP is correct and not expired (10 min window) |
| `POST /auth/reset-password` | Re-validates OTP, hashes and saves new password, clears OTP |

**Security:** Forgot-password always returns success even for unknown emails (prevents email enumeration). OTP deleted after use.

---

## `backend/app/api/routers/inventory.py` — Inventory Router

All routes under `/api/inventory`. Every endpoint requires a valid JWT.

| Endpoint | What it does |
|---|---|
| `POST /inventory/save` | Saves a detected item to the user's inventory in MongoDB |
| `GET /inventory/list` | Returns all user items. Admins get junk-filtered results (unknown brand+model removed) |
| `POST /inventory/filter` | Same as list but with filter criteria (category, brand, price, BTU) |
| `GET /inventory/history` | Returns scan sessions sorted newest-first |
| `GET /inventory/my-stats` | Returns 3 numbers: total scans, items detected, items saved |
| `GET /inventory/admin/stats` | Admin-only. Full dashboard: totals, categories, top brands, per-operator stats, 7-day chart, quality alerts |

---

## `backend/app/api/routers/video.py` — Video Processing Router

All routes under `/api/video`. The core AI pipeline lives here.

### `POST /video/extract-frames`
Old simple flow. Takes a video upload, extracts key frames using `VideoService`, optionally runs `WorkflowService` on the best frame to get brand/model. Returns frames as base64.

### `POST /video/script-process`
The main production flow (Script Lab). Step by step:
1. Saves the uploaded video to a unique session folder (`sessions/lab_XXXX/`)
2. Runs **FFmpeg** to extract 1 frame/second as JPEGs into `raw/`
3. Deletes the video file (saves disk space)
4. Runs **`smart_extract`** (YOLO + Roboflow hybrid) to pick the best "hero" frames per equipment category
5. Returns the hero frames as base64 to Flutter
6. Records the scan session start/end in MongoDB

### `POST /video/process-selected-frames`
Takes a list of hero frame filenames the user selected, runs `WorkflowService` on each one in parallel (up to 6 concurrent), logs each detection to MongoDB, returns results with brand/model identity.

### `POST /video/get-specs`
Takes brand + model + equipment type, runs the full `SpecService` pipeline (search → scrape → extract → normalize), returns complete equipment specs.

Also contains `build_equipment_result()` — a shared helper that converts raw `frame_detector` output + `spec_service` output into the standardised `equipment_result` dict that Flutter expects.
Session cleanup: `_purge_old_sessions()` deletes session folders older than 24h on every new upload.

---

## `backend/app/database.py` — MongoDB Service

One class `MongoService` wrapping all DB operations. A single shared instance `mongo_db` is created at the bottom and imported everywhere else.

**On startup**: connects to Atlas, pings to verify, creates 7 collections + indexes.

| Collection | Stores |
|---|---|
| `users` | accounts, password hashes, OTP fields for reset |
| `detections` | raw AI detection events |
| `inventory` | saved equipment items per user |
| `auth_sessions` | login history |
| `scan_sessions` | scan start/end/status |
| `system_logs` | app-level logs |
| `spec_cache` | cached AI spec results (instant re-lookup by brand+model+category) |

**Key design:** Every method starts with `if not self.client: return False/None/[]` — graceful degradation if MongoDB is down.

Key methods: `create_user`, `find_user_by_email`, `add_to_inventory`, `filter_user_inventory`, `save_reset_otp`, `get_reset_otp`, `clear_reset_otp`, `update_password`, `get_cached_specs`, `cache_specs`, `start_scan_session`, `end_scan_session`, `log_detection`

---

## `backend/app/schemas.py` — Pydantic Response Schemas

Defines the shape of API responses so FastAPI can validate and auto-document them.

| Schema | Used by |
|---|---|
| `AuthResponse` | All auth endpoints — wraps `token` + `user` |
| `BaseResponse` | Simple success/error |
| `InventoryListResponse` | List and filter endpoints |
| `SearchResponse` | Video detection result |
| `ExtractFramesResponse` | Frame extraction endpoint |

---

## `backend/app/services/equipment_schemas.py` — Single Source of Truth for Equipment Types

Defines **what fields every equipment type has**. Used by 3 other files:
- `frame_detector.py` — tells the AI vision prompt what fields to look for
- `spec_service.py` — builds the extraction prompt from this schema
- Routers — guarantees consistent JSON shape sent to Flutter

**What's in it:**

- **5 Pydantic spec schemas** (one per type): `AirConditionerSpecs`, `RefrigeratorSpecs`, `MicrowaveSpecs`, `LaptopSpecs`, `MonitorSpecs` — each defines typed, optional fields with descriptions
- **`EQUIPMENT_SCHEMAS`** — plain dict version of all schemas (all values `None` = "not yet filled")
- **`LABEL_TO_CATEGORY`** — normalises any raw label to a canonical key (e.g. `"fridge"` → `"refrigerator"`, `"tv_monitor"` → `"monitor"`)
- **`CATEGORY_LABELS`** — human-readable names for prompt injection
- **`get_schema(type)`** — returns a fresh copy of the schema for a given type
- **`normalize_category(raw)`** — maps any raw label to the canonical category key
- **`schema_as_prompt_fields(type)`** — serialises the schema into a JSON hint string for Groq/Gemini to fill in

---

## `backend/app/services/frame_detector.py` — Classical CV + Groq Vision Identification

The file that identifies brand and model from a single image using computer vision + AI.

**Full pipeline:**
1. **OpenCV** — finds the dominant object in the frame using edge detection + contour analysis → draws a bounding box
2. **Crop** — crops the detected region and enhances it (CLAHE contrast + sharpening upscale) so logos and text are more readable
3. **Pass 1 (Fast)** — sends the full frame to **Groq Llama 4 Scout Vision**, asks: *what equipment type is this, is a brand visible, any model code visible?* Returns in ~1s
4. **Pass 2 (Forensic)** — sends **both** the full frame AND the enhanced crop to Groq with an equipment-specific deep-read prompt (different prompts for AC, fridge, microwave, laptop, monitor). The AI is told exactly where to look for model codes on each type and must either read text it sees or deduce from visual cues
5. Returns a structured dict with `brand`, `equipment_category`, `model_candidates`, `visual_cues`

**Optimisation:** If a `yolo_type_hint` is passed (from the filename, e.g. `hero_1_microwave_f0042.png`), Pass 1 is skipped entirely — the type is already known from YOLO.

**Rate limiting:** Every Groq call goes through `groq_throttle()` first.
**Retry logic:** Both passes retry up to 3 times with wait on 429 rate limit errors.

---

## `backend/app/services/workflow_service.py` — Roboflow Workflow Orchestrator

Runs the Roboflow cloud workflow on a single image and returns detections + brand/model identity.

**What it does per image:**
1. Extracts the `yolo_type_hint` from the hero filename (e.g. `hero_1_air_conditioner_f0012.png` → `"airconditioner"`)
2. Finds the matching clean raw frame (the unannotated source) so the AI reads a clean image, not one with boxes already drawn on it
3. Calls the **Roboflow custom workflow** (cloud detection + annotation) with retry on 503
4. Filters predictions by confidence (lower threshold for ACs, higher for others)
5. Keeps only the single highest-confidence detection and redraws it locally with one clean box
6. Calls `frame_detector.process_frame()` for brand/model forensic identification (Pass 2 only if type hint known)
7. Returns `raw_image`, `ai_image` (annotated), `forensic_data`, `has_ai`

---

## `backend/app/services/spec_service.py` — Equipment Spec Pipeline

Finds and extracts the full technical specifications for a detected device. This is a 4-step agentic pipeline:

**Step 1 — DuckDuckGo multi-query search**
Runs 3 targeted queries per device (specs query, manufacturer query, Tunisian retailer query). Deduplicates URLs and returns up to 9 results. Handles "model unknown" and "capacity-only" cases gracefully.

**Step 2 — BeautifulSoup scraping**
Scrapes the top 4 candidate URLs **in parallel** using `ThreadPoolExecutor`. Prioritises spec tables and definition lists over general page text. Caps each page at 6000 chars. Falls back to DDG snippets if all pages fail.

**Step 3 — Groq schema-aware extraction**
Sends the scraped content + the equipment's canonical schema to **Groq (llama-3.3-70b)**, asking it to fill every field. Rules enforced: no hallucination on `exact_model_reference` (must be copied verbatim from scraped text), typed values only (no units in numeric fields), booleans as `true/false`.

**Step 4 — Normalization**
Strips hallucinated keys, coerces types (int/float/bool), converts dimension dicts to strings, scales energy consumption if Groq returned monthly/daily instead of annual. Recomputes `fields_found` and `source_quality` (high ≥ 7 fields, medium ≥ 4, low < 4).

**Cache:** Before running the pipeline, checks MongoDB `spec_cache`. On a hit, returns instantly. On a miss and success, saves the result to cache.

---

## `backend/app/services/yolov5_service.py` — Local YOLOv5 Detector

Runs the local YOLOv5 model (loaded from `vision_engine/weights/yolov5s.pt`) on PIL images to detect equipment in video frames.

**What it does:**
- Loads YOLOv5 from the local repo folder (not PyPI) using `torch.hub.load`
- `detect(image)` — runs inference and returns only allowed classes: `laptop`, `refrigerator`, `microwave`, `oven`, `tvmonitor`, `tv`
- Maps `"oven"` → `"microwave"` and `"tvmonitor"` → `"tv"` for consistency
- **IoU deduplication**: if two bounding boxes overlap >50% on the same frame, only the higher-confidence one is kept — prevents a laptop screen from being detected as both `"laptop"` and `"tv"` simultaneously
- `draw_detections(image, detections)` — draws bounding boxes with labels on a PIL image

Used in `smart_extract.py` as Pass 1 (fast local scan of all frames before sending anything to the cloud).

---

## `backend/app/services/roboflow_service.py` — Roboflow Cloud Detector

Sends images to Roboflow cloud workflows via HTTP and returns detections + annotated images.

**What it does:**
- `detect(image, workflow_id)` — converts PIL image to base64, POSTs to Roboflow workflow API, retries on 429/503/500 with exponential backoff
- Returns normalized detections (converts Roboflow's center-x/y/w/h format to x1/y1/x2/y2) + annotated image as base64
- `draw_detections(image, detections)` — fallback local box drawing if the workflow returns no annotated image
- `decode_annotated_image(b64)` — decodes the Roboflow annotated image (handles data-URL prefix and dict formats)

Used in `smart_extract.py` as Pass 2 (cloud validation on the best frames YOLO found).

---

## `backend/app/services/rate_limiter.py` — Groq API Rate Limiter

A **token-bucket** rate limiter that smoothly paces Groq API calls instead of using fixed `time.sleep()` delays.

**How it works:**
- A bucket has a capacity of 6 tokens and refills at 25 tokens/minute
- Before every Groq call, `groq_throttle()` is called — it takes one token from the bucket
- If the bucket is full (first few calls), it returns instantly with no wait
- If the bucket is empty, it calculates exactly how long to wait for one token to refill and sleeps only that amount
- Thread-safe: uses a `threading.Lock` because `frame_detector` runs inside `run_in_threadpool` with multiple concurrent workers

**Why this matters:** Groq free tier is ~30 req/min. With 6 concurrent frame workers, without this limiter they'd all fire at once and hit 429 errors.

---

## `backend/app/scripts/smart_extract.py` — Hybrid Frame Extraction Engine

The brain of the video processing pipeline. Takes all the extracted raw frames from FFmpeg and picks the best "hero" frame per detected equipment category.

**Two-pass hybrid approach:**

**Pass 1 — Local YOLO scan (fast, all frames):**
All frames are scanned in parallel with `YOLOv5Service`. Builds a global pool of detections with quality scores. Quality is a composite of: object sharpness (Laplacian variance on the crop), frame sharpness, detection confidence, how centred the object is, and how much of the frame it occupies.

**Pass 2 — Roboflow cloud probes (accurate, selective):**
Instead of sending all frames to Roboflow (expensive), it selects a smart subset:
- Best frame per category from YOLO
- Top sharpest frames overall
- Evenly spaced frames for temporal coverage (catches things YOLO missed)
- Extra frames for fridge/microwave (harder to detect)
Up to 18 Roboflow calls total, run in parallel with `ThreadPoolExecutor`.

**Safeguards:**
- **YOLO IoU dedup** (in `yolov5_service.py`): drops duplicate boxes on the same frame
- **Roboflow safeguard**: if Roboflow labels something as `"air_conditioner"` but YOLO saw a `"laptop"` or `"refrigerator"` overlapping the same region (IoU > 55%) → override to trust YOLO
- **Cross-frame dedup**: if both `"computer"` and `"tv_monitor"` survived (same physical laptop screen), drop `"tv_monitor"`
- **Final IoU pass**: drops any heroes that still overlap >50% on the same frame
- **Hero limits**: most categories get 1 hero max; laptops/monitors get up to 2 (in case there are 2 devices)
- **Minimum quality + confidence thresholds** per category before a frame qualifies as a hero

**Output:** Hero frames saved as `hero_1_air_conditioner_f0012.png` — the filename encodes the category and original frame ID so `workflow_service.py` can find the clean raw frame later.

---

---

# Frontend

## `frontend/lib/main.dart` — App Entry Point

Loads `.env`, sets up 2 global providers (`AuthProvider`, `DetectionProvider`), defines all named routes with animated transitions.

| Route | Page |
|---|---|
| `/` | SplashPage |
| `/signin` | SignInPage |
| `/signup` | SignUpPage |
| `/forgot-password` | ForgotPasswordPage |
| `/check-email` | CheckEmailPage (receives email arg) |
| `/reset-password` | ResetPasswordPage (receives email + otp args) |
| `/app` | AppShell (main logged-in shell) |

---

## `frontend/lib/core/network/api_service.dart` — API Client

Single class that makes all HTTP calls using **Dio**. An interceptor automatically attaches the JWT token from secure storage to every request header.

Key methods: `signUp/signIn/googleSignIn`, `forgotPassword/verifyOtp/resetPassword`, `detectFromVideo`, `saveToInventory`, `fetchInventory`, `fetchMyStats`, `fetchAdminStats`, `getSpecs`

Base URL: reads from `.env`, falls back to `127.0.0.1:8000` on Android (works with `adb reverse`).

---

## `frontend/lib/core/network/api_exception.dart` — Error Wrapper

Simple class wrapping API errors with a `message` and optional `statusCode`. All `ApiService` methods throw this on failure so pages can catch it cleanly with typed error handling.

---

## `frontend/lib/features/auth/presentation/providers/auth_provider.dart` — Auth State

`ChangeNotifier` holding the logged-in user's state. Persists via **FlutterSecureStorage** (encrypted on-device).

- On app start: restores session from secure storage (auto-login)
- `signUp/signIn/signInWithGoogle` — calls ApiService, saves token + user info on success
- `logout` — clears secure storage + signs out of Google

---

## `frontend/lib/features/app/presentation/providers/detection_provider.dart` — Detection State

`ChangeNotifier` managing the scan lifecycle with 4 states: `idle / loading / success / error`.

- `detectFromVideo(file)` — sends video to backend, updates status
- `saveCurrentToInventory()` — saves current result to MongoDB
- `reset()` — clears back to idle

---

## `frontend/lib/features/app/presentation/pages/app_shell.dart` — Main Shell

Wrapper for all logged-in pages. Holds the bottom nav bar and switches between pages via `PageView`.

- Pages: Detect, Inventory, (Admin if isAdmin), Profile
- **Inactivity timer**: auto-logout after 10 minutes of no touch events
- Background animated arc waves drawn via `CustomPainter`

---

## Forgot Password Flow

6-digit OTP via Gmail SMTP. No deep links needed.

1. `forgot_password_page` → calls `/auth/forgot-password` → OTP stored in MongoDB, emailed
2. `check_email_page` → 6-digit numeric input → calls `/auth/verify-otp`
3. `reset_password_page` → new password + confirm → calls `/auth/reset-password`

**Gmail App Password:** myaccount.google.com > Security > 2-Step Verification > App passwords → paste into `.env` as `GMAIL_APP_PASSWORD`

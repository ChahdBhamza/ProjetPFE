# Pipeline — How It Works

Full execution order, file by file, from video upload to final specs.

---

## Phase 1 — Video → Hero Frames

> Triggered by: Flutter uploads a video

```
Flutter
  └── POST /api/video/script-process
        └── video.py  (endpoint)
              │
              ├── 1. Saves video to disk
              │         sessions/lab_XXXX/video.mp4
              │
              ├── 2. database.py
              │         start_scan_session()
              │
              ├── 3. FFmpeg  (external binary via imageio_ffmpeg)
              │         extracts 1 frame/sec
              │         → sessions/lab_XXXX/raw/frame_0001.jpg ...
              │         deletes video.mp4 after  (saves disk space)
              │
              └── 4. smart_extract.py  ← the heavy work
                        │
                        ├── PASS 1 — local, runs on ALL frames, parallel
                        │     yolov5_service.py → detect()
                        │     For each detection found:
                        │       frame_sharpness()     Laplacian variance on the full frame
                        │       object_sharpness()    Laplacian variance on the object crop only
                        │       composite_quality()   weighted score:
                        │                               38% object sharpness
                        │                               22% frame sharpness
                        │                               22% detection confidence
                        │                               10% how centred the object is
                        │                                8% how much of the frame it fills
                        │     → builds a global pool of scored detections
                        │
                        ├── selects probe frames for cloud:
                        │       best frame per category  (from YOLO pool)
                        │       top sharpest frames overall
                        │       evenly spaced frames  (catches things YOLO missed)
                        │       extra frames for fridge/microwave  (hardest to detect)
                        │       capped at 18 Roboflow calls total
                        │
                        ├── PASS 2 — cloud, selected frames only, parallel
                        │     roboflow_service.py → detect()
                        │     Filters predictions by confidence + minimum size thresholds
                        │     Safeguard:
                        │       if Roboflow labels something "air_conditioner"
                        │       but YOLO saw "laptop" overlapping the same region (IoU > 55%)
                        │       → override: trust YOLO, discard Roboflow label
                        │
                        ├── Hero selection:
                        │       picks best frame per category  (quality score + confidence)
                        │       enforces minimum frame gap between heroes of the same type
                        │       enforces hero count limits  (most types: 1, laptops/monitors: 2)
                        │       cross-frame dedup: if "computer" and "tv_monitor" both survived
                        │                          → drop "tv_monitor"  (same physical screen)
                        │       final IoU pass: drops heroes overlapping >50% on the same frame
                        │
                        └── saves heroes to disk:
                              sessions/lab_XXXX/final_shots/
                                hero_1_air_conditioner_f0012.png
                                hero_2_laptop_f0034.png
                              filename encodes: category + original frame ID

              └── video.py reads heroes, encodes as base64
              └── database.py → end_scan_session()
              └── returns hero frames to Flutter
```

---

## Phase 2 — Frame Selection → Brand & Model

> Triggered by: user picks frames in Flutter and taps "Analyse"

```
Flutter
  └── POST /api/video/process-selected-frames
        └── video.py  (endpoint)
              │
              ├── semaphore: max 6 concurrent frames at once
              │
              └── for each selected frame:
                    workflow_service.py → run_specialized_workflow()
                          │
                          ├── extracts yolo_hint from filename
                          │     "hero_1_air_conditioner_f0012.png"  →  "airconditioner"
                          │
                          ├── finds the CLEAN raw frame  (not the annotated hero)
                          │     sessions/lab_XXXX/raw/frame_0012.jpg
                          │     reason: AI reads text without bounding boxes covering logos
                          │
                          ├── Roboflow workflow  (for the annotated display image)
                          │     filters predictions by confidence
                          │     keeps only the single highest-confidence detection
                          │     redraws one clean local bounding box
                          │
                          └── frame_detector.py → process_frame()
                                    │
                                    ├── OpenCV — detect_dominant_object()
                                    │     Gaussian blur → Canny edge detection
                                    │     → dilate → find contours → largest valid box
                                    │
                                    ├── draw_bounding_box()
                                    │     draws annotated copy  (for display)
                                    │
                                    ├── enhance_crop_for_ocr()
                                    │     crops the detected region
                                    │     upscales to min 600px
                                    │     CLAHE contrast enhancement
                                    │     sharpening kernel
                                    │     → enhanced crop ready for AI reading
                                    │
                                    ├── if yolo_hint is known → SKIP Pass 1
                                    │
                                    ├── Pass 1  (only if equipment type is unknown)
                                    │     rate_limiter.py → groq_throttle()
                                    │     Groq Llama 4 Scout Vision
                                    │     sends: full frame
                                    │     asks: equipment type + is brand visible + any model code?
                                    │     validates with Pydantic Pass1Result schema
                                    │
                                    └── Pass 2  (always runs — forensic identification)
                                          rate_limiter.py → groq_throttle()
                                          Groq Llama 4 Scout Vision
                                          sends: full frame  +  enhanced crop  (2 images)
                                          uses equipment-specific prompt:
                                            airconditioner → look for capacity badge, side sticker
                                            refrigerator   → look for door frame plate, engraved plastic
                                            microwave      → look for back sticker, wattage label
                                            laptop         → look for bottom sticker, series badge
                                            monitor        → look for back panel sticker, screen size
                                          returns: brand, model_candidates, visual_cues, detected
                                          validates with Pydantic Pass2Result schema

              └── video.py → build_equipment_result()
                    merges frame_detector output into standardised Flutter dict:
                      identity  (brand, model, category, confidence, visual_cues)
                      specs     (empty at this stage)
                      meta      (source quality, ai_image, pipeline)

              └── database.py → log_detection()
              └── returns results to Flutter
```

---

## Phase 3 — Specs Lookup

> Triggered by: user taps "Get Specs" on a detected device

```
Flutter
  └── POST /api/video/get-specs
        └── video.py  (endpoint)
              └── spec_service.py → get_full_identity(brand, model, equipment_type)
                        │
                        ├── equipment_schemas.py
                        │     normalize_category()       raw label → canonical key
                        │                                "fridge" → "refrigerator"
                        │     schema_as_prompt_fields()  field hints for Groq prompt
                        │                                tells Groq exactly what fields to fill
                        │
                        ├── STEP 0 — cache check
                        │     database.py → get_cached_specs(brand, model, category)
                        │     CACHE HIT  →  return instantly, skip all steps below
                        │     CACHE MISS →  continue
                        │
                        ├── STEP 1 — DuckDuckGo search
                        │     runs 3 targeted queries:
                        │       "{brand} {model} specifications fiche technique"
                        │       "{brand} {model} datasheet manuel"
                        │       "{brand} {model} tunisianet.com OR mega.tn OR mytek.tn"
                        │     deduplicates by URL
                        │     returns up to 9 unique results
                        │
                        ├── STEP 2 — BeautifulSoup scraping  (parallel)
                        │     ThreadPoolExecutor → scrapes top 4 URLs at once
                        │     for each page:
                        │       removes noise  (scripts, nav, footer, ads)
                        │       extracts spec tables and definition lists first
                        │       extracts divs with "spec"/"caract"/"fiche" in class/id
                        │       caps at 6000 chars per page
                        │     keeps first 3 pages that returned content
                        │     fallback: uses DDG snippets if all pages failed
                        │
                        ├── STEP 3 — Groq extraction
                        │     rate_limiter.py → groq_throttle()
                        │     Groq llama-3.3-70b-versatile
                        │     sends: scraped content + canonical schema fields as hints
                        │     strict rules enforced in prompt:
                        │       exact_model_reference: ONLY from scraped text, never invent
                        │       numeric fields: numbers only, no units in value
                        │       boolean fields: true / false only
                        │     returns structured JSON
                        │
                        ├── STEP 4 — normalization
                        │     strips hallucinated keys not in the canonical schema
                        │     coerces types:
                        │       int fields   (capacity_btu, ram_gb, noise_level_db ...)
                        │       float fields (weight_kg, display_inches, battery_wh ...)
                        │       bool fields  (smart_wifi, no_frost, inverter)
                        │     converts dimension dict → "HxWxD cm" string
                        │     scales energy kWh if Groq returned monthly or daily instead of annual:
                        │       < 5  → multiply by 365  (was daily)
                        │       < 50 → multiply by 12   (was monthly)
                        │     fills every missing schema key with null
                        │     grades source_quality:
                        │       high   ≥ 7 fields found
                        │       medium ≥ 4 fields found
                        │       low    < 4 fields found
                        │
                        └── database.py → cache_specs()
                              saves result so future lookups of same device return instantly

              └── video.py → build_equipment_result()
                    merges spec_service output into standardised Flutter dict
              └── returns full equipment result to Flutter
```

---

## File Roles — One Line Each

| File | Role |
|---|---|
| `video.py` | Endpoint orchestrator — receives requests, calls everything, assembles responses |
| `smart_extract.py` | Decides which frames are the best shot of each detected device |
| `yolov5_service.py` | Fast local scan of all frames (Pass 1 of frame extraction) |
| `roboflow_service.py` | Cloud validation on selected frames (Pass 2 of frame extraction) |
| `workflow_service.py` | Per-frame orchestrator — runs Roboflow + frame_detector together |
| `frame_detector.py` | Reads brand and model from an image using OpenCV + Groq Vision |
| `spec_service.py` | Finds and extracts full technical specs from the web |
| `equipment_schemas.py` | Defines what fields each equipment type has — used by spec_service and frame_detector |
| `rate_limiter.py` | Token-bucket that prevents hitting Groq rate limits across concurrent workers |
| `database.py` | Saves and reads everything — sessions, detections, inventory, spec cache |

---

## Data Flow Summary

```
Video file
  → FFmpeg           → raw frames (JPEGs on disk)
  → YOLOv5           → scored detection pool
  → Roboflow         → cloud-validated detections + annotated images
  → smart_extract    → hero frames (best shot per equipment category)
  → WorkflowService  → Roboflow display image + frame_detector identity
  → frame_detector   → brand + model candidates  (Groq Vision, 2 images)
  → SpecService      → full technical specs  (DDG + scrape + Groq text)
  → database         → cached, logged, saved to inventory
  → Flutter          → displayed to user
```

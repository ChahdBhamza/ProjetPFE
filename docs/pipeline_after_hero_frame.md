# Post Hero-Frame Detection Pipeline

> **Context:** Once the sliding-window temporal segmentation and Laplacian variance scoring have selected the single sharpest "Hero Frame" from the uploaded video, the system hands it off to a multi-stage forensic pipeline. This document explains every step — technically and conceptually.

---

## 🌍 Non-Technical Overview

Think of it like sending a photo of a piece of equipment to a team of specialist experts:

1. **A security guard (RF-DETR)** looks at the photo and draws a tight box around just the machine — cutting out all background noise.
2. **A fast analyst (LLM Pass 1)** glances at it and says *"that's a refrigerator, and I think I can see a Samsung logo."*
3. **A forensic specialist (LLM Pass 2)** gets both the full photo AND a zoomed close-up, reads every sticker, badge, and label, and returns the exact model code with a confidence score and forensic reasoning.
4. **A researcher (SpecService)** takes that brand + model, runs 3 targeted Google searches, scrapes the top product pages, and extracts every technical specification into a clean structured JSON.
5. **The database (MongoDB)** stores it all — including the cropped hero frame as a base64 image so the exact real-life photo of the scanned unit is permanently visible in the inventory.

---

## ⚙️ Technical — Step by Step

---

### Step 1 — RF-DETR Cloud Bounding Box
**File:** `workflow_service.py`

The hero frame JPEG is sent to the **Roboflow Serverless API** (`custom-workflow-3`). The RF-DETR Detection Transformer model runs on the cloud and returns:

- `predictions` — list of detected objects with `x, y, w, h, confidence, class`
- `annotated_image` — the hero frame with the detection box drawn on it (returned as base64)

Any prediction below **60% confidence is dropped immediately**. If zero predictions survive, the forensic pass is skipped entirely and the system returns an empty result to Flutter.

```python
predictions = [p for p in predictions if p.get("confidence", 0) >= 0.60]
if len(predictions) > 0:
    # → proceed to forensic ID
```

---

### Step 2 — Classical CV Bounding Box + Crop
**File:** `frame_detector.py → process_frame()`

In parallel with Step 1, OpenCV runs its **own** bounding box detection on the clean hero frame to generate a precise crop for the LLM:

1. Convert to **grayscale** + apply **Gaussian blur** (7×7 kernel) to reduce noise
2. Run **Canny edge detection** (low=30, high=100) to find object boundaries
3. Apply **morphological dilation** with a 15×15 kernel to connect broken edge contours into one solid blob
4. Find all **external contours**, filter out anything smaller than 8% or larger than 97% of the total frame area
5. Take the **largest valid contour**, compute its bounding rectangle, and add a **3% padding** on each side
6. **Crop** the raw frame to this bounding box → `raw_crop`

```python
bbox = detect_dominant_object(frame)   # → (x, y, w, h)
raw_crop = frame[y:y+h, x:x+w]
```

---

### Step 3 — CLAHE Image Enhancement
**File:** `frame_detector.py → enhance_crop_for_ocr()`

The raw crop is enhanced before being passed to the Vision LLM to maximise text and logo readability:

1. **Upscale** if the crop short-side is below 800px (Lanczos4 interpolation)
2. Convert BGR → **LAB color space** to separate luminance from color channels
3. Apply **CLAHE** on the L (luminance) channel — `clipLimit=2.5`, `tileGridSize=(8,8)` — boosts local contrast in dark areas without blowing out highlights
4. Convert back LAB → BGR
5. Apply a custom **sharpening kernel** to crisp up edges and text:

```python
kernel = np.array([[0, -0.5, 0],
                   [-0.5,  3, -0.5],
                   [0, -0.5, 0]])
enhanced = cv2.filter2D(crop, -1, kernel)
```

The result is the **enhanced crop** — this is what the LLM reads brand logos and model stickers from.

---

### Step 4 — Two-Pass Groq Llama Vision
**File:** `frame_detector.py → identify_with_gemini()`

#### Pass 1 — Fast Type Classifier
**Model:** `meta-llama/llama-4-scout-17b-16e-instruct` | **Max tokens:** 300 | **Temperature:** 0.05

Sends only the **full annotated frame** (with CV bounding box). A structured JSON prompt asks:

```json
{
  "equipment_type": "refrigerator",
  "brand_visible": true,
  "preliminary_brand": "Samsung",
  "confidence_type": 85
}
```

This is a fast, cheap call — it exists purely to give Pass 2 a type hint and brand anchor so Pass 2 doesn't start blind.

**Type Resolution Logic (YOLO ↔ LLM Safeguard):**

| Condition | Winner |
|:---|:---|
| YOLO hint exists AND Pass 1 agrees | Use YOLO hint |
| YOLO hint exists AND Pass 1 disagrees with confidence ≥ 70% | **Trust Pass 1** (LLM overrides YOLO) |
| YOLO hint exists AND Pass 1 disagrees with confidence < 70% | Use YOLO hint |
| No YOLO hint | Use Pass 1 result directly |

---

#### Pass 2 — Forensic Identification
**Model:** `meta-llama/llama-4-scout-17b-16e-instruct` | **Max tokens:** 2000 | **Temperature:** 0.05

Sends **TWO images simultaneously:**
- **Image 1:** Full annotated frame (scene context, scale reference)
- **Image 2:** Enhanced CLAHE crop (zoomed in for text/logo reading)

The prompt is **equipment-category-specific**. Each category has its own forensic protocol, for example:

> **For Refrigerators:** Read the front door logo → find the EU energy label → look for No-Frost badge → find capacity sticker (inside door) → find refrigerant label (back panel) → read model code on the rating plate.

> **For Laptops:** Read lid logo → find series badge (Legion, VivoBook, etc.) → check bottom regulatory sticker for exact model number → count port layout → identify CPU badge.

Pass 2 also receives the `preliminary_brand` from Pass 1 as an anchor to prevent cross-brand hallucination.

**Output:**

```json
{
  "detected": true,
  "equipment_category": "refrigerator",
  "brand": "Samsung",
  "model_candidates": [
    {
      "model": "RT38CG6421B1",
      "confidence": 78,
      "reasoning": "Energy label visible, No-Frost badge on door, silver finish matches 2023 Samsung top-mount series"
    },
    {
      "model": "RT38T5030S9",
      "confidence": 22,
      "reasoning": "Similar design but older generation without the updated badge"
    }
  ],
  "visual_cues": ["No-Frost badge", "EU A+ energy label", "Silver finish", "Bottom-mount freezer"]
}
```

> **Confidence rules enforced in prompt:** ≥90% = readable model text on sticker; 70–89% = recognized by unique design features; 50–69% = brand recognized but model unclear; <50% = excluded. All candidates must sum to exactly 100.

---

### Step 5 — Spec Hunting Pipeline
**File:** `spec_service.py → get_full_identity()`

This is triggered as a **separate API call** when the Flutter user taps "Get Specs". It receives `brand` + `top_model` from Step 4.

#### Sub-step 5a — DuckDuckGo Multi-Query Search

Three targeted queries are fired via `DDGS`:

```
1. "Samsung RT38CG6421B1 refrigerator specifications fiche technique"
2. "Samsung RT38CG6421B1 site:samsung.com specifications"
3. "Samsung RT38CG6421B1 prix tunisie mega.tn OR mytek.tn OR tunisianet.com"
```

Results are deduplicated by URL. Up to **9 unique URLs** are collected across all three queries.

---

#### Sub-step 5b — BeautifulSoup DOM Scraping (Top 3 Pages)

For each URL:
1. HTTP GET with a realistic Chrome user-agent header
2. Strip all noise tags: `<script>`, `<style>`, `<nav>`, `<footer>`, `<svg>`, `<img>`
3. **Prioritize `<table>` and `<dl>` elements** — spec tables are extracted first and placed at the top
4. Also target any `<div>` or `<section>` whose class/id matches `/spec|caract|detail|fiche/`
5. Append full body text as fallback
6. **Hard cap: 6,000 chars per page**

The combined text from up to 3 pages is then capped at **4,000 chars total** before being injected into the LLM prompt (token budget protection).

---

#### Sub-step 5c — Groq Schema-Aware Extraction

**Model:** `llama-3.1-8b-instant` | **Max tokens:** 1,500 | **Temperature:** 0.05

The prompt includes:
- The scraped content (≤4,000 chars)
- The **exact Pydantic JSON schema** for the equipment category (e.g. for a refrigerator: `capacity_liters`, `refrigerant`, `no_frost`, `energy_class`, `price_tnd`, etc.)
- Strict rules: no null values — if a spec is missing from the web, **estimate from training knowledge**

Example output for a refrigerator:
```json
{
  "capacity_liters": 380,
  "refrigerant": "R600a",
  "no_frost": true,
  "energy_class": "A+",
  "price_tnd": 1899.0,
  "dimensions": "185 x 70 x 67 cm",
  "exact_model_reference": "RT38CG6421B1EF"
}
```

---

#### Sub-step 5d — Normalization Pass

After extraction, a normalization pass runs automatically:

| Rule | Example |
|:---|:---|
| Strip units from numeric strings | `"380L"` → `380` (int) |
| Parse float fields | `"1,299.0 TND"` → `1299.0` (float) |
| Coerce boolean strings | `"Yes"` / `"Oui"` → `true` (bool) |
| Split comma strings to lists | `"Grill, Steam"` → `["Grill", "Steam"]` |
| Count non-null fields | Used to grade source quality |

**Source quality grading:**

| Fields Found | Quality Grade |
|:---|:---|
| ≥ 7 | `"high"` |
| ≥ 4 | `"medium"` |
| < 4 | `"low"` |

---

### Step 6 — MongoDB Atlas Storage
**File:** `database.py`, `video.py → build_equipment_result()`

The full result is assembled by `build_equipment_result()` and saved to MongoDB:

```json
{
  "identity": {
    "equipment_category": "refrigerator",
    "brand": "Samsung",
    "top_model": "RT38CG6421B1",
    "confidence": 78,
    "visual_cues": ["No-Frost badge", "EU A+ energy label"]
  },
  "specs": {
    "capacity_liters": 380,
    "refrigerant": "R600a",
    "no_frost": true,
    "energy_class": "A+",
    "price_tnd": 1899.0
  },
  "meta": {
    "ai_image": "<base64 annotated hero crop>",
    "source_quality": "high",
    "fields_found": 8,
    "verified": true,
    "source_urls": ["https://samsung.com/...", "https://mega.tn/..."],
    "pipeline": "ddg-3queries -> beautifulsoup(3 pages) -> groq-llama-3.1-8b-instant"
  }
}
```

The `ai_image` field stores the RF-DETR annotated bounding box screenshot as a base64 string. When the user opens the Inventory tab, Flutter decodes this string and renders it as the equipment card banner — providing **visual forensic lineage** of the exact scanned unit.

---

## 📊 Complete Flow Diagram

```
Hero Frame (sharpest frame from video)
    │
    ├──► RF-DETR (Roboflow Serverless Cloud)
    │        └─ Bounding box coordinates + confidence filter (≥ 60%)
    │        └─ Annotated image (base64) returned
    │
    ├──► OpenCV (local server)
    │        └─ Canny edge detection → contour crop
    │        └─ CLAHE enhancement → sharpening kernel
    │
    ├──► Groq Pass 1  (llama-4-scout, 1 image, ~300 tokens)
    │        └─ Equipment type classification
    │        └─ Preliminary brand detection
    │        └─ YOLO ↔ LLM type arbitration safeguard
    │
    ├──► Groq Pass 2  (llama-4-scout, 2 images, ~2000 tokens)
    │        └─ Category-specific forensic protocol prompt
    │        └─ Model candidates + confidence + visual cues
    │
    ├──► DuckDuckGo × 3 queries
    │        └─ Specs query + manufacturer query + Tunisian price query
    │        └─ Up to 9 unique product URLs
    │
    ├──► BeautifulSoup (top 3 pages, 4,000 char cap)
    │        └─ DOM noise stripping
    │        └─ Spec table priority extraction
    │
    ├──► Groq Extraction  (llama-3.1-8b, schema-constrained, ~1500 tokens)
    │        └─ Typed JSON specs output
    │        └─ Normalization + quality grading
    │
    └──► MongoDB Atlas
             └─ Full equipment_result document stored
             └─ base64 hero crop stored as ai_image in metadata
             └─ Inventory tab renders it as the card banner
```

---

## 🧮 Token Budget Summary

| LLM Call | Model | Max Input | Max Output | Purpose |
|:---|:---|:---|:---|:---|
| Pass 1 | llama-4-scout-17b | ~500 tokens | 300 tokens | Type + brand hint |
| Pass 2 | llama-4-scout-17b | ~1000 tokens | 2000 tokens | Forensic model ID |
| Spec Extraction | llama-3.1-8b-instant | ~1800 tokens | 1500 tokens | Spec JSON extraction |

Total per full scan: approximately **~7,100 tokens** across 3 separate LLM calls.

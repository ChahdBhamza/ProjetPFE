"""
frame_detector.py — Classical CV bounding box + Vision LLM identification

Pipeline:
  1. OpenCV detects the dominant large object in the frame
  2. Draws a bounding box on the original image
  3. Crops the region of interest
  4. Enhances the crop (CLAHE + upscale) for better brand/text visibility
  5. Sends BOTH images to OpenRouter Vision LLM
  6. LLM identifies brand, model candidates, confidence, reasoning
"""

import cv2
import numpy as np
import base64
import json
import time
from openai import OpenAI
from PIL import Image


# ── Step 1: Classical CV — find dominant object bounding box ──────────────────

def detect_dominant_object(frame: np.ndarray) -> tuple[int, int, int, int] | None:
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (7, 7), 0)
    edges = cv2.Canny(blurred, 30, 100)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (15, 15))
    dilated = cv2.dilate(edges, kernel, iterations=3)
    contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    if not contours:
        return None

    h_frame, w_frame = frame.shape[:2]
    frame_area = h_frame * w_frame
    valid = []
    for c in contours:
        x, y, w, h = cv2.boundingRect(c)
        area = w * h
        if 0.08 * frame_area < area < 0.97 * frame_area:
            valid.append((area, x, y, w, h))

    if not valid:
        largest = max(contours, key=cv2.contourArea)
        x, y, w, h = cv2.boundingRect(largest)
        return x, y, w, h

    valid.sort(reverse=True)
    _, x, y, w, h = valid[0]
    pad_x = int(w * 0.03)
    pad_y = int(h * 0.03)
    x = max(0, x - pad_x)
    y = max(0, y - pad_y)
    w = min(w_frame - x, w + 2 * pad_x)
    h = min(h_frame - y, h + 2 * pad_y)
    return x, y, w, h


# ── Step 2: Draw annotated bounding box ──────────────────────────────────────

def draw_bounding_box(frame: np.ndarray, bbox: tuple[int, int, int, int]) -> np.ndarray:
    annotated = frame.copy()
    x, y, w, h = bbox
    color = (30, 180, 100)
    cv2.rectangle(annotated, (x, y), (x + w, y + h), color, 3)

    corner_len = min(w, h) // 8
    accent = (60, 220, 140)
    for cx, cy, dx, dy in [(x, y, 1, 1), (x+w, y, -1, 1), (x, y+h, 1, -1), (x+w, y+h, -1, -1)]:
        cv2.line(annotated, (cx, cy), (cx + dx * corner_len, cy), accent, 4)
        cv2.line(annotated, (cx, cy), (cx, cy + dy * corner_len), accent, 4)

    label = "Equipment detected"
    font = cv2.FONT_HERSHEY_SIMPLEX
    (text_w, text_h), baseline = cv2.getTextSize(label, font, 0.65, 2)
    cv2.rectangle(annotated, (x - 2, y - text_h - baseline - 14), (x + text_w + 4, y - 4), color, -1)
    cv2.putText(annotated, label, (x, y - baseline - 8), font, 0.65, (255, 255, 255), 2)

    return annotated


# ── Step 3: Image enhancement for better brand/logo recognition ───────────────

def enhance_crop_for_ocr(crop: np.ndarray) -> np.ndarray:
    h, w = crop.shape[:2]
    target_min = 640
    if min(h, w) < target_min:
        scale = target_min / min(h, w)
        crop = cv2.resize(crop, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_LANCZOS4)

    lab = cv2.cvtColor(crop, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8))
    l = clahe.apply(l)
    enhanced = cv2.merge([l, a, b])
    enhanced = cv2.cvtColor(enhanced, cv2.COLOR_LAB2BGR)

    kernel = np.array([[0, -0.5, 0], [-0.5, 3, -0.5], [0, -0.5, 0]])
    enhanced = cv2.filter2D(enhanced, -1, kernel)
    enhanced = np.clip(enhanced, 0, 255).astype(np.uint8)

    return enhanced


# ── Step 4: Helpers ───────────────────────────────────────────────────────────

def encode_image_to_base64(img: np.ndarray) -> str:
    _, buffer = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 92])
    return base64.b64encode(buffer).decode("utf-8")

def cv2_to_pil(img_cv2: np.ndarray) -> Image.Image:
    return Image.fromarray(cv2.cvtColor(img_cv2, cv2.COLOR_BGR2RGB))


# ── Step 5: Gemini Vision prompt ─────────────────────────────────────────────

VISION_PROMPT = """
You are a HIGH-PRECISION FORENSIC SPECIALIST in identifying equipment.
Your mission is to provide the EXACT technical reference for the equipment in the photo.

You are given TWO images:
- Image 1: Full scene for context
- Image 2: ENHANCED close-up for reading stickers, logos, and model plates.

YOUR FORENSIC PROTOCOL:
1. READ THE BRAND: Look for logos. If it says "Lenovo", the brand is Lenovo.
2. FIND THE REFERENCE: Look for specific alphanumeric codes (e.g., 15IAH7, Legion 5, AC-12000, MW-700). 
   Check: bottom stickers, corner badges, and control panels.
3. FORMAT: Every model name in "model_candidates" MUST follow the format: [BRAND] [SERIES] [REFERENCE CODE].
   Example: "Lenovo Legion 5 15IAH7" or "Brandt Microwave M-20".

STRICT CONFIDENCE RULES:
- 90%+: You can clearly read the model name/number on the image.
- 70-80%: You recognize the series and specific design features that only exist for one model.
- 50% or less: If you are guessing based on general shape (e.g. "it looks like a laptop").
- If the brand is confirmed but model plate is blurry, suggest the BRAND + most likely series but keep confidence below 60%.

Respond ONLY with this JSON structure:
{
  "detected": true,
  "equipment_type": "laptop",
  "brand": "Lenovo",
  "model_candidates": [
    {
      "model": "Lenovo Legion 5 15IAH7",
      "confidence": 95,
      "reasoning": "Lenovo logo visible on lid. 'Legion' badge clearly readable. Alphanumeric reference code '15IAH7' visible on the bottom label in Image 2."
    },
    {
      "model": "Lenovo Legion 5 Pro",
      "confidence": 5,
      "reasoning": "Similar form factor but chassis thickness matches the standard Legion 5 better."
    }
  ],
  "visual_cues": [
    "Specific port layout on the back matches Legion 2022 series",
    "Blue backlit power button is unique to this generation"
  ]
}

IMPORTANT:
- Confidence values MUST sum to exactly 100.
- Reasoning MUST describe specific visual elements you actually see.
"""


def identify_with_llm(annotated_frame: np.ndarray, enhanced_crop: np.ndarray, api_key: str) -> dict:
    client = OpenAI(
        base_url="https://openrouter.ai/api/v1",
        api_key=api_key,
        default_headers={
            "HTTP-Referer": "http://localhost:8000",
            "X-Title": "SFM Equipment Identifier",
        }
    )

    def to_b64(img):
        _, buffer = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 90])
        return base64.b64encode(buffer).decode("utf-8")

    b64_full = to_b64(annotated_frame)
    b64_crop = to_b64(enhanced_crop)

    # Attempt with simple retry for 429s
    for attempt in range(3):
        try:
            response = client.chat.completions.create(
                model="google/gemini-3.1-flash-lite",
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": VISION_PROMPT},
                            {
                                "type": "image_url",
                                "image_url": {"url": f"data:image/jpeg;base64,{b64_full}"}
                            },
                            {
                                "type": "image_url",
                                "image_url": {"url": f"data:image/jpeg;base64,{b64_crop}"}
                            },
                        ],
                    }
                ],
                temperature=0.1,
                max_tokens=2000,
            )
            break
        except Exception as e:
            if "429" in str(e) and attempt < 2:
                print(f"[rate limit] Busy upstream, retrying in 5s...")
                time.sleep(5)
                continue
            raise

    raw = response.choices[0].message.content.strip()
    if "```json" in raw:
        raw = raw.split("```json")[1].split("```")[0].strip()
    elif "```" in raw:
        raw = raw.split("```")[1].split("```")[0].strip()

    return json.loads(raw)


# ── Public entry point ────────────────────────────────────────────────────────

def process_frame(image_path: str, api_key: str) -> dict:
    frame = cv2.imread(image_path)
    if frame is None:
        raise ValueError(f"Could not read image at {image_path}")

    bbox = detect_dominant_object(frame)
    if bbox is None:
        bbox = (0, 0, frame.shape[1], frame.shape[0])

    x, y, w, h = bbox
    annotated = draw_bounding_box(frame, bbox)
    raw_crop = frame[y:y+h, x:x+w]
    enhanced_crop = enhance_crop_for_ocr(raw_crop)

    llm_result = identify_with_llm(annotated, enhanced_crop, api_key)

    return {
        "bbox": {"x": x, "y": y, "w": w, "h": h},
        "annotated_image_b64": encode_image_to_base64(annotated),
        "result": llm_result,
    }

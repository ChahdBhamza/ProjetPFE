"""
frame_detector.py — Classical CV bounding box + Two-Pass Gemini Vision Identification

Pipeline:
  1. OpenCV detects the dominant large object in the frame
  2. Draws a bounding box on the original image
  3. Crops the region of interest
  4. Enhances the crop (CLAHE + upscale) for better brand/text visibility
  5. PASS 1 (Fast Type Detect): gemini-2.0-flash-lite classifies equipment type + confirms brand visible
  6. PASS 2 (Forensic ID): Equipment-specific deep-read prompt sent with BOTH images via gemini-2.5-flash
  7. Returns standardised identity dict ready to feed into SpecService
"""

import cv2
import numpy as np
import base64
import json
import os
import time
from dotenv import load_dotenv
from groq import Groq
from PIL import Image
from pydantic import BaseModel, Field
from typing import List, Optional

load_dotenv()

# ── Pydantic Schemas for Structured Output ────────────────────────────────────

class Pass1Result(BaseModel):
    equipment_type: str = Field(description="Must be one of: 'airconditioner', 'refrigerator', 'microwave', 'laptop', 'unknown'")
    brand_visible: bool = Field(description="True if a manufacturer logo or printed brand name is visible in the image")
    preliminary_brand: Optional[str] = Field(description="Best guess at the brand name, or null if not visible")
    confidence_type: int = Field(description="Confidence percentage for the type classification (0-100)")

class ModelCandidate(BaseModel):
    model: str = Field(description="Must be an EXACT, SINGLE alphanumeric reference code (e.g., 'Samsung AR12TXHQASINEU'). NO GENERIC NAMES.")
    confidence: int = Field(description="Confidence percentage for this candidate (0-100)")
    reasoning: str = Field(description="Forensic reasoning explaining why this model is selected based on visible features")

class Pass2Result(BaseModel):
    detected: bool = Field(description="True only if there is actually equipment visible and identifiable in the image")
    equipment_category: str = Field(description="Canonical category: airconditioner, refrigerator, microwave, laptop, or unknown")
    brand: str = Field(description="Detected brand name")
    model_candidates: List[ModelCandidate] = Field(description="List of matching model candidates")
    visual_cues: List[str] = Field(description="List of specific visible elements detected on the equipment")

# ── Groq client ───────────────────────────────────────────────────────────────

def _get_groq_client() -> Groq:
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise RuntimeError("GROQ_API_KEY not set in .env")
    return Groq(api_key=api_key)


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
    target_min = 800
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


def _img_to_bytes(img: np.ndarray) -> bytes:
    _, buffer = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 90])
    return buffer.tobytes()


# ── Step 5: Pass 1 — Fast equipment type detection ────────────────────────────

PASS1_PROMPT = """
You are a fast equipment classifier. Look at this image and identify the equipment type and whether the brand is visible.
"""

def _run_pass1(client: Groq, full_frame_bytes: bytes) -> dict:
    """Fast type + brand visibility check via Groq Llama Vision."""
    b64_img = base64.b64encode(full_frame_bytes).decode('utf-8')
    prompt = PASS1_PROMPT + """

Respond ONLY with a valid JSON object with exactly these keys:
{
  "equipment_type": "airconditioner" | "refrigerator" | "microwave" | "laptop" | "unknown",
  "brand_visible": true | false,
  "preliminary_brand": "BrandName" | null,
  "confidence_type": 0-100
}"""

    for attempt in range(3):
        try:
            resp = client.chat.completions.create(
                model="meta-llama/llama-4-scout-17b-16e-instruct",
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64_img}"}},
                        ],
                    }
                ],
                temperature=0.05,
                max_tokens=300,
                response_format={"type": "json_object"},
            )
            raw = resp.choices[0].message.content.strip()
            return json.loads(raw)
        except Exception as e:
            err = str(e)
            if "429" in err or "rate_limit" in err.lower():
                wait = 10 * (attempt + 1)
                print(f"[Pass1] Groq rate limited. Waiting {wait}s... (attempt {attempt+1})")
                time.sleep(wait)
                continue
            print(f"[Pass1] Groq error (attempt {attempt+1}): {err[:200]}")
            time.sleep(3)
    return {"equipment_type": "unknown", "brand_visible": False, "preliminary_brand": None, "confidence_type": 0}


# ── Step 6: Pass 2 — Equipment-specific forensic identification prompts ────────

def _build_pass2_prompt(equipment_type: str, preliminary_brand: str | None) -> str:
    """Build a forensic identification prompt tailored to the equipment category."""

    brand_hint = f'The preliminary brand detected is "{preliminary_brand}". Confirm or correct it.' if preliminary_brand else "No brand was pre-detected. Search all visible surfaces."

    base_rules = f"""
You are a FORENSIC EQUIPMENT IDENTIFICATION SPECIALIST.
You are given TWO images:
- Image 1: Full scene with bounding box annotation (context)
- Image 2: ENHANCED close-up crop (for reading logos, stickers, serial plates)

{brand_hint}

STRICT CONFIDENCE RULES:
- 90%+: You can CLEARLY READ the exact model code/number on the image
- 70-89%: You recognize the specific series by unique design features (port layout, badge shape, panel design)
- 50-69%: You recognize the brand and likely product generation, but cannot read exact model code
- Below 50%: Do NOT include this candidate — it is a guess

IMPORTANT:
- The model candidates you suggest MUST be highly accurate.
- Every model name in "model_candidates" MUST be a single, precise alphanumeric reference code. DO NOT use generic family names like "Samsung Inverter" or "LG DualCool". You MUST provide the exact reference code.
  Example CORRECT: "Samsung AR12TXHQASINEU" or "LG P12EP"
  Example INCORRECT: "Samsung WindFree" or "LG Air Conditioner"
- Confidence values across all candidates MUST sum to exactly 100
- Reasoning MUST describe specific visible elements you actually see
"""

    type_specific = {
        "airconditioner": """
FORENSIC PROTOCOL FOR AIR CONDITIONERS:
1. READ THE BRAND: Look at the front panel logo and any side badging
2. FIND THE BTU/CAPACITY: Look for capacity numbers like "12000", "18K", "24000" on the front badge or label strip
3. LOOK FOR INVERTER BADGE: Many units have "Inverter", "WindFree", "Dual Inverter", or "Twin Cool" badges
4. CHECK REFRIGERANT LABEL: Often on the back or service panel — "R32", "R410A"
5. MODEL CODE: Usually on a silver sticker on the side panel or back unit. Contains alphanumerics like "AR12TXHQASINEU"
6. SMART FEATURES: Look for WiFi symbol or "Smart" label on the panel
""",
        "refrigerator": """
FORENSIC PROTOCOL FOR REFRIGERATORS:
1. READ THE BRAND: Front door logo, usually top or center
2. CAPACITY STICKER: Often inside the door or on the side — look for "L" or "Liters" e.g. "380L"
3. ENERGY LABEL: The EU energy efficiency label (A/A+/A++/A+++) is usually on the front or side
4. NO-FROST BADGE: Look for "No-Frost", "Total No Frost", or "Multi Air Flow" badges
5. REFRIGERANT: On the technical plate inside the door or on the back — "R600a" or "R134a"
6. MODEL CODE: On the rating plate inside the door or on the back panel — e.g. "RT38CG6421B1"
7. COMPRESSOR BADGE: "Digital Inverter" or "Inverter" may be on the door
""",
        "microwave": """
FORENSIC PROTOCOL FOR MICROWAVE OVENS:
1. READ THE BRAND: Front panel, usually centered or top-left
2. WATTAGE: Look for "W" or "Watts" on the front label strip — e.g. "1000W", "800W"
3. CAPACITY: Look for "L" or "Liters" — e.g. "25L", "30L"
4. FUNCTIONS: Check button panel for Grill, Convection, Steam, Defrost labels
5. CONTROL TYPE: Is it a digital display with touchpad, or analog knobs?
6. MODEL CODE: Usually on a sticker on the back or inside the door frame
""",
        "laptop": """
FORENSIC PROTOCOL FOR LAPTOPS:
1. READ THE BRAND: Logo on the lid (closed/open), keyboard deck, or screen bezel
2. SERIES BADGE: Look for "Legion", "IdeaPad", "ThinkPad", "Pavilion", "VivoBook", "ProArt" etc.
3. BOTTOM LABEL (CRITICAL): The bottom of the laptop has a regulatory sticker with the EXACT model number e.g. "15IAH7", "FX517ZE", "FA507NU" — this is the most reliable identifier
4. KEYBOARD BACKLIGHT: RGB or single-color backlight is specific to product series
5. PORT LAYOUT: Count and identify USB-A, USB-C, HDMI, SD card slots on the sides
6. SCREEN BORDER: Thin bezels vs thick borders help identify generation
7. CPU BADGE: Look for Intel/AMD sticker near touchpad area
""",
        "unknown": """
FORENSIC PROTOCOL (UNKNOWN DEVICE):
1. Identify what category of equipment this is first
2. Look for any brand logo, model badge, or sticker
3. Note distinctive physical features: color, shape, size, controls
4. Provide your best model candidates based on visible evidence only
""",
    }

    type_key = equipment_type if equipment_type in type_specific else "unknown"

    return f"""{base_rules}

{type_specific[type_key]}

CRITICAL: You are provided with TWO images. The FIRST is the full scene. The SECOND is a zoomed-in crop of the equipment. 
If the equipment is far away in the first image, rely heavily on the SECOND (cropped) image to read the brand logo and model text.
NEVER leave the "brand" field empty. If you cannot read the exact brand, make your absolute best guess based on the logo shape, colors, and equipment design.

IMPORTANT: detected must be true only if equipment is visible and identifiable.
"""


def _run_pass2(client: Groq, full_frame_bytes: bytes, crop_bytes: bytes, equipment_type: str, preliminary_brand: str | None) -> dict:
    """Deep forensic identification using Groq Llama Vision."""
    b64_full = base64.b64encode(full_frame_bytes).decode('utf-8')
    b64_crop = base64.b64encode(crop_bytes).decode('utf-8')
    prompt = _build_pass2_prompt(equipment_type, preliminary_brand)
    prompt += """

Respond ONLY with a valid JSON object matching exactly:
{
  "detected": true | false,
  "equipment_category": "string",
  "brand": "string",
  "model_candidates": [{"model": "string", "confidence": 0-100, "reasoning": "string"}],
  "visual_cues": ["string"]
}"""

    for attempt in range(3):
        try:
            time.sleep(2)  # stay within 30 RPM Groq free tier
            resp = client.chat.completions.create(
                model="meta-llama/llama-4-scout-17b-16e-instruct",
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64_full}"}},
                            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64_crop}"}},
                        ],
                    }
                ],
                temperature=0.05,
                max_tokens=2000,
                response_format={"type": "json_object"},
            )
            raw = resp.choices[0].message.content.strip()
            return json.loads(raw)
        except Exception as e:
            err = str(e)
            if "429" in err or "rate_limit" in err.lower():
                wait = 15 * (attempt + 1)
                print(f"[Pass2] Groq rate limited. Waiting {wait}s... (attempt {attempt+1})")
                time.sleep(wait)
                continue
            print(f"[Pass2] Error (attempt {attempt+1}): {err[:200]}")
            if attempt < 2:
                time.sleep(5)
                continue
            return {
                "detected": True,
                "equipment_category": equipment_type,
                "brand": preliminary_brand or "Unknown",
                "model_candidates": [],
                "visual_cues": [],
                "_error": err,
            }

# ── Public entry point ────────────────────────────────────────────────────────

def identify_with_gemini(annotated_frame: np.ndarray, enhanced_crop: np.ndarray) -> dict:
    """
    Two-pass Groq Llama Vision identification:
      Pass 1: Fast type detection (llama-4-scout-17b)
      Pass 2: Equipment-specific forensic prompt with both images
    Returns a merged result dict.
    """
    client = _get_groq_client()

    full_bytes = _img_to_bytes(annotated_frame)
    crop_bytes = _img_to_bytes(enhanced_crop)

    print("[Vision] Pass 1: Fast equipment type detection...")
    pass1 = _run_pass1(client, full_bytes)
    eq_type = pass1.get("equipment_type", "unknown")
    brand_hint = pass1.get("preliminary_brand", None)
    print(f"[Vision] Pass 1 result: type={eq_type}, brand={brand_hint}, confidence={pass1.get('confidence_type', 0)}%")

    print(f"[Vision] Pass 2: Forensic ID for type='{eq_type}'...")
    pass2 = _run_pass2(client, full_bytes, crop_bytes, eq_type, brand_hint)

    # Merge: pass1 type detection + pass2 deep identification
    pass2["equipment_category"] = pass2.get("equipment_category") or eq_type
    pass2["pass1_type_confidence"] = pass1.get("confidence_type", 0)

    return pass2


def process_frame(image_path: str, api_key: str | None = None) -> dict:
    """
    Public entry point — accepts image path, returns full identification result.
    The api_key parameter is kept for backward compatibility but the native
    google-genai SDK is used (reads GOOGLE_API_KEY from environment).
    """
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

    llm_result = identify_with_gemini(annotated, enhanced_crop)

    return {
        "bbox": {"x": x, "y": y, "w": w, "h": h},
        "annotated_image_b64": encode_image_to_base64(annotated),
        "result": llm_result,
    }

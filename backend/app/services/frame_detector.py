"""
frame_detector.py — Classical CV bounding box + Two-Pass Groq Vision Identification

Pipeline:
  1. OpenCV detects the dominant large object in the frame
  2. Draws a bounding box on the original image
  3. Crops the region of interest
  4. Enhances the crop (CLAHE + upscale) for better brand/text visibility
  5. PASS 1 (Fast Type Detect): groq llama-4-scout classifies equipment type + confirms brand visible
  6. PASS 2 (Forensic ID): Equipment-specific deep-read prompt sent with BOTH images via groq llama-4-scout
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
from pydantic import BaseModel, Field, ValidationError
from typing import List, Optional

from app.services.rate_limiter import groq_throttle

load_dotenv()

# ── Pydantic Schemas for Structured Output ────────────────────────────────────

class Pass1Result(BaseModel):
    equipment_type: str = Field(description="Must be one of: 'airconditioner', 'refrigerator', 'microwave', 'laptop', 'monitor', 'unknown'")
    brand_visible: bool = Field(description="True if a manufacturer logo or printed brand name is visible in the image")
    preliminary_brand: Optional[str] = Field(description="Best guess at the brand name, or null if not visible")
    preliminary_model: Optional[str] = Field(description="Any model code, reference, or capacity visible in the image (e.g. '9000BTU', 'AR09TX', 'IdeaPad'), or null if nothing readable")
    confidence_type: int = Field(description="Confidence percentage for the type classification (0-100)")

class ModelCandidate(BaseModel):
    model: str = Field(description="The model code EXACTLY as printed/visible in the image. If nothing is readable, describe what you see (e.g. '12000BTU white inverter unit'). Never invent a code.")
    confidence: int = Field(description="Confidence percentage for this candidate (0-100)")
    reasoning: str = Field(description="Forensic reasoning explaining why this model is selected based on visible features")

class Pass2Result(BaseModel):
    detected: bool = Field(description="True only if there is actually equipment visible and identifiable in the image")
    equipment_category: str = Field(description="Canonical category: airconditioner, refrigerator, microwave, laptop, monitor, or unknown")
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
    target_min = 600  # Reduced from 800 for faster processing
    if min(h, w) < target_min:
        scale = target_min / min(h, w)
        crop = cv2.resize(crop, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_LINEAR)  # Faster than LANCZOS4

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
    _, buffer = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 85])
    return buffer.tobytes()


# ── Step 5: Pass 1 — Fast equipment type detection ────────────────────────────

PASS1_PROMPT = """You are a fast equipment classifier and identifier.
Look at this image and extract:
1. The equipment TYPE
2. The BRAND (logo or printed name on the unit)
3. Any MODEL CODE, reference number, or capacity visible (on sticker, label, or badge)

Respond ONLY with a valid JSON object with exactly these keys:
{
  "equipment_type": "airconditioner" | "refrigerator" | "microwave" | "laptop" | "monitor" | "unknown",
  "brand_visible": true | false,
  "preliminary_brand": "BrandName" | null,
  "preliminary_model": "model code or capacity visible in image, e.g. AR09TX or 9000BTU" | null,
  "confidence_type": 0-100
}"""

def _run_pass1(client: Groq, full_frame_bytes: bytes) -> dict:
    """Fast type + brand + model visibility check via Groq Llama Vision."""
    b64_img = base64.b64encode(full_frame_bytes).decode('utf-8')
    prompt = PASS1_PROMPT

    for attempt in range(3):
        try:
            groq_throttle()
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
            return Pass1Result(**json.loads(raw)).model_dump()
        except ValidationError as e:
            print(f"[Pass1] Schema validation failed (attempt {attempt+1}): {e}")
            time.sleep(3)
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

def _build_pass2_prompt(equipment_type: str, preliminary_brand: str | None, preliminary_model: str | None = None) -> str:
    """Build forensic identification prompt."""

    hints = []
    if preliminary_brand:
        hints.append(f"BRAND (from Pass 1): \"{preliminary_brand}\" — restrict model reference to this brand's real catalog.")
    if preliminary_model:
        hints.append(f"MODEL HINT (from Pass 1): \"{preliminary_model}\" was detected. Verify or refine it using the enhanced crop.")
    brand_hint = "\n".join(hints)

    type_specific = {
        "airconditioner": (
            "EQUIPMENT TYPE: Split Air Conditioner (indoor wall unit)\n"
            "WHERE TO LOOK FOR MODEL:\n"
            "- Front panel: brand logo, capacity badge (9K/12K/18K/24K BTU), Inverter/Twin Cool/WindFree badge\n"
            "- Side panel sticker: alphanumeric model code e.g. AR12TXHQASINEU, F12AK, FTXS35\n"
            "- Capacity + series visible → use them to identify the exact series model\n"
            "REAL EXAMPLES: Samsung AR09TXHQASINEU, LG S09EQ, Daikin FTXS25, Gree GWH09AAB"
        ),
        "refrigerator": (
            "EQUIPMENT TYPE: Refrigerator / Fridge-Freezer\n"
            "WHERE TO LOOK FOR MODEL:\n"
            "- Front door: brand logo, No-Frost badge, capacity (L), energy label (A+++)\n"
            "- Inside door frame: model rating plate or sticker e.g. RT38CG6421B1, GBB72PZDMN\n"
            "- Side or back panel: data plate (metal or plastic), may be engraved or stamped\n"
            "- Plastic interior walls: model/serial number may be ENGRAVED or MOLDED into the plastic\n"
            "- Door handle area or bottom grille: sometimes has embossed model info\n"
            "REAL EXAMPLES: Samsung RT38CG6421B1, LG GBB72PZDMN, Bosch KGN39XIDR"
        ),
        "microwave": (
            "EQUIPMENT TYPE: Microwave Oven\n"
            "WHERE TO LOOK FOR MODEL:\n"
            "- Front: brand, wattage (800W/1000W), capacity (25L/30L), control type\n"
            "- Back sticker or inside door frame: model code\n"
            "- Button panel: Grill, Convection, Steam functions\n"
            "REAL EXAMPLES: Samsung MS23K3513AK, LG MH6535GIS, Whirlpool MWP303SB"
        ),
        "laptop": (
            "EQUIPMENT TYPE: Laptop / Notebook\n"
            "WHERE TO LOOK FOR MODEL:\n"
            "- Lid: brand logo\n"
            "- Screen bezel or keyboard deck: series badge (Legion, IdeaPad, VivoBook, ProArt, Pavilion)\n"
            "- Bottom sticker (CRITICAL): exact model number e.g. 82SB, FX517ZE, FA507NU\n"
            "- Near touchpad: Intel/AMD CPU badge\n"
            "REAL EXAMPLES: ASUS TUF FX517ZE, Lenovo Legion 5 82SB, HP Pavilion 15-eg2"
        ),
        "monitor": (
            "EQUIPMENT TYPE: Computer Monitor / Display\n"
            "WHERE TO LOOK FOR MODEL:\n"
            "- Front bezel bottom: brand logo\n"
            "- Back panel sticker: model code e.g. U2422H, S2421HN, 27G2U\n"
            "- Screen size clue in model number (24→24inch, 27→27inch)\n"
            "- Ports on back/bottom: HDMI, DP, USB-C, VGA\n"
            "REAL EXAMPLES: Dell U2422H, Samsung S27AG552, AOC 27G2U"
        ),
        "unknown": (
            "EQUIPMENT TYPE: Unknown — identify category first, then brand and model.\n"
            "Look for any logo, badge, sticker, or distinctive design features."
        ),
    }

    type_key = equipment_type if equipment_type in type_specific else "unknown"
    type_block = type_specific[type_key]

    return f"""You are a FORENSIC EQUIPMENT IDENTIFICATION SPECIALIST.
You are given TWO images:
- Image 1: Full scene — the complete frame, may show stickers, labels, or text anywhere on the equipment
- Image 2: Enhanced crop — zoomed in on the equipment for closer detail

{brand_hint}

{type_block}

YOUR TASK: Return the SINGLE most accurate brand + model reference.

STEP 1 — SCAN BOTH IMAGES FOR ANY VISIBLE TEXT OR MARKINGS:
Look for ALL of the following in BOTH images:
- Stickers or labels (adhesive, paper, metallic)
- Rating plates or data plates (metal or plastic)
- Engraved or embossed text (molded into the plastic or metal body)
- Stamped markings (pressed into metal panels)
- Printed text on the front panel, door, or casing
- Any alphanumeric code, reference number, or model designation anywhere on the unit
If you find ANY readable text in EITHER image → that is your answer, copy it exactly

STEP 2 — SOURCE PRIORITY:
A) Text readable in Image 1 or Image 2 (sticker, engraving, stamp, print) → copy EXACTLY as seen, letter by letter. Confidence 90%+.
   State which image you read it from: "READ from Image 1" or "READ from Image 2"
B) No text readable in either image → use visual cues + brand training knowledge to identify the most likely real model. Confidence 70-89%.
C) Cannot determine → return capacity/description only (e.g. "380L No-Frost" or "9000BTU Inverter"). Confidence 50-69%.

ABSOLUTE RULES:
- If you READ text from either image: do NOT change it, correct it, or replace it with training knowledge
- If you DEDUCE from training: only suggest models you are certain exist in that brand's catalog
- Return exactly ONE candidate — the most confident
- Brand must never be empty
- Reasoning must explicitly say "READ from Image 1/2: [text seen]" OR "DEDUCED from: [visual features]"

OUTPUT: Valid JSON only, no markdown:
{{
  "brand": "string",
  "equipment_category": "string",
  "model_candidates": [
    {{
      "model": "string",
      "confidence": number,
      "reasoning": "READ from Image 1/2: [exact text seen] OR DEDUCED from: [features used]"
    }}
  ],
  "visual_cues": ["specific things observed in Image 1 and/or Image 2"],
  "detected": true
}}"""


def _run_pass2(client: Groq, full_frame_bytes: bytes, crop_bytes: bytes, equipment_type: str, preliminary_brand: str | None, preliminary_model: str | None = None) -> dict:
    """Deep forensic identification using Groq Llama Vision."""
    b64_full = base64.b64encode(full_frame_bytes).decode('utf-8')
    b64_crop = base64.b64encode(crop_bytes).decode('utf-8')
    prompt = _build_pass2_prompt(equipment_type, preliminary_brand, preliminary_model)
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
            groq_throttle()  # token-bucket: only waits if near the rate cap
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
                max_tokens=500,
                response_format={"type": "json_object"},
            )
            raw = resp.choices[0].message.content.strip()
            return Pass2Result(**json.loads(raw)).model_dump()
        except ValidationError as e:
            print(f"[Pass2] Schema validation failed (attempt {attempt+1}): {e}")
            if attempt < 2:
                time.sleep(5)
                continue
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

def identify_with_groq(annotated_frame: np.ndarray, enhanced_crop: np.ndarray, yolo_type_hint: str | None = None) -> dict:
    """
    Two-pass Groq identification:
      Pass 1: Fast equipment type confirmation + brand visibility check
      Pass 2: Equipment-specific forensic identification (brand + model)
    """
    client = _get_groq_client()

    full_bytes = _img_to_bytes(annotated_frame)
    crop_bytes = _img_to_bytes(enhanced_crop)

    KNOWN_TYPES = {"airconditioner", "refrigerator", "microwave", "laptop", "monitor"}

    # Pass 1 — Fast type + brand visibility check
    print(f"[Vision] Pass 1: Equipment type detection...")
    pass1 = _run_pass1(client, full_bytes)
    print(f"[Vision] Pass 1 result: type='{pass1['equipment_type']}' brand_visible={pass1['brand_visible']} brand='{pass1['preliminary_brand']}' conf={pass1['confidence_type']}%")

    # Resolve equipment type: trust YOLO hint if Pass 1 returns unknown
    pass1_type = pass1.get("equipment_type", "unknown")
    if yolo_type_hint and yolo_type_hint in KNOWN_TYPES:
        eq_type = yolo_type_hint if pass1_type == "unknown" else pass1_type
    else:
        eq_type = pass1_type if pass1_type in KNOWN_TYPES else "unknown"

    preliminary_brand = pass1.get("preliminary_brand") if pass1.get("brand_visible") else None
    preliminary_model = pass1.get("preliminary_model")

    # Pass 2 — Forensic identification: brand + model (deep read with crop)
    print(f"[Vision] Pass 2: Forensic ID for type='{eq_type}' brand='{preliminary_brand}' model_hint='{preliminary_model}'...")
    pass2 = _run_pass2(client, full_bytes, crop_bytes, eq_type, preliminary_brand, preliminary_model)

    # Final category: trust Pass 2 if valid, fallback to resolved type
    pass2_cat = pass2.get("equipment_category", "")
    if pass2_cat not in KNOWN_TYPES:
        pass2["equipment_category"] = eq_type
    pass2["pass1_type_confidence"] = pass1.get("confidence_type", 0)

    return pass2


def process_frame(image_path: str, api_key: str | None = None, yolo_type_hint: str | None = None) -> dict:
    """
    Public entry point — accepts image path, returns full identification result.
    yolo_type_hint: if provided (e.g. 'monitor', 'laptop'), Pass 1 is skipped and
    the hint is used directly as the equipment type for the forensic Pass 2 prompt.
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

    # Pass the clean frame (no annotation) as the full-scene image so the model
    # can read logos/text anywhere without the green box covering them.
    llm_result = identify_with_groq(frame, enhanced_crop, yolo_type_hint=yolo_type_hint)

    return {
        "bbox": {"x": x, "y": y, "w": w, "h": h},
        "annotated_image_b64": encode_image_to_base64(annotated),
        "result": llm_result,
    }

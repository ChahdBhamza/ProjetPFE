"""
test_prompt.py — End-to-end test of the upgraded vision + spec pipeline.

Tests:
  1. Two-pass Gemini vision (Pass 1: type detect, Pass 2: forensic ID)
  2. Schema-aware spec extraction via DuckDuckGo + Gemini
  3. Standardised equipment_result JSON output

Usage:
    cd backend
    venv\\Scripts\\python test_prompt.py [--image PATH] [--skip-specs]

Default test image: dataequipment/climatiseurs/Samsung/images/ (first found)
"""

import sys
import os
import json
import argparse
import time
import io

# ── Force UTF-8 console output for Windows ────────────────────────────────────
if sys.platform.startswith('win'):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# ── Bootstrap path & env ──────────────────────────────────────────────────────
sys.path.insert(0, os.path.dirname(__file__))
from dotenv import load_dotenv
load_dotenv()

# ── CLI args ──────────────────────────────────────────────────────────────────
parser = argparse.ArgumentParser(description="Test the full vision + spec pipeline")
parser.add_argument("--image", type=str, default=None, help="Path to a test image")
parser.add_argument("--skip-specs", action="store_true", help="Skip spec fetch (faster)")
parser.add_argument("--all-samples", action="store_true", help="Run on all sample images found")
args = parser.parse_args()

# ── Locate test images ────────────────────────────────────────────────────────
SAMPLE_DIRS = [
    os.path.join("..", "dataequipment", "climatiseurs", "Samsung", "images"),
    os.path.join("..", "dataequipment", "climatiseurs", "LG", "images"),
    os.path.join("..", "dataequipment", "climatiseurs", "Gree", "images"),
]

def find_sample_images(limit: int = 3) -> list[str]:
    found = []
    for d in SAMPLE_DIRS:
        if os.path.isdir(d):
            for f in sorted(os.listdir(d)):
                if f.lower().endswith((".jpg", ".jpeg", ".png")):
                    found.append(os.path.join(d, f))
                    if not args.all_samples and len(found) >= limit:
                        return found
    return found

if args.image:
    test_images = [args.image]
else:
    test_images = find_sample_images(limit=1 if not args.all_samples else 99)

if not test_images:
    print("ERROR: No test images found. Pass --image <path> or add images to dataequipment/")
    sys.exit(1)

# ── Imports ───────────────────────────────────────────────────────────────────
from app.services.frame_detector import process_frame
from app.services.equipment_schemas import get_schema, normalize_category, CATEGORY_LABELS

def print_section(title: str, char: str = "="):
    w = 64
    print(f"\n{char*w}")
    print(f"  {title}")
    print(f"{char*w}")

def print_equipment_result(eq_result: dict):
    identity = eq_result.get("identity", {})
    specs    = eq_result.get("specs", {})
    meta     = eq_result.get("meta", {})

    category = identity.get("equipment_category", "unknown")
    label    = CATEGORY_LABELS.get(category, category.upper())

    print(f"\n  ┌── IDENTITY {'─'*40}")
    print(f"  │  Category  : {label}")
    print(f"  │  Brand     : {identity.get('brand', '?')}")
    print(f"  │  Top Model : {identity.get('top_model', '?')}")
    print(f"  │  Confidence: {identity.get('confidence', 0)}%")
    print(f"  │  Pass-1 Type Confidence: {identity.get('pass1_type_confidence', 'N/A')}%")

    candidates = identity.get("all_candidates", [])
    if candidates:
        print(f"  │")
        print(f"  │  All Candidates:")
        for i, c in enumerate(candidates, 1):
            print(f"  │    {i}. {c.get('model','?')}  [{c.get('confidence','?')}%]")
            reasoning = c.get("reasoning", "")
            if reasoning:
                for line in reasoning[:120].split(". "):
                    if line.strip():
                        print(f"  │       → {line.strip()}")

    visual_cues = identity.get("visual_cues", [])
    if visual_cues:
        print(f"  │")
        print(f"  │  Visual Cues:")
        for cue in visual_cues:
            print(f"  │    ✦ {cue}")

    if specs:
        print(f"  │")
        print(f"  ├── SPECS {'─'*42}")
        for k, v in specs.items():
            if v is not None:
                print(f"  │  {k:<25} : {v}")
            else:
                print(f"  │  {k:<25} : —")

    if meta.get("fields_found") is not None:
        print(f"  │")
        print(f"  ├── META {'─'*43}")
        print(f"  │  Fields found   : {meta.get('fields_found', 0)}")
        print(f"  │  Source quality : {meta.get('source_quality', 'N/A')}")
        print(f"  │  Pipeline       : {meta.get('pipeline', 'N/A')}")
        if meta.get("summary"):
            print(f"  │  Summary        : {meta['summary']}")
        sources = meta.get("source_urls", [])
        for s in sources[:3]:
            print(f"  │  Source URL     : {s[:80]}")

    print(f"  └{'─'*52}")


# ── Main test loop ────────────────────────────────────────────────────────────
print_section(f"CYBERSIGHT — FULL PIPELINE TEST  ({len(test_images)} image(s))")
print(f"  Skip specs: {args.skip_specs}")

overall_pass = 0
overall_fail = 0

for img_path in test_images:
    print_section(f"IMAGE: {os.path.basename(img_path)}", char="-")

    t0 = time.time()
    try:
        # ── STAGE 1: Two-pass Gemini vision ──────────────────────────────
        print("\n[Stage 1] Running two-pass Gemini vision identification...")
        frame_result = process_frame(img_path)
        llm = frame_result.get("result", {})

        if not llm.get("detected", False):
            print(f"  [✗] No equipment detected: {llm.get('reason', 'unknown reason')}")
            overall_fail += 1
            continue

        category = normalize_category(
            llm.get("equipment_category") or llm.get("equipment_type", "unknown")
        )
        brand = llm.get("brand", "Unknown")
        candidates = llm.get("model_candidates", [])
        top = candidates[0] if candidates else {}
        top_model = top.get("model", "Unknown")

        print(f"  [✓] Detected: {CATEGORY_LABELS.get(category, category)} | Brand: {brand}")
        print(f"  [✓] Top candidate: {top_model} ({top.get('confidence','?')}%)")

        # Build partial equipment_result (no specs yet)
        from app.api.routers.video import build_equipment_result
        equipment_result = build_equipment_result(llm)

        if args.skip_specs:
            print("\n  [Skipping spec fetch — --skip-specs flag set]")
            t1 = time.time()
            print(f"\n  ⏱  Vision stage completed in {t1 - t0:.1f}s")
            print_equipment_result(equipment_result)
            overall_pass += 1
            continue

        # ── STAGE 2: Schema-aware spec fetch ─────────────────────────────
        print(f"\n[Stage 2] Fetching {category} specs from web...")
        from app.services.spec_service import SpecService
        spec_svc = SpecService()
        specs = spec_svc.get_full_identity(
            brand=brand,
            model=top_model,
            equipment_type=category,
        )

        # Merge into final equipment_result
        equipment_result = build_equipment_result(llm, specs)

        t1 = time.time()
        print(f"\n  ⏱  Full pipeline completed in {t1 - t0:.1f}s")

        # ── STAGE 3: Validate canonical schema ───────────────────────────
        canonical = get_schema(category)
        returned_specs = equipment_result.get("specs", {})
        missing_keys = [k for k in canonical if k not in returned_specs]
        extra_keys   = [k for k in returned_specs if k not in canonical]

        if missing_keys:
            print(f"\n  [!] Schema gap — missing keys: {missing_keys}")
        if extra_keys:
            print(f"  [!] Extra keys in output (non-standard): {extra_keys}")
        if not missing_keys:
            print(f"\n  [✓] Schema validation PASSED — all {len(canonical)} canonical keys present")

        # ── STAGE 4: Print full result ────────────────────────────────────
        print_equipment_result(equipment_result)

        # ── STAGE 5: Dump raw JSON for inspection ─────────────────────────
        out_file = os.path.join(
            os.path.dirname(__file__),
            f"scratch/test_result_{os.path.splitext(os.path.basename(img_path))[0][:30]}.json"
        )
        os.makedirs(os.path.dirname(out_file), exist_ok=True)
        with open(out_file, "w", encoding="utf-8") as fout:
            json.dump(equipment_result, fout, ensure_ascii=False, indent=2)
        print(f"\n  [Saved] Raw JSON → {out_file}")

        overall_pass += 1

    except Exception as e:
        print(f"\n  [ERROR] {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        overall_fail += 1

# ── Summary ───────────────────────────────────────────────────────────────────
print_section("RESULTS")
print(f"  Passed : {overall_pass}")
print(f"  Failed : {overall_fail}")
print(f"  Total  : {len(test_images)}")
print()

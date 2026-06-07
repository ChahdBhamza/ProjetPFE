
import os
import sys
import cv2
import argparse
import numpy as np
from pathlib import Path
from PIL import Image
from concurrent.futures import ThreadPoolExecutor
from dotenv import load_dotenv
import time

load_dotenv()

BACKEND_DIR = Path(__file__).parent.parent.parent
sys.path.append(str(BACKEND_DIR))

try:
    from app.services.yolov5_service import YOLOv5Service
    from app.services.roboflow_service import RoboflowService
except ImportError as e:
    print(f"Error: Could not import services. {e}")
    sys.exit(1)

WORKFLOW_ID = "custom-workflow-3"
MAX_FRAMES_TO_PROCESS = 60
ROBOFLOW_PROBE_FRAMES = 10  # sharpest full-res frames sent to Roboflow (coverage for fridge / microwave / AC)
MAX_ROBOFLOW_CALLS = 18
# Per-category hero limits — only computers/monitors may have multiple instances.
# Everything else (fridge, microwave, AC) gets 1 slot to prevent false-positive duplicates.
HEROES_PER_CAT = {
    "computer":        2,
    "tv_monitor":      1,
    "refrigerator":    1,
    "microwave":       1,
    "air_conditioner": 1,
}
DEFAULT_HEROES = 1

# Minimum frame gap between two heroes of the same category.
# Computers use 2 (tighter) so the best frame of each PC is never blocked by the other.
FRAME_GAP_BY_CAT = {
    "computer":   2,
    "tv_monitor": 2,
}
DEFAULT_FRAME_GAP = 4

# Per-category minimum confidence to qualify as a hero (false-positive gate).
HERO_MIN_CONFIDENCE = {
    "refrigerator":    0.30,
    "air_conditioner": 0.40,
    "microwave":       0.30,
    "computer":        0.28,
    "tv_monitor":      0.28,
}

def is_allowed(cls_name):
    name = cls_name.lower()
    whitelist = [
        "laptop", "computer", "pc", "personal computer", "desktop",
        "tv", "monitor", "display", "screen",
        "refrigerator", "fridge", "microwave",
        "conditioner", "air cond", "ac unit", "ac", "oven",
    ]
    return any(kw in name for kw in whitelist) or "ac" in name.split()

def normalize_equipment_class(cls_name):
    name = cls_name.lower().replace("_", " ")
    if "microwave" in name or "oven" in name:
        return "microwave"
    if "fridge" in name or "refrigerator" in name:
        return "refrigerator"
    if "conditioner" in name or "air cond" in name or name in ("ac", "a/c") or " ac" in f" {name} ":
        return "air_conditioner"
    if any(k in name for k in ("laptop", "computer", "pc", "desktop")):
        return "computer"
    if any(k in name for k in ("tv", "monitor", "display", "screen")):
        return "tv_monitor"
    return name

def _iou(bbox_a, bbox_b):
    """Intersection-over-Union for two [x1,y1,x2,y2] boxes."""
    try:
        xa1, ya1, xa2, ya2 = bbox_a
        xb1, yb1, xb2, yb2 = bbox_b
        xi1, yi1 = max(xa1, xb1), max(ya1, yb1)
        xi2, yi2 = min(xa2, xb2), min(ya2, yb2)
        inter = max(0, xi2 - xi1) * max(0, yi2 - yi1)
        area_a = (xa2 - xa1) * (ya2 - ya1)
        area_b = (xb2 - xb1) * (yb2 - yb1)
        union = area_a + area_b - inter
        return inter / max(union, 1e-6)
    except Exception:
        return 0.0


def calculate_center_score(hit, img_w, img_h):
    try:
        if "bbox" not in hit:
            return 0.5
        x1, y1, x2, y2 = hit["bbox"]
        obj_center_x = (x1 + x2) / 2
        obj_center_y = (y1 + y2) / 2
        img_center_x = img_w / 2
        img_center_y = img_h / 2
        dist_x = abs(obj_center_x - img_center_x) / max(img_center_x, 1)
        dist_y = abs(obj_center_y - img_center_y) / max(img_center_y, 1)
        return max(0.0, 1.0 - (dist_x + dist_y) / 2)
    except Exception:
        return 0.5

def frame_sharpness(frame_img):
    gray = cv2.cvtColor(frame_img, cv2.COLOR_BGR2GRAY)
    return cv2.Laplacian(gray, cv2.CV_64F).var()


def bbox_area_frac(hit, img_w, img_h):
    try:
        x1, y1, x2, y2 = hit["bbox"]
        return max(0.0, (x2 - x1) * (y2 - y1)) / max(float(img_w * img_h), 1.0)
    except Exception:
        return 0.0


def object_sharpness(full_bgr, bbox, small_w, small_h):
    """Laplacian variance on the detection crop at full resolution (best signal for blur)."""
    try:
        fh, fw = full_bgr.shape[:2]
        x1, y1, x2, y2 = bbox
        sx = fw / max(small_w, 1)
        sy = fh / max(small_h, 1)
        fx1 = int(max(0, x1 * sx))
        fy1 = int(max(0, y1 * sy))
        fx2 = int(min(fw, x2 * sx))
        fy2 = int(min(fh, y2 * sy))
        if fx2 - fx1 < 8 or fy2 - fy1 < 8:
            return 0.0
        crop = full_bgr[fy1:fy2, fx1:fx2]
        gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
        return float(cv2.Laplacian(gray, cv2.CV_64F).var())
    except Exception:
        return 0.0


def text_region_score(full_bgr, bbox, small_w, small_h):
    """Detect presence of label/sticker text rows in the equipment crop.
    Uses adaptive threshold + horizontal dilation to find word-shaped blobs.
    Returns 0-1: higher means a model plate or rating sticker is visible.
    """
    try:
        fh, fw = full_bgr.shape[:2]
        x1, y1, x2, y2 = bbox
        sx = fw / max(small_w, 1)
        sy = fh / max(small_h, 1)
        fx1 = int(max(0, x1 * sx))
        fy1 = int(max(0, y1 * sy))
        fx2 = int(min(fw, x2 * sx))
        fy2 = int(min(fh, y2 * sy))
        if fx2 - fx1 < 20 or fy2 - fy1 < 20:
            return 0.0
        crop = full_bgr[fy1:fy2, fx1:fx2]
        gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
        thresh = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY_INV, 15, 6
        )
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (18, 3))
        dilated = cv2.dilate(thresh, kernel, iterations=1)
        contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        crop_area = float((fx2 - fx1) * (fy2 - fy1))
        label_area = 0
        for cnt in contours:
            x, y, w, h = cv2.boundingRect(cnt)
            if h < 4 or w < 20:
                continue
            aspect = w / max(h, 1)
            if 2.5 <= aspect <= 30.0 and w * h > 150:
                label_area += w * h
        return min(label_area / max(crop_area * 0.12, 1.0), 1.0)
    except Exception:
        return 0.0


def composite_quality(hit, img_w, img_h, frame_sharp, full_bgr, small_w, small_h):
    """Prefer sharp, confident frames — with a text-label bonus for fridges.
    text_region_score gives a boost to frames where a model sticker is visible,
    so the LLM reads the real reference instead of guessing from appearance.
    """
    conf = float(hit.get("confidence", 0))
    center = calculate_center_score(hit, img_w, img_h)
    area = bbox_area_frac(hit, img_w, img_h)
    obj_sharp = object_sharpness(full_bgr, hit["bbox"], small_w, small_h)
    fs = min(frame_sharp / 400.0, 1.0)
    os_ = min(obj_sharp / 300.0, 1.0)
    ar = min(area / 0.12, 1.0)

    cat = hit.get("_category", "")
    if cat == "refrigerator":
        # text_region_score is the dominant factor for fridges:
        # the frame showing the model sticker must always beat a sharper front-view shot.
        ts = text_region_score(full_bgr, hit["bbox"], small_w, small_h)
        return 0.18 * os_ + 0.10 * fs + 0.12 * conf + 0.06 * center + 0.04 * ar + 0.50 * ts
    return 0.38 * os_ + 0.22 * fs + 0.22 * conf + 0.10 * center + 0.08 * ar

def smart_extract(video_path, output_dir, interval=10, window_size=5, required_hits=3, strict=True, max_frames=MAX_FRAMES_TO_PROCESS, yolo=None, roboflow=None):
    final_dir = os.path.join(output_dir, "final_shots")
    raw_dir = os.path.join(output_dir, "raw")
    if not os.path.exists(final_dir):
        os.makedirs(final_dir)

    for f in os.listdir(final_dir):
        if f.endswith(".png") or f.endswith(".jpg"):
            os.remove(os.path.join(final_dir, f))

    print("Initializing fast hybrid extractor (YOLO scan + Roboflow heroes)")
    total_start = time.time()
    if yolo is None:
        yolo = YOLOv5Service()
    if roboflow is None:
        roboflow = RoboflowService()

    def yolo_scan_frame(f_name):
        f_path = os.path.join(raw_dir, f_name)
        frame_img = cv2.imread(f_path)
        if frame_img is None:
            return None

        try:
            frame_id = int(f_name.split("_")[1].split(".")[0])
        except Exception:
            frame_id = 0

        h, w = frame_img.shape[:2]
        scale = 640 / max(h, w)
        sw, sh = int(w * scale), int(h * scale)
        small = cv2.resize(frame_img, (sw, sh))
        pil_small = Image.fromarray(cv2.cvtColor(small, cv2.COLOR_BGR2RGB))

        hits = []
        fs = frame_sharpness(frame_img)
        for hit in yolo.detect(pil_small):
            if not strict or is_allowed(hit["class"]):
                # Refrigerator guard: YOLO's 0.20 floor is too loose and fires on
                # cabinets/boxes. Require higher confidence AND a meaningful size.
                cat_hit = normalize_equipment_class(hit["class"])
                # YOLO fridge hits are used only to guide Roboflow probe selection.
                # They are tagged _yolo_probe_only so they never become hero candidates.
                if cat_hit == "refrigerator":
                    hit["_obj_sharp"] = object_sharpness(frame_img, hit["bbox"], sw, sh)
                    hit["_quality"] = composite_quality(hit, sw, sh, fs, frame_img, sw, sh)
                    hit["_yolo_probe_only"] = True
                    hits.append(hit)
                    continue
                if cat_hit == "microwave":
                    if hit.get("confidence", 0) < 0.30:
                        continue
                    if bbox_area_frac(hit, sw, sh) < 0.04:
                        continue
                hit["_obj_sharp"] = object_sharpness(frame_img, hit["bbox"], sw, sh)
                hit["_quality"] = composite_quality(hit, sw, sh, fs, frame_img, sw, sh)
                hits.append(hit)

        return {
            "frame": frame_img,
            "hits": hits,
            "id": frame_id,
            "w": sw,
            "h": sh,
            "sharp": fs,
            "f_name": f_name,
        }

    def roboflow_probe(data):
        """Full-res cloud workflow: detections + official annotated image."""
        pil_full = Image.fromarray(cv2.cvtColor(data["frame"], cv2.COLOR_BGR2RGB))
        res = roboflow.detect(pil_full, workflow_id=WORKFLOW_ID, quiet=True)
        if "error" in res:
            return data["id"], [], None

        hits = []
        fh, fw = data["frame"].shape[:2]
        fs = data["sharp"]
        for hit in res.get("detections", []):
            cls_lower = hit.get("class", "").lower()
            _is_ac = any(k in cls_lower for k in ("air_conditioner", "airconditioner", " ac", "conditioner"))
            _is_fridge = any(k in cls_lower for k in ("fridge", "refrigerator"))
            if _is_ac:
                _min_conf = 0.45
            elif _is_fridge:
                _min_conf = 0.30
            else:
                _min_conf = 0.60
            rf_cat = normalize_equipment_class(hit["class"])
            conf = hit.get("confidence", 0)
            area = bbox_area_frac(hit, fw, fh)
            print(f"[RF f{data['id']:04d}] class={hit['class']} cat={rf_cat} conf={conf:.3f} area={area:.3f} min_conf={_min_conf:.2f}")
            if conf < _min_conf:
                print(f"  → SKIP low confidence")
                continue
            if rf_cat == "refrigerator" and area < 0.05:
                print(f"  → SKIP fridge too small")
                continue
            if rf_cat == "microwave" and area < 0.04:
                print(f"  → SKIP microwave too small")
                continue
            if not strict or is_allowed(hit["class"]):
                hit["_source"] = "roboflow"
                hit["_obj_sharp"] = object_sharpness(data["frame"], hit["bbox"], fw, fh)
                hit["_quality"] = composite_quality(hit, fw, fh, fs, data["frame"], fw, fh)
                print(f"  → ACCEPTED quality={hit['_quality']:.3f}")
                hits.append(hit)

        ann_pil = RoboflowService.decode_annotated_image(res.get("image"))
        return data["id"], hits, ann_pil

    global_pool = []
    rf_annotated_by_id = {}

    if not os.path.exists(raw_dir):
        print("ERROR: FFmpeg raw directory not found!")
        return

    frame_files = sorted([f for f in os.listdir(raw_dir) if f.endswith((".jpg", ".png"))])
    if interval > 1:
        frame_files = frame_files[::interval]
    cap = max(1, int(max_frames))
    if len(frame_files) > cap:
        step = max(1, len(frame_files) // cap)
        frame_files = frame_files[::step][:cap]

    print(f"[Pass 1] YOLO on {len(frame_files)} frames (local)...")
    t1 = time.time()
    yolo_results = []
    with ThreadPoolExecutor(max_workers=4) as executor:
        for data in executor.map(yolo_scan_frame, frame_files):
            if data:
                yolo_results.append(data)

    for data in yolo_results:
        for hit in data["hits"]:
            hit["_frame"] = data["frame"]
            hit["_frame_id"] = data["id"]
            hit["_source"] = "yolo"
            hit["_category"] = normalize_equipment_class(hit["class"])
            global_pool.append(hit)

    print(f"[Pass 1] Done in {time.time() - t1:.1f}s | yolo pool={len(global_pool)}")

    # Cloud probes: best frame per category + sharpest frames (microwave often appears here)
    best_by_cat = {}
    for hit in global_pool:
        cat = hit["_category"]
        if cat not in best_by_cat or hit["_quality"] > best_by_cat[cat]["_quality"]:
            best_by_cat[cat] = hit

    probe_ids = {h["_frame_id"] for h in best_by_cat.values()}
    sharp_sorted = sorted(yolo_results, key=lambda d: d["sharp"], reverse=True)
    for data in sharp_sorted[:ROBOFLOW_PROBE_FRAMES]:
        probe_ids.add(data["id"])

    # Temporal coverage: evenly spread probes across the whole video so that
    # YOLO-invisible classes (e.g. air_conditioner) still reach Roboflow.
    if yolo_results:
        coverage_step = max(1, len(yolo_results) // ROBOFLOW_PROBE_FRAMES)
        for data in yolo_results[::coverage_step][:ROBOFLOW_PROBE_FRAMES]:
            probe_ids.add(data["id"])

    # Extra coverage: best frames for fridge / microwave (often missed by global sharp sort)
    for target_cat in ("refrigerator", "microwave"):
        ranked = []
        for data in yolo_results:
            for hit in data["hits"]:
                if normalize_equipment_class(hit["class"]) == target_cat:
                    ranked.append((hit["_quality"], data["id"]))
        ranked.sort(reverse=True)
        for _, fid in ranked[:6]:
            probe_ids.add(fid)

    probe_ids = list(probe_ids)[:MAX_ROBOFLOW_CALLS]

    id_to_data = {d["id"]: d for d in yolo_results}
    probe_list = [id_to_data[fid] for fid in probe_ids if fid in id_to_data]
    print(f"[Pass 2] Roboflow on {len(probe_list)} full-res frames (annotated output)...")
    t2 = time.time()

    with ThreadPoolExecutor(max_workers=3) as executor:
        for frame_id, rf_hits, ann_pil in executor.map(roboflow_probe, probe_list):
            if ann_pil is not None:
                rf_annotated_by_id[frame_id] = ann_pil
            for hit in rf_hits:
                base = id_to_data.get(frame_id)
                if not base:
                    continue
                hit["_frame"] = base["frame"]
                hit["_frame_id"] = frame_id
                hit["_category"] = normalize_equipment_class(hit["class"])

                # [STRICT SAFEGUARD] Stop Roboflow from mislabelling objects based on YOLO ground truth.
                # Only override if YOLO's conflicting box *overlaps* the AC box — avoids silently
                # discarding a real AC when a different object (e.g. laptop) also exists in the frame.
                yolo_hits_on_frame = base["hits"]
                if hit["_category"] == "air_conditioner":
                    rf_bbox = hit.get("bbox", [0, 0, 0, 0])
                    for yh in yolo_hits_on_frame:
                        yolo_cat = normalize_equipment_class(yh["class"])
                        if yolo_cat not in ("refrigerator", "computer", "tv_monitor", "microwave"):
                            continue
                        iou_val = _iou(rf_bbox, yh.get("bbox", [0, 0, 0, 0]))
                        if iou_val > 0.55:
                            print(f"🚫 SAFEGUARD: Overriding Roboflow 'air_conditioner' → '{yolo_cat}' (IoU={iou_val:.2f}, YOLO saw {yolo_cat} on same region)")
                            hit["_category"] = yolo_cat
                            hit["class"] = "laptop" if yolo_cat == "computer" else ("tv" if yolo_cat == "tv_monitor" else yolo_cat)
                            hit["_force_local_draw"] = True
                            break

                # If safeguard triggered, discard the bad Roboflow annotated image
                if hit.get("_force_local_draw"):
                    hit["_rf_annotated"] = None
                else:
                    hit["_rf_annotated"] = ann_pil
                global_pool.append(hit)

    print(f"[Pass 2] Done in {time.time() - t2:.1f}s | total pool={len(global_pool)}")

    # ── Hero Selection ────────────────────────────────────────────────────────
    def _hero_score(c):
        """Combined ranking: quality (visual clarity) + confidence (model certainty).
        Prevents a sharp false positive from beating a confident true detection."""
        return 0.70 * c["_quality"] + 0.30 * c.get("confidence", 0)

    by_cat = {}
    for candidate in sorted(
        [c for c in global_pool if not c.get("_yolo_probe_only")],
        key=lambda x: (x.get("_source") != "roboflow", -_hero_score(x))
    ):
        cat = candidate.get("_category") or normalize_equipment_class(candidate["class"])

        if candidate["_quality"] < 0.18:
            print(f"⚠️ SKIP: '{cat}' candidate on frame {candidate['_frame_id']} rejected due to low quality ({candidate['_quality']:.2f})")
            continue

        min_conf = HERO_MIN_CONFIDENCE.get(cat, 0.25)
        if candidate.get("confidence", 0) < min_conf:
            print(f"⚠️ SKIP: '{cat}' candidate on frame {candidate['_frame_id']} rejected due to low confidence ({candidate.get('confidence', 0):.2f} < {min_conf})")
            continue

        max_heroes = HEROES_PER_CAT.get(cat, DEFAULT_HEROES)
        frame_gap  = FRAME_GAP_BY_CAT.get(cat, DEFAULT_FRAME_GAP)
        existing = by_cat.get(cat, [])
        fid = candidate["_frame_id"]
        too_close = any(abs(fid - h["_frame_id"]) < frame_gap for h in existing)
        if len(existing) < max_heroes and not too_close:
            existing.append(candidate)
            by_cat[cat] = existing

    # Cross-frame screen dedup
    if "computer" in by_cat and "tv_monitor" in by_cat:
        print("🚫 CROSS-FRAME DEDUP: Both 'computer' and 'tv_monitor' detected — dropping 'tv_monitor' (same physical screen device)")
        del by_cat["tv_monitor"]

    # Final IoU pass: drop heroes that still overlap > 50% on the same frame
    heroes_list = sorted(
        [h for heroes in by_cat.values() for h in heroes],
        key=lambda h: -_hero_score(h)
    )
    final_heros = []
    for hero in heroes_list:
        dominated = False
        for kept in final_heros:
            if hero["_frame_id"] == kept["_frame_id"]:
                iou = _iou(hero.get("bbox", [0, 0, 0, 0]), kept.get("bbox", [0, 0, 0, 0]))
                if iou > 0.50:
                    print(f"🚫 DEDUP: Dropping '{hero.get('_category')}' hero (IoU={iou:.2f} with '{kept.get('_category')}' on frame {hero['_frame_id']})")
                    dominated = True
                    break
        if not dominated:
            final_heros.append(hero)

    # ── Refrigerator label refinement ─────────────────────────────────────────
    # The Roboflow hero is the sharpest clear-front-view frame, but the frame
    # showing the model plate (e.g. "MP0500") is often a neighbor frame.
    # Scan ±5 raw frames around each fridge hero and swap to the one with the
    # highest text_region_score — no re-probing Roboflow needed.
    FRIDGE_REFINE_WINDOW = 5
    for hero in final_heros:
        if hero.get("_category") != "refrigerator":
            continue
        hero_fid = hero["_frame_id"]
        h_fw = hero["_frame"].shape[1]
        h_fh = hero["_frame"].shape[0]
        hero_bbox = hero.get("bbox", [0, 0, h_fw, h_fh])
        hero_ts = text_region_score(hero["_frame"], hero_bbox, h_fw, h_fh)
        print(f"[Fridge Refine] Hero f{hero_fid:04d} text_score={hero_ts:.3f} — scanning ±{FRIDGE_REFINE_WINDOW} neighbors...")

        best_ts = hero_ts
        best_fid = hero_fid
        best_frame = hero["_frame"]

        for delta in range(-FRIDGE_REFINE_WINDOW, FRIDGE_REFINE_WINDOW + 1):
            if delta == 0:
                continue
            adj_fid = hero_fid + delta
            if adj_fid not in id_to_data:
                continue
            adj_frame = id_to_data[adj_fid]["frame"]
            a_fw = adj_frame.shape[1]
            a_fh = adj_frame.shape[0]
            adj_ts = text_region_score(adj_frame, hero_bbox, a_fw, a_fh)
            print(f"[Fridge Refine]   f{adj_fid:04d} text_score={adj_ts:.3f}")
            if adj_ts > best_ts + 0.08:
                best_ts = adj_ts
                best_fid = adj_fid
                best_frame = adj_frame

        if best_fid != hero_fid:
            print(f"🔄 FRIDGE REFINEMENT: f{hero_fid:04d} → f{best_fid:04d} (text_score {hero_ts:.3f} → {best_ts:.3f})")
            hero["_frame"] = best_frame
            hero["_frame_id"] = best_fid

    print(f"Saving {len(final_heros)} heroes with clean local annotations for UI consistency...")
    t3 = time.time()
    for idx, hero in enumerate(final_heros):
        fid = hero["_frame_id"]
        cat = hero.get("_category") or normalize_equipment_class(hero["class"])

        pil_hero = Image.fromarray(cv2.cvtColor(hero["_frame"], cv2.COLOR_BGR2RGB))
        clean_label = cat.replace('_', ' ').title()
        hero_to_draw = hero.copy()
        hero_to_draw['class'] = clean_label

        out_img = yolo.draw_detections(pil_hero, [hero_to_draw])

        filename = f"hero_{idx + 1}_{cat}_f{fid:04d}.png"
        cv2.imwrite(os.path.join(final_dir, filename), cv2.cvtColor(np.array(out_img), cv2.COLOR_RGB2BGR))
        print(f"SAVED: {filename} (Quality: {hero['_quality']:.2f}, label: {clean_label})")

    t_end = time.time()
    print(f"[TIMER] Save took {t_end - t3:.1f}s | Total: {t_end - total_start:.1f}s")
    print(f"Done! Captured {len(final_heros)} forensic shots.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fast hybrid extractor")
    parser.add_argument("--input", required=True, help="Path to input video")
    parser.add_argument("--output", default="smart_test_results", help="Output directory")
    parser.add_argument("--interval", type=int, default=10, help="Process every Nth extracted frame")
    parser.add_argument("--max-frames", type=int, default=MAX_FRAMES_TO_PROCESS, help="Cap YOLO scans")
    parser.add_argument("--strict", type=int, default=1, help="1 for forensic whitelist")

    args = parser.parse_args()
    smart_extract(args.input, args.output, args.interval, strict=(args.strict == 1), max_frames=args.max_frames)

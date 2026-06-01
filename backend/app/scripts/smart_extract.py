
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
MAX_FRAMES_TO_PROCESS = 15
ROBOFLOW_PROBE_FRAMES = 4  # sharpest full-res frames sent to Roboflow (coverage for fridge / microwave / AC)
MAX_ROBOFLOW_CALLS = 5

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


def composite_quality(hit, img_w, img_h, frame_sharp, full_bgr, small_w, small_h):
    """Prefer sharp, confident, reasonably large subjects (reduces blurry tiny boxes)."""
    conf = float(hit.get("confidence", 0))
    center = calculate_center_score(hit, img_w, img_h)
    area = bbox_area_frac(hit, img_w, img_h)
    obj_sharp = object_sharpness(full_bgr, hit["bbox"], small_w, small_h)
    # Normalize typical ranges so scores stay in ~0..1
    fs = min(frame_sharp / 400.0, 1.0)
    os_ = min(obj_sharp / 300.0, 1.0)
    ar = min(area / 0.12, 1.0)  # large appliance ~10–40% of frame
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
            _min_conf = 0.45 if _is_ac else 0.60
            if hit.get("confidence", 0) < _min_conf:
                continue
            if not strict or is_allowed(hit["class"]):
                hit["_source"] = "roboflow"
                # bbox already in full-res coordinates from Roboflow
                hit["_obj_sharp"] = object_sharpness(data["frame"], hit["bbox"], fw, fh)
                hit["_quality"] = composite_quality(hit, fw, fh, fs, data["frame"], fw, fh)
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

    # Extra coverage: best frames for fridge / microwave (often missed by global sharp sort)
    for target_cat in ("refrigerator", "microwave"):
        ranked = []
        for data in yolo_results:
            for hit in data["hits"]:
                if normalize_equipment_class(hit["class"]) == target_cat:
                    ranked.append((hit["_quality"], data["id"]))
        ranked.sort(reverse=True)
        for _, fid in ranked[:4]:
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
                        if iou_val > 0.35:
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
    # Duplicates across categories are already suppressed by YOLO's per-frame
    # IoU dedup (yolov5_service.py). Here we simply pick the best hero per
    # category, then do a final IoU cross-check to drop any stragglers that
    # slipped through on the same frame.

    # Best hero per raw category (no merging — each category keeps its own slot)
    by_cat = {}
    for candidate in sorted(global_pool, key=lambda x: (x.get("_source") != "roboflow", -x["_quality"])):
        cat = candidate.get("_category") or normalize_equipment_class(candidate["class"])
        
        # Filter out extremely low quality / blurry candidates to prevent false positive heroes
        if candidate["_quality"] < 0.28:
            print(f"⚠️ SKIP: '{cat}' candidate on frame {candidate['_frame_id']} rejected due to low quality ({candidate['_quality']:.2f})")
            continue
            
        if cat not in by_cat:
            by_cat[cat] = candidate

    # Cross-frame screen dedup: if both 'computer' and 'tv_monitor' survived
    # (same physical laptop detected across different frames), drop tv_monitor.
    # 'computer'/'laptop' is the more specific COCO class for a laptop screen.
    if "computer" in by_cat and "tv_monitor" in by_cat:
        print("🚫 CROSS-FRAME DEDUP: Both 'computer' and 'tv_monitor' detected — dropping 'tv_monitor' (same physical screen device)")
        del by_cat["tv_monitor"]

    # Final IoU pass: drop heroes that still overlap > 50% on the same frame
    heroes_list = sorted(by_cat.values(), key=lambda h: -h["_quality"])
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

    print(f"Saving {len(final_heros)} heroes with clean local annotations for UI consistency...")
    t3 = time.time()
    for idx, hero in enumerate(final_heros):
        fid = hero["_frame_id"]
        cat = hero.get("_category") or normalize_equipment_class(hero["class"])

        # Always draw locally to ensure exactly ONE bounding box with a clean, consistent style.
        # This completely avoids double/overlapping bounding boxes of different colors from the cloud.
        pil_hero = Image.fromarray(cv2.cvtColor(hero["_frame"], cv2.COLOR_BGR2RGB))
        
        # Format a premium capitalized label (e.g., "Air Conditioner", "Microwave")
        clean_label = cat.replace('_', ' ').title()
        
        # Create a draw-copy so we don't modify the source candidate data
        hero_to_draw = hero.copy()
        hero_to_draw['class'] = clean_label

        out_img = yolo.draw_detections(pil_hero, [hero_to_draw])

        # Encode the frame ID inside the filename (e.g., hero_1_microwave_f0042.png)
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

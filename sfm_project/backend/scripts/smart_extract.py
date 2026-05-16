import os
import sys
import cv2
import argparse
import numpy as np
import shutil
from pathlib import Path
from PIL import Image
from concurrent.futures import ThreadPoolExecutor
from dotenv import load_dotenv

# Load API keys from .env
load_dotenv()

# Add directories to path
ROOT_DIR = Path(__file__).parent.parent.parent.parent
BACKEND_DIR = ROOT_DIR / "backend"
sys.path.append(str(BACKEND_DIR))

try:
    from app.services.yolov5_service import YOLOv5Service
    from app.services.roboflow_service import RoboflowService
except ImportError as e:
    print(f"Error: Could not import services. {e}")
    sys.exit(1)

# --- THE FORENSIC WHITELIST ---
def is_allowed(cls_name):
    name = cls_name.lower()
    whitelist = [
        "laptop", "computer", "pc", "personal computer", "desktop", 
        "tv", "monitor", "display", "screen",
        "refrigerator", "fridge", "microwave", 
        "conditioner", "air cond", "ac unit", "ac"
    ]
    return any(kw in name for kw in whitelist) or "ac" in name.split()

def calculate_center_score(hit, img_w, img_h):
    try:
        if 'x' in hit: # Roboflow center
            obj_center_x, obj_center_y = hit['x'], hit['y']
        elif 'bbox' in hit: # YOLO corners
            x1, y1, x2, y2 = hit['bbox']
            obj_center_x, obj_center_y = (x1 + x2) / 2, (y1 + y2) / 2
        else: return 0.5
        
        img_center_x, img_center_y = img_w / 2, img_h / 2
        dist_x = abs(obj_center_x - img_center_x) / img_center_x
        dist_y = abs(obj_center_y - img_center_y) / img_center_y
        return 1.0 - (dist_x + dist_y) / 2
    except: return 0.5

def smart_extract(video_path, output_dir, interval=10, window_size=5, required_hits=3, strict=True):
    final_dir = os.path.join(output_dir, "final_shots")
    raw_dir = os.path.join(output_dir, "raw") # Created by endpoints.py via FFmpeg
    if not os.path.exists(final_dir): os.makedirs(final_dir)
    
    for f in os.listdir(final_dir):
        if f.endswith(".png") or f.endswith(".jpg"): os.remove(os.path.join(final_dir, f))
    
    print(f"Initializing V3 Hybrid Extractor (FFmpeg + Diverse Gallery)")
    yolo = YOLOv5Service()
    roboflow = RoboflowService()
    WORKFLOW_ID = "custom-workflow-3"

    executor = ThreadPoolExecutor(max_workers=4)
    futures = []
    global_pool = []

    def process_frame_ai(f_name):
        f_path = os.path.join(raw_dir, f_name)
        frame_img = cv2.imread(f_path)
        if frame_img is None: return None
        
        # Get frame id from filename e.g. frame_0001.jpg
        try: frame_id = int(f_name.split("_")[1].split(".")[0])
        except: frame_id = 0

        h, w = frame_img.shape[:2]
        scale = 640 / max(h, w)
        small_frame = cv2.resize(frame_img, (int(w * scale), int(h * scale)))
        pil_img = Image.fromarray(cv2.cvtColor(small_frame, cv2.COLOR_BGR2RGB))
        
        y_hits = yolo.detect(pil_img)
        res = roboflow.detect(pil_img, workflow_id=WORKFLOW_ID)
        rf_hits = res.get("detections", [])
        
        # Filter out hits that have no actual bounding box (0 area)
        valid_hits = []
        for h_obj in (y_hits + rf_hits):
            if 'bbox' in h_obj:
                x1, y1, x2, y2 = h_obj['bbox']
                if abs(x2 - x1) < 5 or abs(y2 - y1) < 5: continue # Reject fake boxes
            valid_hits.append(h_obj)
            
        return {"frame": frame_img, "hits": valid_hits, "id": frame_id, "w": w, "h": h}

    if os.path.exists(raw_dir):
        frame_files = sorted([f for f in os.listdir(raw_dir) if f.endswith((".jpg", ".png"))])
        print(f"Parallel scanning {len(frame_files)} FFmpeg frames (4 Workers)...")
        
        for f_name in frame_files:
            futures.append(executor.submit(process_frame_ai, f_name))
            
        for f in futures:
            try:
                data = f.result()
                if not data: continue
                
                all_hits = data["hits"]
                if all_hits:
                    print(f"AI DEBUG: Frame {data['id']} sees: {', '.join([f'{h['class']} ({h['confidence']:.2f})' for h in all_hits])}")

                for hit in all_hits:
                    if not strict or is_allowed(hit['class']):
                        hit["_frame"] = data["frame"]
                        hit["_frame_id"] = data["id"]
                        center = calculate_center_score(hit, data["w"], data["h"])
                        hit["_quality"] = (hit["confidence"] * 0.7) + (center * 0.3)
                        global_pool.append(hit)
            except Exception as e:
                print(f"Worker Error: {e}")
    else:
        print("ERROR: FFmpeg raw directory not found!")
        
    executor.shutdown()
    
    print(f"\nCollecting Best Forensic Evidence (1 Per Equipment)...")
    global_pool.sort(key=lambda x: x["_quality"], reverse=True)
    
    final_heros = []
    for candidate in global_pool:
        class_count = sum(1 for p in final_heros if p['class'] == candidate['class'])
        if class_count >= 1: continue # Only take the absolute best shot for this equipment
                
        final_heros.append(candidate)

    print(f"\nSaving Aligned Forensic Heroes (PNG)...")
    for idx, hero in enumerate(final_heros):
        h_orig, w_orig = hero["_frame"].shape[:2]
        scale = max(h_orig, w_orig) / 640.0
        
        sh = hero.copy()
        if 'x' in sh:
            sh['x'] *= scale
            sh['y'] *= scale
            sh['width'] *= scale
            sh['height'] *= scale
            sh['bbox'] = [sh['x']-sh['width']/2, sh['y']-sh['height']/2, sh['x']+sh['width']/2, sh['y']+sh['height']/2]
        elif 'bbox' in sh:
            x1, y1, x2, y2 = sh['bbox']
            sh['bbox'] = [x1 * scale, y1 * scale, x2 * scale, y2 * scale]

        pil_hero = Image.fromarray(cv2.cvtColor(hero["_frame"], cv2.COLOR_BGR2RGB))
        annotated_pil = roboflow.draw_detections(pil_hero, [sh])
        
        filename = f"hero_{idx+1}_{hero['class'].replace(' ', '_')}.png"
        cv2.imwrite(os.path.join(final_dir, filename), cv2.cvtColor(np.array(annotated_pil), cv2.COLOR_RGB2BGR))
        print(f"SAVED: {filename} (Quality: {hero['_quality']:.2f})")

    print(f"\nDone! Captured {len(final_heros)} Diverse Forensic Shots.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Classic Diverse Extractor")
    parser.add_argument("--input", required=True, help="Path to input video")
    parser.add_argument("--output", default="smart_test_results", help="Output directory")
    parser.add_argument("--interval", type=int, default=10, help="Check every Nth frame")
    parser.add_argument("--strict", type=int, default=1, help="1 for forensic whitelist")
    
    args = parser.parse_args()
    smart_extract(args.input, args.output, args.interval, strict=(args.strict == 1))

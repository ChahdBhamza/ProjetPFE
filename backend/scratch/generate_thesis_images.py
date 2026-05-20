import os
import sys
import cv2
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
from PIL import Image

# Setup Paths
BACKEND_DIR = Path(r"c:\Users\chahd\Desktop\DetectionAppPFE\backend")
sys.path.insert(0, str(BACKEND_DIR))
from app.services.yolov5_service import YOLOv5Service
from app.services.roboflow_service import RoboflowService
from app.services.vision_rag_service import VisionRAGService

VIDEO_PATH = BACKEND_DIR / "uploads" / "f4603c58-571f-4082-b29a-1b4c67529cc7.mp4"
FIG_DIR = BACKEND_DIR.parent / "docs" / "figures"
os.makedirs(FIG_DIR, exist_ok=True)

cap = cv2.VideoCapture(str(VIDEO_PATH))

# --- FIG 1: TEMPORAL REDUNDANCY ---
fig, axes = plt.subplots(1, 3, figsize=(15, 5))
for i, f_idx in enumerate([100, 101, 102]):
    cap.set(cv2.CAP_PROP_POS_FRAMES, f_idx)
    _, frame = cap.read()
    axes[i].imshow(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
    axes[i].set_title(f"Frame {f_idx}")
    axes[i].axis('off')
plt.suptitle("Temporal Redundancy: 3 consecutive frames at 30fps")
plt.tight_layout()
plt.savefig(FIG_DIR / "thesis_temporal_redundancy.png", dpi=150)
plt.close()

# --- FIG 2: LAPLACIAN VARIANCE ---
def get_sharpness(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    return cv2.Laplacian(gray, cv2.CV_64F).var()

cap.set(cv2.CAP_PROP_POS_FRAMES, 42)
_, blur_frame = cap.read()
blur_score = get_sharpness(blur_frame)

cap.set(cv2.CAP_PROP_POS_FRAMES, 96)
_, sharp_frame = cap.read()
sharp_score = get_sharpness(sharp_frame)

fig, axes = plt.subplots(1, 2, figsize=(16, 7))
axes[0].imshow(cv2.cvtColor(blur_frame, cv2.COLOR_BGR2RGB))
axes[0].set_title(f"Frame 42 (Mid-Pan) | S = {blur_score:.2f}", color='red')
axes[0].axis('off')
axes[1].imshow(cv2.cvtColor(sharp_frame, cv2.COLOR_BGR2RGB))
axes[1].set_title(f"Frame 96 (Stabilized) | S = {sharp_score:.2f}", color='green')
axes[1].axis('off')
plt.suptitle("Laplacian Variance Filter in Action")
plt.tight_layout()
plt.savefig(FIG_DIR / "thesis_laplacian_filter.png", dpi=150)
plt.close()

# --- FIG 3: YOLO GATEKEEPER ---
print("Running YOLO...")
yolo = YOLOv5Service()
cap.set(cv2.CAP_PROP_POS_FRAMES, 15)
_, empty_frame = cap.read()
empty_rgb = cv2.cvtColor(empty_frame, cv2.COLOR_BGR2RGB)
pil_empty = Image.fromarray(empty_rgb)
empty_hits = yolo.detect(pil_empty)
empty_drawn = yolo.draw_detections(pil_empty, empty_hits)

sharp_rgb = cv2.cvtColor(sharp_frame, cv2.COLOR_BGR2RGB)
pil_sharp = Image.fromarray(sharp_rgb)
sharp_hits = yolo.detect(pil_sharp)
sharp_drawn = yolo.draw_detections(pil_sharp, sharp_hits)

fig, axes = plt.subplots(1, 2, figsize=(16, 7))
axes[0].imshow(empty_drawn)
axes[0].set_title(f"Frame 15 | Sharpness: {get_sharpness(empty_frame):.1f} | YOLO Detections: {len(empty_hits)}")
axes[0].axis('off')
axes[1].imshow(sharp_drawn)
axes[1].set_title(f"Frame 96 | Sharpness: {sharp_score:.1f} | YOLO Detections: {len(sharp_hits)}")
axes[1].axis('off')
plt.suptitle("YOLOv5 Gatekeeper: Filtering Out Empty & Blurry Frames")
plt.tight_layout()
plt.savefig(FIG_DIR / "thesis_yolo_gatekeeper.png", dpi=150)
plt.close()

# --- FIG 4: ROBOFLOW CLOUD INFERENCE ---
print("Running Roboflow...")
rf = RoboflowService()
rf_res = rf.detect(pil_sharp, workflow_id="custom-workflow-3")
rf_hits = rf_res.get('detections', [])
if rf_hits:
    rf_drawn = yolo.draw_detections(pil_sharp, rf_hits) # use yolo's drawing util for visualization
    plt.figure(figsize=(10, 8))
    plt.imshow(rf_drawn)
    plt.title("Roboflow Cloud API Detection (Hero Frame)")
    plt.axis('off')
    plt.savefig(FIG_DIR / "thesis_roboflow_output.png", dpi=150)
    plt.close()

# --- FIG 5: CLAHE ENHANCEMENT ---
print("Running CLAHE...")
vision_rag = VisionRAGService()
if sharp_hits:
    best_hit = max(sharp_hits, key=lambda x: x['confidence'])
    x1, y1, x2, y2 = [int(v) for v in best_hit['bbox']]
    raw_crop_bgr = sharp_frame[y1:y2, x1:x2]
    enhanced_crop_bgr = vision_rag.enhance_crop_for_ocr(raw_crop_bgr)
    
    fig, axes = plt.subplots(1, 2, figsize=(14, 8))
    axes[0].imshow(cv2.cvtColor(raw_crop_bgr, cv2.COLOR_BGR2RGB))
    axes[0].set_title("Raw Bounding Box Crop (Low Contrast)")
    axes[0].axis('off')
    axes[1].imshow(cv2.cvtColor(enhanced_crop_bgr, cv2.COLOR_BGR2RGB))
    axes[1].set_title("Enhanced Crop (CLAHE + Lanczos4 Upscale)")
    axes[1].axis('off')
    plt.suptitle("Preparing Visual Data for the LLM")
    plt.tight_layout()
    plt.savefig(FIG_DIR / "thesis_clahe_enhancement.png", dpi=150)
    plt.close()

cap.release()
print("All figures generated successfully to docs/figures/")

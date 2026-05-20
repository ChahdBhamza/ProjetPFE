import os
import sys
import cv2
import numpy as np
from pathlib import Path
from PIL import Image
import matplotlib.pyplot as plt

# Setup Paths
BACKEND_DIR = Path(r"c:\Users\chahd\Desktop\DetectionAppPFE\backend")
sys.path.insert(0, str(BACKEND_DIR))

from app.services.yolov5_service import YOLOv5Service

VIDEO_PATH = BACKEND_DIR / "uploads" / "f4603c58-571f-4082-b29a-1b4c67529cc7.mp4"
FIGURE_PATH = BACKEND_DIR.parent / "docs" / "figures" / "real_aspect_ratio.png"
SCREENSHOT_DIR = BACKEND_DIR.parent / "docs" / "figures"

# Initialize YOLOv5
print("Initializing YOLOv5...")
yolo_service = YOLOv5Service()

# Open Video
cap = cv2.VideoCapture(str(VIDEO_PATH))
total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
fps = cap.get(cv2.CAP_PROP_FPS)

print(f"Loaded video: {total_frames} frames @ {fps} fps")

aspect_ratios = {}
frame_interval = 4 # Process every 4th frame for a dense enough sample
detections_count = 0

print("Processing frames...")
for frame_idx in range(0, total_frames, frame_interval):
    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
    ret, frame = cap.read()
    if not ret:
        continue
    
    # Convert BGR to RGB for PIL
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    pil_image = Image.fromarray(rgb_frame)
    
    # Run YOLOv5 Inference
    detections = yolo_service.detect(pil_image)
    
    if detections:
        # Save a screenshot for the first good detection
        if detections_count == 0:
            drawn = yolo_service.draw_detections(pil_image, detections)
            screenshot_path = SCREENSHOT_DIR / "real_detection_screenshot.png"
            drawn.save(screenshot_path)
            print(f"Saved real screenshot to {screenshot_path}")
            
        for det in detections:
            cls_name = det['class']
            x1, y1, x2, y2 = det['bbox']
            width = x2 - x1
            height = y2 - y1
            
            if height > 0:
                ar = width / height
                if cls_name not in aspect_ratios:
                    aspect_ratios[cls_name] = []
                aspect_ratios[cls_name].append(ar)
                detections_count += 1
                
cap.release()

print("\n--- Real Aspect Ratio Stats ---")
if not aspect_ratios:
    print("No detections found!")
else:
    for cls_name, ars in aspect_ratios.items():
        print(f"Class: {cls_name:<15} | Count: {len(ars):<3} | Mean AR: {np.mean(ars):.3f} | Min: {np.min(ars):.3f} | Max: {np.max(ars):.3f}")

    # Generate Plot
    plt.figure(figsize=(10, 6))
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728']
    
    for i, (cls_name, ars) in enumerate(aspect_ratios.items()):
        plt.hist(ars, bins=15, alpha=0.7, label=f"{cls_name} (n={len(ars)})", color=colors[i % len(colors)])
        
    plt.title("Real Bounding Box Aspect Ratios (from Uploaded Video)")
    plt.xlabel("Aspect Ratio (Width/Height)")
    plt.ylabel("Frequency")
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # Save the figure
    os.makedirs(FIGURE_PATH.parent, exist_ok=True)
    plt.savefig(FIGURE_PATH, dpi=150, bbox_inches='tight')
    print(f"\nSaved real distribution plot to {FIGURE_PATH}")
    
    print("\nScript completed successfully.")

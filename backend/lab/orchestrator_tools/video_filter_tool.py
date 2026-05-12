import sys
import os
from pathlib import Path
from PIL import Image
import io
import cv2

# 1. Setup paths to import from backend
# Location: backend/lab/orchestrator_tools/video_filter_tool.py
BACKEND_DIR = Path(__file__).parent.parent.parent
PROJECT_ROOT = BACKEND_DIR.parent
sys.path.append(str(BACKEND_DIR))

# Import the services from your backend
try:
    from app.services.yolov5_service import YOLOv5Service
    from app.services.video_service import VideoService
except ImportError as e:
    print(f"Error: Could not find backend services: {e}")
    sys.exit(1)

def run_intelligent_video_filter(video_path="test_video.mp4"):
    if not os.path.exists(video_path):
        print(f"Error: {video_path} not found.")
        return

    # Initialize Services
    print("⚙️ Initializing Intelligent Video Filter...")
    # Point to your local weights
    model_path = str(BACKEND_DIR / "vision_engine" / "weights" / "yolov5s.pt")
    yolo_filter = YOLOv5Service(model_path=model_path)
    # Allow more objects for the filter pass (e.g., tv, microwave, appliance)
    yolo_filter.allowed_classes = ['laptop', 'tv', 'microwave', 'refrigerator', 'oven', 'air conditioner']
    
    video_service = VideoService()

    print(f"🎬 Processing Video: {video_path}")
    print("-" * 50)
    
    # Step 1: Extract the sharpest candidate frames (Quality Control)
    print("💎 Step 1: Extracting sharpest frames...")
    candidates = video_service.extract_key_frames(video_path, max_frames=10)
    
    final_frames = []
    
    print(f"🧠 Step 2: Running Local YOLO Filter on {len(candidates)} candidates...")
    print("-" * 50)
    
    for entry in candidates:
        pil_img = entry['raw']
        frame_idx = entry['frame_idx']
        
        # Check if the frame has ANY interesting equipment
        detections = yolo_filter.detect(pil_img)
        
        if detections:
            classes = [d['class'] for d in detections]
            print(f"✅ [Frame {frame_idx:04d}] KEEP -> Found: {', '.join(classes)}")
            final_frames.append({
                "frame_idx": frame_idx,
                "image": pil_img,
                "objects": classes
            })
        else:
            print(f"❌ [Frame {frame_idx:04d}] DISCARD -> No equipment detected.")

    print("-" * 50)
    print(f"📊 SUMMARY:")
    print(f"  Total Candidates: {len(candidates)}")
    print(f"  Filtered Frames:  {len(final_frames)}")
    print(f"  Efficiency Gain:  {((len(candidates) - len(final_frames)) / len(candidates) * 100):.1f}% reduction in AI calls.")
    print("-" * 50)

    # Save the "Useful" frames to a special folder
    if final_frames:
        output_dir = Path("filtered_frames")
        output_dir.mkdir(exist_ok=True)
        for f in final_frames:
            f['image'].save(output_dir / f"useful_frame_{f['frame_idx']}.jpg")
        print(f"💾 Saved {len(final_frames)} useful frames to /filtered_frames")

if __name__ == "__main__":
    test_video = sys.argv[1] if len(sys.argv) > 1 else "test_video.mp4"
    run_intelligent_video_filter(test_video)

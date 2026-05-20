import sys
import os
import cv2
import numpy as np
from PIL import Image

# Add backend to path to import local modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.yolov5_service import YOLOv5Service

def main():
    video_path = r"c:\Users\chahd\Desktop\DetectionAppPFE\sfm_project\backend\uploads\f4603c58-571f-4082-b29a-1b4c67529cc7.mp4"
    if not os.path.exists(video_path):
        print(f"Error: Video not found at {video_path}")
        return
        
    cap = cv2.VideoCapture(video_path)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    print(f"Loaded real video: {video_path} ({total_frames} frames)")
    
    # Let's search the first window (frames 0 to 172) for the sharpest and blurriest frames
    window_size = total_frames // 5
    print(f"Window size: {window_size} frames")
    
    highest_sharpness = -1
    lowest_sharpness = 999999
    
    best_frame = None
    worst_frame = None
    
    best_idx = -1
    worst_idx = -1
    
    # We will sample every 4th frame to speed up this test script
    for idx in range(0, window_size, 4):
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if not ret:
            break
            
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        sharpness = cv2.Laplacian(gray, cv2.CV_64F).var()
        
        if sharpness > highest_sharpness:
            highest_sharpness = sharpness
            best_frame = frame.copy()
            best_idx = idx
            
        if sharpness < lowest_sharpness and sharpness > 2.0:  # Avoid solid black frames
            lowest_sharpness = sharpness
            worst_frame = frame.copy()
            worst_idx = idx
            
    print(f"Sharpest frame found at index {best_idx} with sharpness {highest_sharpness:.2f}")
    print(f"Blurriest frame found at index {worst_idx} with sharpness {lowest_sharpness:.2f}")
    
    # Let's try running the YOLOv5 detector on the sharpest frame
    try:
        yolo = YOLOv5Service()
        pil_img = Image.fromarray(cv2.cvtColor(best_frame, cv2.COLOR_BGR2RGB))
        detections = yolo.detect(pil_img)
        print(f"Detections on Hero Frame: {detections}")
    except Exception as e:
        print(f"YOLOv5 Inference Error: {e}")
        
    cap.release()

if __name__ == "__main__":
    main()

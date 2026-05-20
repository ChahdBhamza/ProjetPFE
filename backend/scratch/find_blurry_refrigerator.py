import sys
import os
import cv2
import numpy as np
from PIL import Image

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.services.yolov5_service import YOLOv5Service

def main():
    video_path = r"c:\Users\chahd\Desktop\DetectionAppPFE\sfm_project\backend\uploads\f4603c58-571f-4082-b29a-1b4c67529cc7.mp4"
    if not os.path.exists(video_path):
        print(f"Error: {video_path} not found")
        return
        
    cap = cv2.VideoCapture(video_path)
    yolo = YOLOv5Service()
    
    # We know the sharp peak is around 96. Let's scan from frame 40 to 120 to find a blurry frame with a refrigerator
    print("Scanning frames 40 to 120 for a blurry refrigerator...")
    
    results = []
    
    # We scan every 2nd frame
    for idx in range(40, 120, 2):
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if not ret:
            break
            
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        sharpness = cv2.Laplacian(gray, cv2.CV_64F).var()
        
        # Check if refrigerator is detected
        pil_img = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        detections = yolo.detect(pil_img)
        
        has_fridge = any(d['class'] == 'refrigerator' for d in detections)
        
        if has_fridge:
            fridge_det = [d for d in detections if d['class'] == 'refrigerator'][0]
            print(f"Frame {idx}: Sharpness = {sharpness:.2f}, Fridge Confidence = {fridge_det['confidence']:.2%}")
            results.append({
                'idx': idx,
                'sharpness': sharpness,
                'confidence': fridge_det['confidence']
            })
            
    cap.release()
    
    if not results:
        print("No refrigerators detected in scanned frames.")
        return
        
    # Sort by sharpness ascending to find the absolute blurriest frame containing the refrigerator
    results.sort(key=lambda x: x['sharpness'])
    
    print("\nTop 5 Blurriest Frames containing a Refrigerator:")
    for i, r in enumerate(results[:5]):
        print(f"{i+1}. Frame {r['idx']}: Sharpness = {r['sharpness']:.2f}, Confidence = {r['confidence']:.2%}")

if __name__ == "__main__":
    main()

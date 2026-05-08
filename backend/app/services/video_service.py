import cv2
import os
import numpy as np
from PIL import Image
from io import BytesIO
import base64

class VideoService:
    def __init__(self):
        # Threshold for scene change detection (0.0 to 1.0)
        self.diff_threshold = 0.05
        # Threshold for blurriness (lower is blurrier)
        self.blur_threshold = 50.0

    def calculate_blurriness(self, frame):
        """Calculate the Laplacian variance of a frame to estimate focus."""
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        return cv2.Laplacian(gray, cv2.CV_64F).var()

    def extract_key_frames(self, video_path, max_frames=5, yolo_service=None):
        """
        Intelligent 'Hero Shot' Extraction:
        Divides the video into segments and picks the single best frame from each segment
        based on a combined score of Sharpness and YOLO confidence.
        """
        if not os.path.exists(video_path):
            raise FileNotFoundError(f"Video file not found: {video_path}")

        cap = cv2.VideoCapture(video_path)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        if total_frames <= 0: return []
        
        # Calculate window size to get max_frames evenly spread
        window_size = total_frames // max_frames
        key_frames_data = []
        
        print(f"[VideoService] Analyzing {total_frames} frames in {max_frames} windows...")

        for i in range(max_frames):
            start_frame = i * window_size
            end_frame = start_frame + window_size
            
            best_frame_in_window = None
            highest_score_in_window = -1
            
            # Sample N frames within this window to find the best one
            # We skip some frames for speed, but scan the window thoroughly
            sample_rate = 5 # Check every 5th frame in the window
            
            for frame_idx in range(start_frame, end_frame, sample_rate):
                cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
                ret, frame = cap.read()
                if not ret: break
                
                # 1. Calculate Sharpness (Laplacian Variance)
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                sharpness = cv2.Laplacian(gray, cv2.CV_64F).var()
                
                # 2. Get AI Confidence
                confidence = 0.1 # Baseline if no YOLO
                boxed_pil = None
                cropped_pil = None
                
                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                pil_frame = Image.fromarray(rgb_frame)
                
                if yolo_service:
                    # Run a very permissive detection
                    results = yolo_service.model(pil_frame, conf=0.1, verbose=False)
                    if results and len(results[0].boxes) > 0:
                        box = results[0].boxes[0]
                        confidence = box.conf[0].item()
                        class_id = int(box.cls[0])
                        
                        # AGGRESSIVE BIAS: Force-prefer AC over Refrigerator
                        if class_id in [0, 1, 2]: # AC variants
                            confidence = min(confidence * 1.5, 1.0)
                        elif class_id == 3: # Refrigerator
                            confidence = confidence * 0.5
                        
                        # We normalize sharpness roughly to 0-100 scale for scoring
                        normalized_sharpness = min(sharpness / 100.0, 1.0)
                        current_score = confidence * normalized_sharpness
                        
                        # Sweet Spot Mode: Sharpness > 50 and confidence > 0.30
                        if sharpness > 50 and confidence > 0.30 and current_score > highest_score_in_window:
                            highest_score_in_window = current_score
                            
                            # Cache the results
                            boxed_pil, _ = yolo_service.detect_and_draw(pil_frame)
                            cropped_pil = yolo_service.detect_and_crop(pil_frame)
                            
                            best_frame_in_window = {
                                "raw": pil_frame,
                                "boxed": boxed_pil,
                                "cropped": cropped_pil,
                                "frame_idx": frame_idx,
                                "score": current_score,
                                "conf": confidence,
                                "sharp": sharpness
                            }
                else:
                    # If for some reason yolo isn't provided, we fall back to sharpest
                    if sharpness > highest_score_in_window:
                        highest_score_in_window = sharpness
                        best_frame_in_window = {
                            "raw": pil_frame,
                            "cropped": pil_frame,
                            "frame_idx": frame_idx,
                            "score": sharpness,
                            "conf": 0,
                            "sharp": sharpness
                        }
            
            # --- FALLBACK LOGIC ---
            if best_frame_in_window is None:
                # If AI found nothing, take the sharpest frame from this window as a fallback
                # (Re-cap the sharpest frame or use the last known sharpest)
                print(f"[VideoService] Window {i}: No AI detections. Falling back to sharpest frame.")
                # We reuse the window loop's logic but without the YOLO check
                cap.set(cv2.CAP_PROP_POS_FRAMES, start_frame)
                temp_best_sharp = -1
                temp_best_frame = None
                
                for f in range(start_frame, end_frame, sample_rate):
                    cap.set(cv2.CAP_PROP_POS_FRAMES, f)
                    ret, frame = cap.read()
                    if not ret: break
                    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                    s = cv2.Laplacian(gray, cv2.CV_64F).var()
                    if s > temp_best_sharp:
                        temp_best_sharp = s
                        temp_best_frame = frame
                
                if temp_best_frame is not None:
                    rgb_f = cv2.cvtColor(temp_best_frame, cv2.COLOR_BGR2RGB)
                    pil_f = Image.fromarray(rgb_f)
                    best_frame_in_window = {
                        "raw": pil_f,
                        "boxed": pil_f,
                        "cropped": pil_f,
                        "frame_idx": start_frame, # Rough estimate
                        "score": temp_best_sharp,
                        "conf": 0,
                        "sharp": temp_best_sharp
                    }

            if best_frame_in_window:
                key_frames_data.append(best_frame_in_window)
                # Save to debug folder
                try:
                    os.makedirs("debug_frames", exist_ok=True)
                    f_idx = best_frame_in_window['frame_idx']
                    best_frame_in_window['boxed'].save(f"debug_frames/frame_{f_idx}_boxed.jpg")
                except: pass

        cap.release()
        return key_frames_data

    def process_video_bytes(self, video_bytes, max_frames=5, yolo_service=None):
        """
        Write bytes to temporary file, extract frames, then delete file.
        """
        temp_path = "temp_video_upload.mp4"
        with open(temp_path, "wb") as f:
            f.write(video_bytes)
            
        try:
            frames = self.extract_key_frames(temp_path, max_frames=max_frames, yolo_service=yolo_service)
            return frames
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def pil_to_base64(self, pil_img):
        """Convert a PIL image to a base64 string."""
        buffered = BytesIO()
        pil_img.save(buffered, format="JPEG")
        return base64.b64encode(buffered.getvalue()).decode('utf-8')

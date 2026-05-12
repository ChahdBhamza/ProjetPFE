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

    def extract_key_frames(self, video_path, max_frames=5):
        """
        Intelligent 'Hero Shot' Extraction:
        Divides the video into segments and picks the single best frame from each segment
        based on sharpness.
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
            highest_sharpness = -1
            
            # Sample N frames within this window to find the sharpest one
            sample_rate = 2 
            
            for frame_idx in range(start_frame, end_frame, sample_rate):
                cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
                ret, frame = cap.read()
                if not ret: break
                
                # Calculate Sharpness (Laplacian Variance)
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                sharpness = cv2.Laplacian(gray, cv2.CV_64F).var()
                
                if sharpness > highest_sharpness:
                    highest_sharpness = sharpness
                    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                    pil_frame = Image.fromarray(rgb_frame)
                    best_frame_in_window = {
                        "raw": pil_frame,
                        "frame_idx": frame_idx,
                        "sharp": sharpness
                    }

            if best_frame_in_window:
                key_frames_data.append(best_frame_in_window)
                # Save to debug folder
                try:
                    os.makedirs("debug_frames", exist_ok=True)
                    f_idx = best_frame_in_window['frame_idx']
                    best_frame_in_window['raw'].save(f"debug_frames/frame_{f_idx}.jpg")
                except: pass

        cap.release()
        return key_frames_data

    def process_video_bytes(self, video_bytes, max_frames=5):
        """
        Write bytes to temporary file, extract frames, then delete file.
        """
        temp_path = "temp_video_upload.mp4"
        with open(temp_path, "wb") as f:
            f.write(video_bytes)
            
        try:
            frames = self.extract_key_frames(temp_path, max_frames=max_frames)
            return frames
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def pil_to_base64(self, pil_img):
        """Convert a PIL image to a base64 string."""
        buffered = BytesIO()
        pil_img.save(buffered, format="JPEG")
        return base64.b64encode(buffered.getvalue()).decode('utf-8')

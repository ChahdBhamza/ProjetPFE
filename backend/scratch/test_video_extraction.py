import sys
import os

# Add parent directory to path to import app
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.video_service import VideoService
import cv2

def main():
    if len(sys.argv) < 2:
        print("Usage: python test_video_extraction.py <path_to_video>")
        return

    video_path = sys.argv[1]
    if not os.path.exists(video_path):
        print(f"Error: File not found {video_path}")
        return

    service = VideoService()
    print(f"Processing video: {video_path}")
    
    try:
        frames = service.extract_key_frames(video_path, max_frames=5)
        print(f"Successfully extracted {len(frames)} key frames.")
        
        # Save frames to disk for inspection
        output_dir = "extracted_frames"
        os.makedirs(output_dir, exist_ok=True)
        
        for i, frame in enumerate(frames):
            frame_path = os.path.join(output_dir, f"key_frame_{i}.jpg")
            frame.save(frame_path)
            print(f"Saved: {frame_path}")
            
    except Exception as e:
        print(f"Failed: {e}")

if __name__ == "__main__":
    main()

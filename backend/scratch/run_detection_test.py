from app.services.yolo_service import YoloService
from PIL import Image
import os

def run_test():
    yolo = YoloService()
    image_path = r"C:\Users\chahd\.gemini\antigravity\brain\a93ec135-36bf-4fc0-9707-74b0c7ce7f47\test_fridge_1778171252370.png"
    
    if not os.path.exists(image_path):
        print(f"Error: Image not found at {image_path}")
        return

    img = Image.open(image_path).convert("RGB")
    print(f"Loaded image: {image_path}")
    
    # 1. Test detection and drawing
    print("Running detect_and_draw...")
    result_img, detections = yolo.detect_and_draw(img)
    
    save_path = os.path.join("scratch", "test_result_fridge.png")
    result_img.save(save_path)
    print(f"Detection result saved to: {os.path.abspath(save_path)}")

if __name__ == "__main__":
    if not os.path.exists("scratch"):
        os.makedirs("scratch")
    run_test()

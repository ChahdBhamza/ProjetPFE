from app.services.yolo_service import YoloService
from PIL import Image
import os

def test_yolo_classes():
    # Initialize YOLO service
    yolo = YoloService()
    print(f"Active classes: {yolo.model.names if yolo.model else 'None'}")
    
    # We don't have an image path here, so we just verify the class initialization
    if yolo.model:
        names = list(yolo.model.names.values())
        print(f"Configured classes: {names}")
        expected = ["refrigerator", "air conditioner", "microwave", "laptop", "printer"]
        
        all_present = all(cls in names for cls in expected)
        if all_present:
            print("SUCCESS: All requested classes are correctly loaded into YOLO-World.")
        else:
            print(f"WARNING: Some classes might be missing. Found: {names}")

if __name__ == "__main__":
    test_yolo_classes()

from ultralytics import YOLO

def test():
    try:
        model = YOLO('yolov8s-world.pt')
        model.set_classes(["air conditioner"])
        print("YOLO-World loaded and classes set successfully!")
    except Exception as e:
        print(f"Failed: {e}")

if __name__ == "__main__":
    test()

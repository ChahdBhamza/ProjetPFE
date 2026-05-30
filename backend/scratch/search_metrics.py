import json
import glob
import os

def search_notebooks():
    search_paths = [
        r"C:\Users\chahd\Downloads\*.ipynb",
        r"C:\Users\chahd\Desktop\ac training\*.ipynb",
        r"c:\Users\chahd\Desktop\DetectionAppPFE\backend\scratch\*.ipynb"
    ]
    
    keywords = ["accuracy", "precision", "recall", "f1", "confusion", "mAP", "epoch", "val_loss"]
    
    for path_pattern in search_paths:
        files = glob.glob(path_pattern)
        for filepath in files:
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    nb = json.load(f)
                
                # Check cells for keywords
                found_kw = []
                has_output = False
                for cell in nb.get("cells", []):
                    source = "".join(cell.get("source", [])).lower()
                    for kw in keywords:
                        if kw in source and kw not in found_kw:
                            found_kw.append(kw)
                    
                    # Check if outputs contain training logs or metrics
                    for out in cell.get("outputs", []):
                        text = "".join(out.get("text", []))
                        if "epoch" in text.lower() or "map50" in text.lower() or "val/box_loss" in text.lower():
                            has_output = True
                
                if found_kw or has_output:
                    print(f"File: {filepath}")
                    print(f"  Keywords found: {found_kw}")
                    print(f"  Has training outputs: {has_output}")
                    print("-" * 50)
            except Exception as e:
                pass

if __name__ == "__main__":
    search_notebooks()

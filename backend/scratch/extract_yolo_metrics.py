import json
import re

def safe_print(*args):
    text = " ".join(str(arg) for arg in args)
    print(text.encode('ascii', 'ignore').decode('ascii'))

def extract_metrics(filepath):
    safe_print(f"\n================ EXTRACTING METRICS FROM {filepath} ================")
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            nb = json.load(f)
        
        for i, cell in enumerate(nb.get("cells", [])):
            if cell.get("cell_type") == "code":
                source = "".join(cell.get("source", []))
                outputs = cell.get("outputs", [])
                
                # Check if it has outputs
                for out in outputs:
                    if out.get("output_type") == "stream":
                        text = "".join(out.get("text", []))
                        # Find lines with metrics
                        lines = text.split("\n")
                        for line in lines:
                            # print any line that contains "all", "mAP", or final epoch results
                            if "all" in line.lower() or "map50" in line.lower() or "epoch" in line.lower() or "instances" in line.lower():
                                if any(kw in line.lower() for kw in ["all", "map50", "150/150", "box(p"]):
                                    safe_print(f"Cell {i} line: {line.strip()}")
            elif cell.get("cell_type") == "markdown":
                pass
    except Exception as e:
        safe_print(f"Error: {e}")

if __name__ == "__main__":
    extract_metrics(r"C:\Users\chahd\Downloads\train_ac_colab (1).ipynb")
    extract_metrics(r"C:\Users\chahd\Downloads\train_ac_colab_v2 (1).ipynb")
    extract_metrics(r"C:\Users\chahd\Downloads\train_ac_colab_v2 (2).ipynb")
    extract_metrics(r"C:\Users\chahd\Desktop\ac training\train_ac_colab_v2 (1).ipynb")

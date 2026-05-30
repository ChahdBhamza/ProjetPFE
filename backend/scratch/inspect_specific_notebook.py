import json

def safe_print(*args):
    text = " ".join(str(arg) for arg in args)
    print(text.encode('ascii', 'ignore').decode('ascii'))

def inspect(filepath):
    safe_print(f"\n================ INSPECTING {filepath} ================")
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            nb = json.load(f)
        for i, cell in enumerate(nb.get("cells", [])):
            if cell.get("cell_type") == "code":
                source = "".join(cell.get("source", []))
                outputs = cell.get("outputs", [])
                
                # Check if it has any outputs or keywords
                if "val" in source or "train" in source or "metrics" in source or outputs:
                    safe_print(f"\n--- Cell {i} ---")
                    safe_print("Source:")
                    safe_print(source[:500])
                    safe_print("Outputs:")
                    for out in outputs:
                        out_type = out.get("output_type", "unknown")
                        if out_type == "stream":
                            text = "".join(out.get("text", []))
                            safe_print("  [Stream]:", text[:500])
                        elif out_type == "execute_result":
                            data = out.get("data", {})
                            if "text/plain" in data:
                                safe_print("  [Result]:", "".join(data["text/plain"])[:500])
                        elif out_type == "display_data":
                            data = out.get("data", {})
                            if "text/plain" in data:
                                safe_print("  [Display]:", "".join(data["text/plain"])[:500])
                            if "image/png" in data:
                                safe_print("  [Display Image]: PNG image data exists")
    except Exception as e:
        safe_print(f"Error reading {filepath}: {e}")

if __name__ == "__main__":
    inspect(r"C:\Users\chahd\Downloads\train_ac_colab_v2 (1).ipynb")
    inspect(r"C:\Users\chahd\Downloads\train_ac_colab (1).ipynb")

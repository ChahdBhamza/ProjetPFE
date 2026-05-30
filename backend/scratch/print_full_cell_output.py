import json

def safe_print(*args):
    text = " ".join(str(arg) for arg in args)
    print(text.encode('ascii', 'ignore').decode('ascii'))

def print_notebook_outputs(filepath):
    safe_print(f"\n================ FULL CELL OUTPUTS FOR {filepath} ================")
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            nb = json.load(f)
        for i, cell in enumerate(nb.get("cells", [])):
            if cell.get("cell_type") == "code":
                source = "".join(cell.get("source", []))
                # If cell is validation or training
                if "metrics" in source or "val" in source or "train" in source:
                    safe_print(f"\n--- Cell {i} ---")
                    safe_print(f"Source: {source.strip()}")
                    outputs = cell.get("outputs", [])
                    safe_print("Outputs:")
                    for out in outputs:
                        out_type = out.get("output_type", "unknown")
                        if out_type == "stream":
                            text = "".join(out.get("text", []))
                            safe_print(f"[Stream]:\n{text}")
                        elif out_type == "execute_result":
                            data = out.get("data", {})
                            if "text/plain" in data:
                                safe_print(f"[Result]:\n{''.join(data['text/plain'])}")
    except Exception as e:
        safe_print(f"Error reading {filepath}: {e}")

if __name__ == "__main__":
    print_notebook_outputs(r"C:\Users\chahd\Downloads\train_ac_colab (1).ipynb")
    print_notebook_outputs(r"C:\Users\chahd\Downloads\train_ac_colab_v2 (1).ipynb")
    print_notebook_outputs(r"C:\Users\chahd\Downloads\train_ac_colab_v2 (2).ipynb")
    print_notebook_outputs(r"C:\Users\chahd\Desktop\ac training\train_ac_colab_v2 (1).ipynb")

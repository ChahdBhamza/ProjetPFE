import json

def safe_print(*args):
    text = " ".join(str(arg) for arg in args)
    print(text.encode('ascii', 'ignore').decode('ascii'))

def dump_all_outputs(filepath):
    safe_print(f"\n================ DUMPING ALL OUTPUTS FROM {filepath} ================")
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            nb = json.load(f)
        
        for i, cell in enumerate(nb.get("cells", [])):
            if cell.get("cell_type") == "code":
                source = "".join(cell.get("source", []))
                outputs = cell.get("outputs", [])
                
                if outputs:
                    safe_print(f"\n--- Cell {i} ---")
                    safe_print(f"Source: {source.strip()[:100]}...")
                    for out in outputs:
                        out_type = out.get("output_type", "unknown")
                        if out_type == "stream":
                            text = "".join(out.get("text", []))
                            # Print only non-empty lines
                            lines = [l.strip() for l in text.split("\n") if l.strip()]
                            for line in lines[-10:]: # print last 10 lines
                                safe_print(f"  [Stream]: {line}")
                        elif out_type == "execute_result" or out_type == "display_data":
                            data = out.get("data", {})
                            if "text/plain" in data:
                                text = "".join(data["text/plain"])
                                safe_print(f"  [Result]: {text.strip()[:300]}")
    except Exception as e:
        safe_print(f"Error: {e}")

if __name__ == "__main__":
    dump_all_outputs(r"C:\Users\chahd\Desktop\ac training\train_ac_colab_v2 (1).ipynb")

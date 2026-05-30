import json
import sys

def inspect_notebook(path):
    print(f"\n================ INSPECTING {path} ================")
    try:
        with open(path, "r", encoding="utf-8") as f:
            nb = json.load(f)
        print(f"Number of cells: {len(nb['cells'])}")
        for i, cell in enumerate(nb['cells']):
            cell_type = cell.get("cell_type", "unknown")
            source = "".join(cell.get("source", []))
            try:
                print(f"\n--- Cell {i} ({cell_type}) ---")
                print(source)
            except UnicodeEncodeError:
                print(f"\n--- Cell {i} ({cell_type}) ---")
                print(source.encode('ascii', 'ignore').decode('ascii'))
            
            # Print output if present
            outputs = cell.get("outputs", [])
            if outputs:
                print(f"-> Has {len(outputs)} outputs:")
                for out in outputs:
                    out_type = out.get("output_type", "unknown")
                    if out_type == "stream":
                        text = "".join(out.get("text", []))
                        try:
                            print("Stream:", text)
                        except UnicodeEncodeError:
                            print("Stream:", text.encode('ascii', 'ignore').decode('ascii'))
                    elif out_type == "execute_result" or out_type == "display_data":
                        data = out.get("data", {})
                        if "text/plain" in data:
                            text = "".join(data["text/plain"])
                            try:
                                print("Result:", text)
                            except UnicodeEncodeError:
                                print("Result:", text.encode('ascii', 'ignore').decode('ascii'))
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    inspect_notebook(r"C:\Users\chahd\Downloads\train_ac_colab_v2 (1).ipynb")

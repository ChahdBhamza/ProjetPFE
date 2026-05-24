import json
import sys
sys.stdout.reconfigure(encoding='utf-8')

with open('scratch/chapter3_data_preparation.ipynb', 'r', encoding='utf-8') as f:
    nb = json.load(f)

for cell in nb['cells']:
    if cell['cell_type'] == 'markdown':
        print(''.join(cell['source']))
    elif cell['cell_type'] == 'code':
        if 'outputs' in cell:
            for out in cell['outputs']:
                if 'text' in out:
                    print(''.join(out['text']))
                elif 'data' in out and 'text/plain' in out['data']:
                    print(''.join(out['data']['text/plain']))
    print("-" * 40)

import requests, os
from dotenv import load_dotenv
load_dotenv()
r = requests.get('https://openrouter.ai/api/v1/models', headers={'Authorization': 'Bearer ' + os.getenv('OPENROUTER_API_KEY')})
for m in r.json()['data']:
    if ':free' in m['id']:
        modality = m.get('architecture', {}).get('modality', '')
        print(f"{m['id']} | modality={modality}")

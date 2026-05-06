import requests
import re

url = 'https://www.mega.tn/electromenager/froid/refrigerateur'
headers = {'User-Agent': 'Mozilla/5.0'}

r = requests.get(url, headers=headers)
html = r.text

# Find category ID (look for something like 'id=' in the form or main container)
# Often it's in a hidden field
cat_id = re.search(r'name="id"\s+value="(\d+)"', html)
if not cat_id:
    cat_id = re.search(r'id: (\d+)', html) # Check JS

# Find brand IDs (megamark)
marks = re.findall(r'megamark=(\d+)', html)

print(f"Potential Category ID: {cat_id.group(1) if cat_id else 'Not found'}")
print(f"Unique Mark IDs found: {set(marks)}")

# Check for AJAX URL
ajax_url = re.search(r'url:\s*"(index\.php\?option=com_comparateur&view=category.*?)"', html)
if ajax_url:
    print(f"Found AJAX URL: {ajax_url.group(1)}")

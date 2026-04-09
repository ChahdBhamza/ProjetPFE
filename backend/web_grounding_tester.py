import json
from pathlib import Path
from duckduckgo_search import DDGS
import re
import time

def web_search_verify(product_name, db_btu):
    """Searches the web and tries to find a BTU match without AI"""
    print(f"\n🔍 Searching web for: {product_name}...")
    
    with DDGS() as ddgs:
        # Extract Brand and Model ID
        brand_match = re.search(r"Gree|LG|Samsung|TCL|Midea", product_name, re.IGNORECASE)
        brand = brand_match.group(0) if brand_match else "AC"
        
        model_match = re.search(r"([A-Z0-9-]{5,})", product_name)
        model_id = model_match.group(1) if model_match else ""
        
        query = f"{brand} {db_btu} BTU"
        print(f"📡 Using super-broad query: {query}")
        
        results = list(ddgs.text(query, max_results=5))
        
        if not results:
            print("⚠️ WEB SEARCH RETURNED ZERO RESULTS. The internet might be blocking this specific query.")
            return False, []
        
        found_match = False
        web_evidences = []

        for r in results:
            snippet = r['body']
            title = r['title']
            url = r['href']
            print(f"\n[Raw Snippet from {title}]:")
            print(f"--- {snippet[:200]}...")
            
            # Simple Regex to find BTU in the web snippet
            btu_match = re.search(r"(\d{4,5})\s*BTU", snippet, re.IGNORECASE)
            
            if btu_match:
                web_btu = btu_match.group(1)
                match_status = "✅ MATCH" if web_btu == db_btu else "❌ DISCREPANCY"
                
                evidence = {
                    "source": title,
                    "url": url,
                    "web_btu": web_btu,
                    "status": match_status
                }
                web_evidences.append(evidence)
                if match_status == "✅ MATCH":
                    found_match = True

        return found_match, web_evidences

def main():
    # Let's test it with one specific product from your DB
    # Switching to a Gree unit for broader search coverage
    example_json = Path("../dataequipment/climatiseurs/Gree/text/Climatiseur Gree CL12AQCXB-CF Tropicalisé 12000 BTU Chaud Froid - Blanc.json")
    
    if not example_json.exists():
        print(f"Test file not found at {example_json}")
        return

    with open(example_json, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Get the product name from the filename itself
    product_name = example_json.stem
    db_btu = data.get("btu", "Unknown")

    print(f"--- 🌐 WEB GROUNDING TEST ---")
    print(f"Target: {product_name}")
    print(f"DB says BTU is: {db_btu}")

    is_verified, evidence = web_search_verify(product_name, db_btu)

    print("\n--- 📊 RESULTS ---")
    if is_verified:
        print("🏆 GROUNDING SUCCESS: The internet confirms the database specs!")
    else:
        print("⚠️ GROUNDING UNCERTAIN: No exact match found in top snippets.")

    print("\nEvidence found:")
    for e in evidence:
        print(f"- [{e['status']}] Source: {e['source']}")
        print(f"  Web value: {e['web_btu']} BTU | URL: {e['url']}")

if __name__ == "__main__":
    main()

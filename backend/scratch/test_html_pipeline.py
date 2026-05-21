# -*- coding: utf-8 -*-
"""Test the spec extraction pipeline with a local HTML file"""
import sys
import os
import json
from pathlib import Path
from bs4 import BeautifulSoup

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.services.spec_service import SpecService

def test_local_html():
    """Test spec extraction using a local HTML file instead of web scraping"""
    
    # Initialize the service
    svc = SpecService()
    
    # Load the local HTML file
    html_path = Path(__file__).parent / "test_appliance_spec.html"
    
    print("=" * 60)
    print(f"Loading HTML from: {html_path}")
    print("=" * 60)
    
    with open(html_path, 'r', encoding='utf-8') as f:
        html_content = f.read()
    
    print(f"✅ HTML loaded successfully ({len(html_content)} chars)")
    
    # Parse with BeautifulSoup (simulating the scrape_page_content method)
    soup = BeautifulSoup(html_content, "html.parser")
    
    # Remove noise: scripts, styles, nav, footer
    for tag in soup(["script", "style", "nav", "footer", "header", "aside", "form"]):
        tag.decompose()
    
    # Extract spec tables specifically (high-value data)
    spec_tables = []
    for table in soup.find_all(["table", "dl"]):
        spec_tables.append(table.get_text(separator=" | ", strip=True))
    
    # Extract main body text
    body_text = soup.get_text(separator="\n", strip=True)
    
    # Prioritize spec tables at the top, then body text
    combined = ""
    if spec_tables:
        combined += "=== SPECIFICATION TABLES ===\n"
        combined += "\n---\n".join(spec_tables)
        combined += "\n\n"
    
    combined += "=== PAGE CONTENT ===\n"
    combined += body_text
    
    # Limit to 6000 chars to stay within LLM context
    scraped_data = combined[:6000]
    
    print(f"\n📄 Scraped data length: {len(scraped_data)} chars")
    print(f"\n--- FIRST 1000 CHARS OF SCRAPED DATA ---")
    print(scraped_data[:1000])
    print("--- END ---\n")
    
    # Test Gemini extraction with the scraped data
    print("=" * 60)
    print("Testing Gemini Spec Extraction")
    print("=" * 60)
    
    brand = "Samsung"
    model = "RT38K5532S8"
    equipment_type = "refrigerator"
    
    result = svc.extract_and_verify_specs(scraped_data, brand, model, equipment_type)
    
    print("\n" + "=" * 60)
    print("EXTRACTION RESULT")
    print("=" * 60)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    
    # Save result to JSON file
    output_path = Path(__file__).parent / "test_extraction_result.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Result saved to: {output_path}")
    
    return result

if __name__ == "__main__":
    try:
        result = test_local_html()
        print("\n✅ Test completed successfully!")
        
        # Print summary
        if "specs" in result:
            print(f"\n📊 Extracted {result.get('fields_found', 0)} specification fields")
            print(f"🎯 Source quality: {result.get('source_quality', 'unknown')}")
            print(f"📝 Summary: {result.get('summary', 'N/A')}")
            
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
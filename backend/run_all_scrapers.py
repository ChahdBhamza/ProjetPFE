import subprocess
import os
import sys
from pathlib import Path

def run_scraper(script_name):
    print(f"\n--- 🛰️ RUNNING {script_name.upper()} ---")
    script_path = Path("scrapers") / f"{script_name}.py"
    
    # Use the current python executable to run the scripts
    result = subprocess.run([sys.executable, str(script_path)], capture_output=False)
    if result.returncode == 0:
        print(f"✅ {script_name} finished successfully.")
    else:
        print(f"❌ {script_name} failed with return code {result.returncode}")

def main():
    # Ensure we are in the backend directory
    if not Path("scrapers").exists():
        print("Error: scrapers directory not found. Please run from the backend folder.")
        return

    scrapers = ["tunisianet", "mega", "zoom", "primini"]
    
    print("🚀 TARGETING 4 TUNISIAN SOURCES FOR RAG ENRICHMENT")
    print("================================================")
    
    for scraper in scrapers:
        run_scraper(scraper)
        
    print("\n================================================")
    print("🎉 ALL SCRAPERS COMPLETED.")
    print("Files created: scraper_[name]_results.json")
    print("Next step: Run 'data_exporter.py' to organize these images and specs into dataequipment/.")

if __name__ == "__main__":
    main()

import os
import json
import requests
from bs4 import BeautifulSoup
from ddgs import DDGS
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

class SpecService:
    def __init__(self):
        self.api_key = os.getenv("OPENROUTER_API_KEY")
        self.client = OpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=self.api_key,
            default_headers={
                "HTTP-Referer": "http://localhost:8000",
                "X-Title": "Cybersight AI App",
            }
        )
        self.model = "google/gemini-2.5-flash"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }


    # =============================================
    # STEP 1: DuckDuckGo Search (Find URLs)
    # =============================================
    def search_product_urls(self, brand: str, model: str, equipment_type: str) -> list:
        """Use DuckDuckGo to find the best product page URLs."""
        query = f"{brand} {model} {equipment_type} fiche technique specifications"
        urls = []
        try:
            with DDGS() as ddgs:
                for r in ddgs.text(query, max_results=5):
                    urls.append({
                        "title": r.get("title", ""),
                        "url": r.get("href", ""),
                        "snippet": r.get("body", "")
                    })
            print(f"🔎 [DuckDuckGo] Found {len(urls)} results for '{query}'")
        except Exception as e:
            print(f"📡 [DuckDuckGo] Search error: {e}")
        return urls

    # =============================================
    # STEP 2: BeautifulSoup Scraping (Get Raw Data)
    # =============================================
    def scrape_page_content(self, url: str) -> str:
        """Scrape the full text content of a product page using BeautifulSoup."""
        try:
            response = requests.get(url, headers=self.headers, timeout=10)
            response.raise_for_status()
            soup = BeautifulSoup(response.text, "html.parser")

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
            return combined[:6000]

        except Exception as e:
            print(f"⚠️ [Scraper] Failed to scrape {url}: {e}")
            return ""

    # =============================================
    # STEP 3: Gemini Verification & Extraction
    # =============================================
    def extract_and_verify_specs(self, scraped_data: str, brand: str, model: str, equipment_type: str) -> dict:
        """
        Use Gemini to extract structured specs from scraped page data.
        Gemini acts as a VERIFICATION layer: it only returns fields it can confirm
        from the scraped content. No hallucination allowed.
        """

        prompt = f"""You are a strict Technical Data Extraction Agent.
Your job is to extract ONLY verified technical specifications from the raw scraped web page content below.

RULES:
1. ONLY extract data that is EXPLICITLY stated in the scraped content.
2. If a field is NOT found in the content, set its value to null. Do NOT guess or hallucinate.
3. Return ONLY valid JSON, no markdown, no explanation.

Equipment to identify:
- Brand: {brand}
- Model: {model}
- Type: {equipment_type}

Scraped Web Page Content:
---
{scraped_data}
---

Return this exact JSON structure:
{{
    "brand": "{brand}",
    "model": "{model}",
    "type": "{equipment_type}",
    "verified": true,
    "source_quality": "high | medium | low",
    "specs": {{
        "energy_class": "e.g. A+++ or null",
        "capacity": "e.g. 380L or 12000 BTU or null",
        "refrigerant": "e.g. R32 or null",
        "inverter": "Yes/No or null",
        "dimensions": "HxWxD in cm or null",
        "weight": "in kg or null",
        "color": "e.g. Silver or null",
        "noise_level": "in dB or null",
        "warranty": "e.g. 2 years or null",
        "price": "e.g. 1299 TND or null"
    }},
    "fields_found": 0,
    "summary": "One sentence describing the product based on verified data only."
}}

IMPORTANT: Set "fields_found" to the count of non-null fields inside "specs".
Set "source_quality" based on how many fields you found: high (7+), medium (4-6), low (1-3).
"""

        try:
            print(f"🧠 [Gemini] Verifying & extracting specs for {brand} {model}...")
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1,
                max_tokens=1000  # Added to prevent OpenRouter 402 error
            )

            raw_text = response.choices[0].message.content.strip()
            if "```json" in raw_text:
                raw_text = raw_text.split("```json")[1].split("```")[0]
            elif "```" in raw_text:
                raw_text = raw_text.split("```")[1].split("```")[0]

            result = json.loads(raw_text.strip())
            print(f"✅ [Gemini] Extracted {result.get('fields_found', 0)} verified fields (Quality: {result.get('source_quality', 'unknown')})")
            return result

        except Exception as e:
            print(f"❌ [Gemini] Spec Extraction Error: {e}")
            return {"error": str(e), "brand": brand, "model": model, "verified": False}

    # =============================================
    # FULL PIPELINE: Search -> Scrape -> Verify
    # =============================================
    def get_full_identity(self, brand: str, model: str, equipment_type: str) -> dict:
        """
        Complete Agentic Pipeline:
        1. DuckDuckGo finds the best product pages
        2. BeautifulSoup scrapes the raw content (combining top 3 pages)
        3. Gemini extracts and verifies structured specs
        """
        print(f"\n{'='*50}")
        print(f"🔎 [Pipeline] Hunting specs for: {brand} {model} ({equipment_type})")
        print(f"{'='*50}")

        # Step 1: Search
        search_results = self.search_product_urls(brand, model, equipment_type)
        if not search_results:
            return {"status": "no_search_results", "brand": brand, "model": model}

        # Step 2: Scrape the top 3 results and combine them
        best_scraped = ""
        scraped_urls = []
        valid_pages_scraped = 0

        for result in search_results:
            url = result.get("url", "")
            if not url:
                continue

            print(f"🕷️ [Scraper] Trying: {url[:80]}...")
            content = self.scrape_page_content(url)

            if len(content) > 500:
                print(f"✅ [Scraper] Got rich content ({len(content)} chars) from: {url[:60]}")
                best_scraped += f"\n\n--- CONTENT FROM: {url} ---\n{content}"
                scraped_urls.append(url)
                valid_pages_scraped += 1

            # Stop after we have 3 good pages to avoid context limit overflow
            if valid_pages_scraped >= 3:
                break

        if not best_scraped:
            # Fallback: use DuckDuckGo snippets directly
            print("⚠️ [Scraper] All pages failed. Falling back to search snippets...")
            best_scraped = "\n\n".join([
                f"Title: {r['title']}\nSnippet: {r['snippet']}"
                for r in search_results
            ])

        # Step 3: Gemini Verification
        # Trim combined content to max 12000 chars to save tokens
        result = self.extract_and_verify_specs(best_scraped[:12000], brand, model, equipment_type)
        result["source_url"] = ", ".join(scraped_urls) if scraped_urls else "DuckDuckGo Snippets"
        result["pipeline"] = f"duckduckgo -> beautifulsoup ({valid_pages_scraped} pages) -> gemini"

        return result


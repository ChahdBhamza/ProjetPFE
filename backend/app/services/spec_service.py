"""
spec_service.py — Dynamic schema-aware spec extraction pipeline.

Pipeline:
  1. DuckDuckGo multi-query search  (specs + price + official page)
  2. BeautifulSoup scraping of top 3 results
  3. Gemini extraction using the EXACT canonical schema for this equipment type
  4. Normalization pass — coerce strings to typed values, fill nulls, score quality
"""

import os
import json
import copy
import re
import requests
from bs4 import BeautifulSoup
from ddgs import DDGS
from dotenv import load_dotenv
from groq import Groq

from app.services.equipment_schemas import (
    get_schema,
    normalize_category,
    schema_as_prompt_fields,
    CATEGORY_LABELS,
    SPECS_EXTRACTIONS,
)

load_dotenv()


class SpecService:
    def __init__(self):
        self.api_key = os.getenv("GROQ_API_KEY")
        if not self.api_key:
            raise RuntimeError("GROQ_API_KEY not set in .env")
        self.client = Groq(api_key=self.api_key)
        self.model = "llama-3.3-70b-versatile"
        self.headers = {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            )
        }

    # =========================================================================
    # STEP 1: Multi-query DuckDuckGo search
    # =========================================================================

    def search_product_urls(self, brand: str, model: str, equipment_type: str) -> list[dict]:
        """
        Run THREE targeted queries to maximise coverage:
          A) Technical specifications query
          B) Official / manufacturer page query
          C) Tunisian price query
        Deduplicate by URL and return up to 9 unique results.
        """
        category_label = CATEGORY_LABELS.get(normalize_category(equipment_type), equipment_type)

        queries = [
            f"{brand} {model} {category_label} specifications fiche technique",
            f"{brand} {model} site:{brand.lower()}.com OR site:manufacturer specifications",
            f"{brand} {model} prix tunisie mega.tn OR mytek.tn OR tunisianet.com",
        ]

        seen_urls: set[str] = set()
        results: list[dict] = []

        for q in queries:
            try:
                with DDGS() as ddgs:
                    for r in ddgs.text(q, max_results=4):
                        url = r.get("href", "")
                        if url and url not in seen_urls:
                            seen_urls.add(url)
                            results.append({
                                "title":   r.get("title", ""),
                                "url":     url,
                                "snippet": r.get("body", ""),
                                "query":   q,
                            })
            except Exception as e:
                print(f"[DDG] Search error for query '{q[:60]}': {e}")

        print(f"[DDG] Total unique URLs found: {len(results)} across 3 queries")
        return results

    # =========================================================================
    # STEP 2: BeautifulSoup scraping
    # =========================================================================

    def scrape_page_content(self, url: str) -> str:
        """
        Scrape a product page and return cleaned text prioritising spec tables.
        Returns empty string on failure.
        """
        try:
            response = requests.get(url, headers=self.headers, timeout=10)
            response.raise_for_status()
            soup = BeautifulSoup(response.text, "html.parser")

            # Remove DOM noise
            for tag in soup(["script", "style", "nav", "footer", "header",
                              "aside", "form", "button", "iframe", "noscript",
                              "svg", "img", "picture"]):
                tag.decompose()

            # Extract spec tables and definition lists first (highest value)
            spec_sections: list[str] = []
            for table in soup.find_all(["table", "dl"]):
                text = table.get_text(separator=" | ", strip=True)
                if len(text) > 30:
                    spec_sections.append(text)

            # Also grab any div/section with "spec" in class/id
            for div in soup.find_all(["div", "section"], attrs={"class": re.compile(r"spec|caract|detail|fiche", re.I)}):
                text = div.get_text(separator="\n", strip=True)
                if len(text) > 50:
                    spec_sections.append(text)

            body_text = soup.get_text(separator="\n", strip=True)

            combined = ""
            if spec_sections:
                combined += "=== SPECIFICATION TABLES ===\n"
                combined += "\n---\n".join(spec_sections[:5])   # top 5 spec blocks
                combined += "\n\n"
            combined += "=== PAGE CONTENT ===\n"
            combined += body_text

            # Per-page cap: 6000 chars
            return combined[:6000]

        except Exception as e:
            print(f"[Scraper] Failed to scrape {url[:60]}: {e}")
            return ""

    # =========================================================================
    # STEP 3: Gemini schema-aware extraction
    # =========================================================================

    def extract_and_verify_specs(
        self,
        scraped_data: str,
        brand: str,
        model: str,
        equipment_type: str,
    ) -> dict:
        """
        Use Gemini to extract ONLY the fields defined in the canonical schema
        for this equipment type.  No hallucination allowed.
        """
        category = normalize_category(equipment_type)
        category_label = CATEGORY_LABELS.get(category, equipment_type)

        prompt = f"""You are a strict Technical Data Extraction Agent for {category_label} equipment.

Your ONLY job: extract verified technical specifications from the scraped web content below.

STRICT RULES:
1. You MUST NOT leave any fields empty or null. EVERY FIELD MUST BE POPULATED.
2. First, extract data that is EXPLICITLY stated in the scraped content.
3. If a field is missing from the scraped content, you MUST use your expert pre-trained knowledge about the specific model '{brand} {model}' to deduce and fill it in accurately. NO NULL VALUES ALLOWED.
4. For boolean fields: use true or false (JSON booleans, not strings).
5. For numeric fields: use numbers (not strings). e.g. 12000 not "12000 BTU".
6. For "price_tnd": extract the numeric price in TND only (e.g. 1299.0). If unknown, estimate a typical Tunisian Dinars price.

Equipment to identify:
- Brand: {brand}
- Model: {model}
- Category: {category_label}

Scraped Web Content:
---
{scraped_data}
---
"""

        extraction_schema = SPECS_EXTRACTIONS.get(category)
        if not extraction_schema:
            raise ValueError(f"No Pydantic extraction schema found for category '{category}'")

        try:
            print(f"[Groq] Extracting {category_label} specs for {brand} {model} using structured output...")
            
            # Since Groq strict JSON mode requires the schema in the prompt, let's append it
            schema_dict = extraction_schema.model_json_schema() if hasattr(extraction_schema, "model_json_schema") else extraction_schema.schema()
            schema_json = json.dumps(schema_dict, indent=2)
            full_prompt = prompt + f"\n\nYou MUST return a JSON object matching exactly this schema:\n{schema_json}"
            
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": full_prompt}],
                temperature=0.05,
                max_tokens=3000,
                response_format={"type": "json_object"},
            )
            raw = response.choices[0].message.content.strip()
            try:
                raw_json = json.loads(raw)
            except json.JSONDecodeError as je:
                print(f"[Groq] JSON parsing failed: {je}")
                print(f"[Groq] Raw output was:\n{raw}")
                raise je

            # Build outer envelope programmatically
            result = {
                "brand": brand,
                "model": model,
                "equipment_category": category,
                "verified": True,
                "source_quality": "low",  # Calculated in normalization
                "specs": raw_json.get("specs", {}),
                "fields_found": 0,       # Calculated in normalization
                "summary": raw_json.get("summary", ""),
            }

            # Normalize and validate the specs block
            result = self._normalize_specs(result, category)

            print(
                f"[Groq] Extracted {result.get('fields_found', 0)} fields "
                f"(Quality: {result.get('source_quality', 'unknown')})"
            )
            return result

        except Exception as e:
            print(f"[Groq] Extraction error: {e}")
            return {
                "error": str(e),
                "brand": brand,
                "model": model,
                "equipment_category": category,
                "verified": False,
            }

    # =========================================================================
    # STEP 4: Normalization post-processing
    # =========================================================================

    def _normalize_specs(self, result: dict, category: str) -> dict:
        """
        Coerce spec values to their intended types, guarantee all schema keys
        are present, and recompute fields_found + source_quality.
        """
        from app.services.equipment_schemas import EQUIPMENT_SCHEMAS

        canonical = EQUIPMENT_SCHEMAS.get(category, {})
        specs = result.get("specs", {})

        # Ensure every schema key exists (fill missing with None)
        for key in canonical:
            if key not in specs:
                specs[key] = None

        # Type coercions
        int_fields   = {"capacity_btu", "capacity_liters", "power_watts",
                        "noise_level_db", "ram_gb", "warranty_years",
                        "turntable_diameter_cm", "power_consumption_w", "power_supply_w"}
        float_fields = {"weight_kg", "display_inches", "battery_wh", "price_tnd", "annual_energy_consumption_kwh"}
        bool_fields  = {"smart_wifi", "no_frost", "inverter"}

        for key, val in specs.items():
            if val is None:
                continue
            try:
                if key in int_fields:
                    # Strip non-numeric chars and convert
                    numeric = re.sub(r"[^\d]", "", str(val))
                    specs[key] = int(numeric) if numeric else None
                elif key in float_fields:
                    numeric = re.sub(r"[^\d.]", "", str(val).replace(",", "."))
                    specs[key] = float(numeric) if numeric else None
                elif key in bool_fields:
                    if isinstance(val, bool):
                        pass
                    elif isinstance(val, str):
                        specs[key] = val.lower() in ("true", "yes", "oui", "1")
                    else:
                        specs[key] = bool(val)
                elif key == "functions" and isinstance(val, str):
                    # Convert "Grill, Convection" string to list
                    specs[key] = [f.strip() for f in re.split(r"[,;/]", val) if f.strip()]
            except Exception:
                pass  # leave as-is on parse failure

        # Recount non-null fields
        fields_found = sum(1 for v in specs.values() if v is not None)
        result["specs"] = specs
        result["fields_found"] = fields_found
        result["source_quality"] = (
            "high"   if fields_found >= 7 else
            "medium" if fields_found >= 4 else
            "low"
        )
        return result

    # =========================================================================
    # FULL PIPELINE: Search → Scrape → Extract → Normalize
    # =========================================================================

    def get_full_identity(self, brand: str, model: str, equipment_type: str) -> dict:
        """
        Complete agentic pipeline:
          1. Multi-query DuckDuckGo search
          2. BeautifulSoup scraping of top 3 rich pages
          3. Gemini schema-aware extraction for the detected equipment type
          4. Normalization and quality grading
        Returns a standardised equipment spec dict.
        """
        category = normalize_category(equipment_type)

        print(f"\n{'='*56}")
        print(f"[Pipeline] Hunting specs: {brand} {model} ({category})")
        print(f"{'='*56}")

        # Step 1: Search
        search_results = self.search_product_urls(brand, model, equipment_type)
        if not search_results:
            return {
                "status": "no_search_results",
                "brand": brand,
                "model": model,
                "equipment_category": category,
                "specs": get_schema(category),
                "fields_found": 0,
                "source_quality": "low",
            }

        # Step 2: Scrape top pages
        combined_text = ""
        scraped_urls: list[str] = []
        valid_pages = 0

        for result in search_results:
            url = result.get("url", "")
            if not url:
                continue
            print(f"[Scraper] Trying: {url[:80]}...")
            content = self.scrape_page_content(url)
            if len(content) > 500:
                print(f"[Scraper] Got {len(content)} chars from {url[:60]}")
                combined_text += f"\n\n--- SOURCE: {url} ---\n{content}"
                scraped_urls.append(url)
                valid_pages += 1
            if valid_pages >= 3:
                break

        if not combined_text:
            print("[Scraper] All pages failed — using DDG snippets as fallback")
            combined_text = "\n\n".join([
                f"Title: {r['title']}\nSnippet: {r['snippet']}"
                for r in search_results[:5]
            ])

        # Step 3: Gemini extraction (12 000 char context cap)
        extraction = self.extract_and_verify_specs(
            combined_text[:12_000], brand, model, equipment_type
        )
        extraction["source_urls"] = scraped_urls if scraped_urls else ["DDG snippets"]
        extraction["pipeline"] = (
            f"ddg-3queries -> beautifulsoup({valid_pages} pages) -> groq-{self.model}"
        )

        return extraction

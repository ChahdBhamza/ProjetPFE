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

        # Treat junk model values as "model unknown" so searches don't include them
        _junk = {"not identifiable", "unknown model", "unknown", "n/a", "na", "none", "", "unreadable", "unknown model reference"}
        model_lower = model.lower().strip()
        model_is_junk = model_lower in _junk or model_lower.startswith("unreadable") or model_lower.startswith("no visible")

        # If model looks like a capacity hint (e.g. "12000 BTU", "18K"), use it as a search hint only
        import re as _re
        capacity_match = _re.search(r'(\d{4,5})\s*(?:btu)?|(\d{1,2})\s*k\b', model_lower)
        capacity_hint = capacity_match.group(0).strip() if capacity_match else ""

        if not model_is_junk and not capacity_hint:
            # Clean model code — search with it directly
            queries = [
                f"{brand} {model} {category_label} specifications fiche technique",
                f"{brand} {model} {category_label} datasheet manuel",
                f"{brand} {model} {category_label} tunisianet.com OR mega.tn OR mytek.tn OR wiki.tn",
            ]
        elif capacity_hint:
            # Capacity visible but no model code — use it to narrow search
            queries = [
                f"{brand} {capacity_hint} BTU {category_label} fiche technique specifications",
                f"{brand} {capacity_hint} {category_label} datasheet manuel",
                f"{brand} {capacity_hint} {category_label} tunisianet.com OR mega.tn OR mytek.tn",
            ]
        else:
            # No model info at all — search by brand + category
            queries = [
                f"{brand} {category_label} fiche technique specifications",
                f"{brand} {category_label} datasheet manuel",
                f"{brand} {category_label} tunisianet.com OR mega.tn OR mytek.tn",
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
        _headers_list = [
            {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "fr-FR,fr;q=0.9,en;q=0.8",
                "Accept-Encoding": "gzip, deflate, br",
                "Connection": "keep-alive",
            },
            {
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "fr,en;q=0.5",
            },
        ]
        try:
            last_err = None
            for hdrs in _headers_list:
                try:
                    response = requests.get(url, headers=hdrs, timeout=12)
                    if response.status_code == 200:
                        break
                    last_err = f"HTTP {response.status_code}"
                except Exception as e:
                    last_err = str(e)
            else:
                print(f"[Scraper] All attempts failed for {url[:60]}: {last_err}")
                return ""
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

        field_hints = schema_as_prompt_fields(equipment_type)

        prompt = f"""You are a technical specifications expert for {category_label} equipment.

Equipment:
- Brand: {brand}
- Model: {model}
- Category: {category_label}

Your job: fill every schema field from the scraped web content below.
For specs fields: you MAY use your training knowledge to fill gaps.
For "exact_model_reference": ONLY use what is explicitly written in the scraped text. If no model code appears in the text, return "" (empty string). NEVER invent or guess a model reference.

RULES:
- For boolean fields: true or false only (no strings).
- For numeric fields: numbers only, no units in the value (e.g. 12000 not "12000 BTU").
- For "exact_model_reference": copy it verbatim from the scraped text, or "" if not found.
- Output ONLY raw valid JSON. No markdown, no code blocks.

Scraped Web Content:
---
{scraped_data}
---
"""

        extraction_schema = SPECS_EXTRACTIONS.get(category)
        if not extraction_schema:
            print(f"[Groq] No schema for category '{category}' — running generic extraction")
            generic_prompt = f"""You are a technical specifications expert.

Equipment:
- Brand: {brand}
- Model: {model}

Extract every technical specification you can find from the scraped content below.
Return ONLY a raw JSON object with these keys:
{{
  "exact_model_reference": "copy verbatim from the text if present, otherwise empty string",
  "specs": {{ "key": "value", ... }},
  "summary": "one factual sentence about this equipment"
}}

IMPORTANT: "exact_model_reference" must come ONLY from the scraped text. If no model code is in the text, return "".
No markdown, no code blocks. All values must be strings or numbers.

Scraped Web Content:
---
{scraped_data}
---
"""
            try:
                from app.services.rate_limiter import groq_throttle
                groq_throttle()
                response = self.client.chat.completions.create(
                    model=self.model,
                    messages=[{"role": "user", "content": generic_prompt}],
                    temperature=0.05,
                    max_tokens=2048,
                    response_format={"type": "json_object"},
                )
                raw = response.choices[0].message.content.strip()
                raw_json = json.loads(raw)
                extracted_ref = raw_json.get("exact_model_reference", "")
                final_model = extracted_ref if extracted_ref and len(extracted_ref) > 3 else model
                specs = raw_json.get("specs", {})
                return {
                    "brand": brand,
                    "model": final_model,
                    "equipment_category": category,
                    "verified": True,
                    "source_quality": "medium" if specs else "low",
                    "specs": specs,
                    "fields_found": len(specs),
                    "summary": raw_json.get("summary", ""),
                }
            except Exception as e:
                print(f"[Groq] Generic extraction failed: {e}")
                return {
                    "brand": brand,
                    "model": model,
                    "equipment_category": category,
                    "verified": False,
                    "source_quality": "low",
                    "specs": {},
                    "fields_found": 0,
                    "summary": "",
                }

        try:
            print(f"[Groq] Extracting {category_label} specs for {brand} {model} using structured output...")

            full_prompt = prompt + (
                f"\n\nReturn ONLY a raw JSON object with exactly these keys — no markdown, no code blocks:\n"
                f'{{"exact_model_reference": "base model or SKU", "specs": {field_hints}, '
                f'"summary": "one factual sentence"}}'
            )

            from app.services.rate_limiter import groq_throttle
            groq_throttle()
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": full_prompt}],
                temperature=0.05,
                max_tokens=2048,
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
            _junk_refs = {"not identifiable", "unknown model", "unknown", "n/a", "na", "none", "not available", "not found", "unidentified"}
            extracted_ref = raw_json.get("exact_model_reference", "").strip()
            if extracted_ref.lower() in _junk_refs or len(extracted_ref) <= 2:
                extracted_ref = ""
            if extracted_ref:
                print(f"[Groq] ✅ Real model found from web scraping: {extracted_ref}")
            # Web-scraped model takes priority over AI-guessed model from image
            final_model = extracted_ref if extracted_ref else model
            
            result = {
                "brand": brand,
                "model": final_model,
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
            err_str = str(e)
            print(f"[Groq] Extraction error: {e}")
            # On json_validate_failed, retry once with even shorter context (Groq token budget issue)
            if "json_validate_failed" in err_str and scraped_data and len(scraped_data) > 500:
                print("[Groq] Retrying with shortened context (500 chars)...")
                return self.extract_and_verify_specs(scraped_data[:500], brand, model, equipment_type)
            # Even on failure, return the FULL schema (all keys → None) so the
            # frontend always renders every field for this equipment type.
            return {
                "error": err_str,
                "brand": brand,
                "model": model,
                "equipment_category": category,
                "verified": False,
                "specs": get_schema(category),
                "fields_found": 0,
                "source_quality": "low",
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

        # Strip stray keys the model may hallucinate (category, price, color, etc.)
        _STRIPPED_KEYS = {"category", "equipment_category", "price_tnd", "color",
                          "price", "prix", "couleur", "type", "brand", "model"}
        for k in _STRIPPED_KEYS:
            specs.pop(k, None)

        # Keep only keys that exist in the canonical schema
        specs = {k: v for k, v in specs.items() if k in canonical}

        # Ensure every schema key exists (fill missing with None)
        for key in canonical:
            if key not in specs:
                specs[key] = None

        # Convert dimensions dict → "HxWxD cm" string if Groq returned an object
        if "dimensions" in specs and isinstance(specs["dimensions"], dict):
            d = specs["dimensions"]
            h = d.get("height") or d.get("h") or ""
            w = d.get("width")  or d.get("w") or ""
            depth = d.get("depth") or d.get("d") or ""
            parts = [str(x) for x in [h, w, depth] if x]
            specs["dimensions"] = "×".join(parts) + " cm" if parts else None


        # Type coercions
        int_fields   = {"capacity_btu", "capacity_liters", "power_watts",
                        "noise_level_db", "ram_gb", "warranty_years",
                        "turntable_diameter_cm", "power_consumption_w", "power_supply_w",
                        "refresh_rate_hz", "brightness_cdm2"}
        float_fields = {"weight_kg", "display_inches", "battery_wh", "annual_energy_consumption_kwh",
                        "screen_size_inches", "response_time_ms"}
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
                elif key in ("functions", "ports") and isinstance(val, str):
                    # Convert comma-separated string to list
                    specs[key] = [f.strip() for f in re.split(r"[,;/]", val) if f.strip()]
            except Exception:
                pass  # leave as-is on parse failure

        # Normalize annual_energy_consumption_kwh — scale up if value looks like
        # monthly (< 50) or daily (< 5) instead of yearly
        if "annual_energy_consumption_kwh" in specs and specs["annual_energy_consumption_kwh"] is not None:
            kwh = float(specs["annual_energy_consumption_kwh"])
            if kwh < 5:       # looks like daily → multiply by 365
                specs["annual_energy_consumption_kwh"] = round(kwh * 365, 1)
                print(f"[Normalize] annual kWh {kwh} looked daily → scaled to {specs['annual_energy_consumption_kwh']}")
            elif kwh < 50:    # looks like monthly → multiply by 12
                specs["annual_energy_consumption_kwh"] = round(kwh * 12, 1)
                print(f"[Normalize] annual kWh {kwh} looked monthly → scaled to {specs['annual_energy_consumption_kwh']}")

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

        # Sanitize junk model values before anything else
        _junk = {"not identifiable", "unknown model", "unknown", "n/a", "na", "none", "", "unreadable", "unknown model reference"}
        _m = model.lower().strip()
        # Also treat generic fallbacks like "Maxwell Air Conditioner" as no-model
        _is_generic = any(_m.endswith(x) for x in ("air conditioner", "refrigerator", "microwave", "laptop", "monitor"))
        if _m in _junk or _m.startswith("unreadable") or _m.startswith("no visible") or _is_generic:
            model = ""

        print(f"\n{'='*56}")
        print(f"[Pipeline] Hunting specs: {brand} {model or '(model unknown)'} ({category})")
        print(f"{'='*56}")

        # Step 0: Cache lookup — skip the whole search/scrape/extract pipeline on a hit
        if brand and model:
            try:
                from app.database import mongo_db
                cached = mongo_db.get_cached_specs(brand, model, category)
                if cached:
                    print(f"[Pipeline] CACHE HIT for {brand} {model} — returning instantly")
                    cached["pipeline"] = (cached.get("pipeline") or "") + " (cached)"
                    return cached
            except Exception as e:
                print(f"[Pipeline] Cache lookup failed (continuing live): {e}")

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

        # Step 2: Scrape candidate pages in PARALLEL (was sequential with 10s waits each)
        from concurrent.futures import ThreadPoolExecutor

        candidate_urls = [r.get("url", "") for r in search_results if r.get("url")]
        # Scrape the top 6 candidates concurrently, then keep the first 3 that succeed
        candidate_urls = candidate_urls[:6]

        combined_text = ""
        scraped_urls: list[str] = []
        valid_pages = 0

        scraped: dict[str, str] = {}
        with ThreadPoolExecutor(max_workers=6) as executor:
            for url, content in zip(
                candidate_urls,
                executor.map(self.scrape_page_content, candidate_urls),
            ):
                scraped[url] = content

        # Preserve search-result ranking order when assembling the context
        for url in candidate_urls:
            content = scraped.get(url, "")
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

        # Step 3: Extraction — cap at 3,000 chars so total prompt stays within model limits
        extraction = self.extract_and_verify_specs(
            combined_text[:3_000], brand, model, equipment_type
        )
        extraction["source_urls"] = scraped_urls if scraped_urls else ["DDG snippets"]
        extraction["pipeline"] = (
            f"ddg-3queries -> beautifulsoup({valid_pages} pages) -> groq-{self.model}"
        )

        # Cache the result so future lookups of this model are instant.
        # Only cache real successes (avoid caching failed/empty extractions).
        if brand and model and extraction.get("fields_found", 0) > 0 and not extraction.get("error"):
            try:
                from app.database import mongo_db
                mongo_db.cache_specs(brand, model, category, extraction)
                print(f"[Pipeline] Cached specs for {brand} {model}")
            except Exception as e:
                print(f"[Pipeline] Cache write failed: {e}")

        return extraction

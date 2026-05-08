from duckduckgo_search import DDGS
import re
import time

class WebSearchService:
    def verify_product_specs(self, product_name: str, db_btu: str):
        """Searches the web for the product name and tries to match specs"""
        print(f"[WebSearch] Searching for: {product_name}...")
        
        try:
            with DDGS() as ddgs:
                # Optimized query for technical specs
                query = f"{product_name} official specifications btu gas"
                results = list(ddgs.text(query, max_results=5))
                
                web_matches = []
                for r in results:
                    snippet = r['body']
                    
                    # Pattern matching for BTU
                    btu_match = re.search(r"(\d{4,5})\s*BTU", snippet, re.IGNORECASE)
                    
                    if btu_match:
                        found_btu = btu_match.group(1)
                        is_correct = (found_btu == db_btu)
                        
                        web_matches.append({
                            "source": r['title'],
                            "url": r['href'],
                            "found_btu": found_btu,
                            "is_correct": is_correct,
                            "snippet": snippet[:200] + "..."
                        })
                
                return {
                    "search_conducted": True,
                    "results_found": len(web_matches),
                    "evidence": web_matches
                }
        except Exception as e:
            print(f"[WebSearch] Error: {e}")
            return {"search_conducted": False, "error": str(e)}

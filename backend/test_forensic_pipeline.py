import os
import sys
import json
from pathlib import Path
from PIL import Image
from io import BytesIO

# Setup environment
os.chdir(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(os.getcwd())

from app.services.yolo_service import YoloService
from app.services.vision_rag_service import VisionRAGService
from app.services.vector_store import VectorStore
from app.services.clip_embedder import CLIPEmbedder

def run_forensic_test(image_path=None):
    print("="*60)
    print("🔍 CYBERSIGHT FORENSIC PIPELINE TEST (V2 DB)")
    print("="*60)

    # 1. Initialize Services
    yolo = YoloService()
    vision = VisionRAGService()
    # Point to our new Forensic V2 Database
    v_store = VectorStore(collection_name="climatiseurs_forensic", path="qdrant_db_v2")
    embedder = CLIPEmbedder()

    # 2. Load Image
    if image_path is None:
        # Fallback to a known sample if no path provided
        image_path = "../dataequipment/climatiseurs/Gree/images/Climatiseur Gree CL12AQCXB-CF Tropicalisé 12000 BTU Chaud Froid - Blanc.jpg"
    
    if not os.path.exists(image_path):
        print(f"❌ Error: Image not found at {image_path}")
        return

    print(f"[1/5] Loading Image: {Path(image_path).name}")
    raw_img = Image.open(image_path).convert("RGB")

    # 3. Forensic Pre-processing
    print("[2/5] Applying Forensic Cleaning (Crop + Enhance)...")
    cropped = yolo.detect_and_crop(raw_img)
    enhanced = yolo.enhance_for_ocr(cropped)
    
    # Save enhanced for Gemini
    buf = BytesIO()
    enhanced.save(buf, format="JPEG")
    enhanced_bytes = buf.getvalue()

    # 4. AI Identification (Gemini)
    print("[3/5] Gemini is analyzing the pixels for Brand/Specs...")
    ai_perception = vision.identify_from_raw_image(enhanced_bytes)
    print(f"      - AI Sees Category: {ai_perception.get('category')}")
    print(f"      - AI Sees Brand: {ai_perception.get('brand')}")
    print(f"      - AI Sees BTU: {ai_perception.get('btu')}")

    # 5. Vector Search (V2 Forensic DB)
    print("[4/5] Searching the Forensic Knowledge Base (V2)...")
    query_vector = embedder.embed_image(enhanced)
    
    # Use AI filters to narrow down search
    brand_filter = ai_perception.get('brand')
    btu_filter = ai_perception.get('btu')
    
    results = v_store.hybrid_search(
        query_vector=query_vector,
        text_query=ai_perception.get('analysis', ""),
        limit=1,
        brand_filter=brand_filter,
        btu_filter=btu_filter
    )

    if not results:
        print("❌ No matches found in the database.")
        return

    best_match = results[0].payload
    score = results[0].score
    print(f"      - Top Match: {best_match.get('brand')} - {best_match.get('model_name')}")
    print(f"      - Similarity Score: {score:.4f}")

    # 6. Final Verification (Gemini)
    print("[5/5] Performing final Forensic Verification...")
    verification = vision.verify_equipment(enhanced_bytes, best_match, score)
    
    print("\n" + "-"*40)
    print("📋 FINAL VERDICT")
    print("-"*40)
    status = "✅ VERIFIED MATCH" if verification.get('is_match_verified') else "❌ DISCREPANCY DETECTED"
    print(f"Status: {status}")
    print(f"Confidence: {verification.get('confidence', 0)*100:.1f}%")
    print(f"AI Reasoning: {verification.get('analysis')}")
    print("-"*40)

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else None
    run_forensic_test(path)

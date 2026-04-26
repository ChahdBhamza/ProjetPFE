import os
from pathlib import Path
from typing import List, Dict, Optional
import json
from tqdm import tqdm
from app.services.clip_embedder import CLIPEmbedder
from app.services.vector_store import VectorStore


class DataLoader:
    def __init__(self, data_root: str = "../dataequipment"):
        """
        Initialize data loader
        
        Args:
            data_root: Root directory containing climatiseurs data (relative to backend/)
        """
        self.data_root = Path(data_root)
        self.embedder = CLIPEmbedder()
        self.vector_store = VectorStore()
    
    def load_climatiseurs_dataset(self) -> List[Dict]:
        """Loads all climatiseurs from the dataequipment/climatiseurs folder"""
        climatiseurs = []
        climatiseurs_path = self.data_root / "climatiseurs"
        
        if not climatiseurs_path.exists():
            print(f"❌ Dataset path not found: {climatiseurs_path}")
            return climatiseurs
        
        # Iterate through brands (Gree, Samsung, etc.)
        for brand_dir in climatiseurs_path.iterdir():
            if not brand_dir.is_dir():
                continue
            
            brand_name = brand_dir.name
            print(f"📁 Scanning brand: {brand_name}")
            
            text_dir = brand_dir / "text"
            image_dir = brand_dir / "images" # Our exporter uses 'images' plural
            
            if text_dir.exists():
                for text_file in text_dir.glob("*.txt"):
                    climatiseur = self._process_climatiseur_file(
                        brand_name,
                        text_file,
                        image_dir
                    )
                    if climatiseur:
                        climatiseurs.append(climatiseur)
        
        return climatiseurs
    
    def _process_climatiseur_file(self, brand: str, text_file: Path, image_dir: Path) -> Optional[Dict]:
        """Reads a text file and finds its matching image"""
        try:
            with open(text_file, 'r', encoding='utf-8') as f:
                specs_text = f.read().strip()
            
            model_name = text_file.stem
            # Create a simple numeric/string ID for Qdrant
            climatiseur_id = abs(hash(f"{brand}_{model_name}")) % (10**8)
            
            # Find matching image
            image_path = None
            if image_dir.exists():
                for ext in ['.jpg', '.jpeg', '.png', '.webp']:
                    potential_image = image_dir / (model_name + ext)
                    if potential_image.exists():
                        image_path = potential_image
                        break
            
            return {
                'id': climatiseur_id,
                'brand': brand,
                'model_name': model_name,
                'specs_text': specs_text,
                'image_path': image_path,
                'file_path': text_file
            }
        except Exception as e:
            print(f"   ⚠️ Error processing {text_file}: {e}")
            return None
    
    def index_dataset(self):
        """Processes the dataset and saves everything to the Vector Database"""
        climatiseurs = self.load_climatiseurs_dataset()
        print(f"🚀 Found {len(climatiseurs)} climatiseurs. Starting AI indexing...")
        
        indexed_count = 0
        
        for item in tqdm(climatiseurs, desc="Indexing"):
            try:
                # 1. Choose which embedding to use (Image is priority for visual search)
                if item['image_path']:
                    embedding = self.embedder.embed_image(item['image_path'])
                else:
                    embedding = self.embedder.embed_text(item['specs_text'])
                
                if embedding is None:
                    continue

                # 2. Save to Vector Store
                metadata = {
                    "specs": item['specs_text'],
                    "text_file": str(item['file_path']),
                    "image_file": str(item['image_path']) if item['image_path'] else "N/A"
                }
                
                self.vector_store.add_climatiseur(
                    product_id=item['id'],
                    brand=item['brand'],
                    model_name=item['model_name'],
                    embedding=embedding,
                    metadata=metadata
                )
                
                indexed_count += 1
            except Exception as e:
                print(f"   ⚠️ Error indexing {item['model_name']}: {e}")
        
        print(f"✨ Successfully indexed {indexed_count} items into the database!")
        return indexed_count

if __name__ == "__main__":
    # To run this, make sure you are in the 'backend' folder
    # and run: python -m app.services.data_loader
    loader = DataLoader()
    loader.index_dataset()

"""
Minimal CLIP Embedding Module
Just the essentials - image and text embeddings
"""

import torch
import numpy as np
from transformers import CLIPProcessor, CLIPModel
from PIL import Image
from typing import Union
from pathlib import Path

class CLIPEmbedder:
    def __init__(self, model_name: str = "openai/clip-vit-base-patch32"):
        """Initialize CLIP model"""
        print(f"Loading CLIP model: {model_name}")
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"Using device: {self.device}")
        
        # Load model and processor
        try:
            self.model = CLIPModel.from_pretrained(model_name).to(self.device)
            self.processor = CLIPProcessor.from_pretrained(model_name)
            self.model.eval()
            print("[OK] CLIP model loaded successfully")
        except Exception as e:
            print(f"[ERROR] Error loading CLIP model: {e}")
            raise e
    
    def embed_image(self, image: Union[str, Image.Image]) -> np.ndarray:
        """Convert image to embedding (Universal fix)"""
        try:
            if isinstance(image, (str, Path)):
                img = Image.open(image).convert("RGB")
            else:
                img = image.convert("RGB")
                
            with torch.no_grad():
                inputs = self.processor(images=img, return_tensors="pt").to(self.device)
                outputs = self.model.get_image_features(**inputs)
                
                # Universal/Brute Force extraction
                if isinstance(outputs, torch.Tensor):
                    features = outputs
                else:
                    # Try common attribute names for CLIP/Vision models
                    features = getattr(outputs, "image_embeds", 
                               getattr(outputs, "pooler_output", 
                               getattr(outputs, "last_hidden_state", None)))
                    
                    if features is None:
                        # Fallback: Just take the first element if it's a sequence
                        features = outputs[0]
                    
                    # If it's a hidden state (Batch, Sequence, Dim), take the CLS token (index 0)
                    if len(features.shape) == 3:
                        features = features[:, 0]
                
                # Final safeguard: Normalize
                features = features / features.norm(dim=-1, keepdim=True)
                
            return features.cpu().numpy()[0]
        except Exception as e:
            print(f"Error embedding image: {e}")
            return None
    
    def embed_text(self, text: str) -> np.ndarray:
        """Convert text to embedding (Universal fix)"""
        try:
            with torch.no_grad():
                inputs = self.processor(text=text, return_tensors="pt").to(self.device)
                outputs = self.model.get_text_features(**inputs)
                
                # Universal/Brute Force extraction
                if isinstance(outputs, torch.Tensor):
                    features = outputs
                else:
                    # Try common attribute names for CLIP/Text models
                    features = getattr(outputs, "text_embeds", 
                               getattr(outputs, "pooler_output", 
                               getattr(outputs, "last_hidden_state", None)))
                    
                    if features is None:
                        # Fallback
                        features = outputs[0]
                    
                    if len(features.shape) == 3:
                        features = features[:, 0]
                
                features = features / features.norm(dim=-1, keepdim=True)

                
            return features.cpu().numpy()[0]
        except Exception as e:
            print(f"Error embedding text: {e}")
            return None
    
    def similarity(self, emb1: np.ndarray, emb2: np.ndarray) -> float:
        """Calculate how similar two embeddings are (Cosine Similarity)"""
        if emb1 is None or emb2 is None:
            return 0.0
        return float(np.dot(emb1, emb2))

if __name__ == "__main__":
    # Test block
    embedder = CLIPEmbedder()
    test_text = "A photo of a white air conditioner"
    embedding = embedder.embed_text(test_text)
    print(f"Test embedding shape: {embedding.shape}")
    print("[OK] CLIP Embedder is working!")

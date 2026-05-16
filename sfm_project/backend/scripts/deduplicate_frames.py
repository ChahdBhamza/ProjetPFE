import cv2
import os
import argparse
import numpy as np

def get_sharpness(img):
    """Calculates the sharpness score of an image."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    return cv2.Laplacian(gray, cv2.CV_64F).var()

def calculate_similarity(img1, img2):
    """Calculates visual similarity."""
    img1 = cv2.resize(img1, (64, 64))
    img2 = cv2.resize(img2, (64, 64))
    return np.mean((img1.astype("float") - img2.astype("float")) ** 2)

def deduplicate(input_dir, window_size=10, similarity_threshold=50.0):
    """
    Advanced Deduplication:
    1. Breaks frames into windows.
    2. Keeps only the sharpest frame in each window.
    3. Removes remaining duplicates.
    """
    files = sorted([f for f in os.listdir(input_dir) if f.lower().endswith(('.jpg', '.png', '.jpeg'))])
    if not files:
        print("No images found.")
        return

    print(f"Processing {len(files)} frames...")
    
    kept_files = []
    
    # 1. SHARPNESS FILTERING (Keep only the best in each window)
    for i in range(0, len(files), window_size):
        window = files[i : i + window_size]
        best_frame = None
        max_sharpness = -1
        
        for f in window:
            img = cv2.imread(os.path.join(input_dir, f))
            if img is None: continue
            
            score = get_sharpness(img)
            if score > max_sharpness:
                max_sharpness = score
                best_frame = f
        
        if best_frame:
            kept_files.append(best_frame)

    # 2. SIMILARITY FILTERING (Remove redundant 'sharp' frames)
    final_files = []
    if kept_files:
        last_img = cv2.imread(os.path.join(input_dir, kept_files[0]))
        final_files.append(kept_files[0])
        
        for i in range(1, len(kept_files)):
            curr_img = cv2.imread(os.path.join(input_dir, kept_files[i]))
            if curr_img is None: continue
            
            sim = calculate_similarity(last_img, curr_img)
            if sim > similarity_threshold: # Only keep if distinct enough
                final_files.append(kept_files[i])
                last_img = curr_img

    # 3. CLEANUP
    to_delete = set(files) - set(final_files)
    print(f"Purging {len(to_delete)} blurry or redundant frames...")
    
    for f in to_delete:
        try:
            os.remove(os.path.join(input_dir, f))
        except:
            pass
            
    print(f"Done! Reduced {len(files)} frames down to {len(final_files)} high-quality unique frames.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", required=True)
    parser.add_argument("--window", type=int, default=10)
    parser.add_argument("--threshold", type=float, default=50.0)
    
    args = parser.parse_args()
    deduplicate(args.dir, args.window, args.threshold)

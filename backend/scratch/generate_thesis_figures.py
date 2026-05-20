import os
import numpy as np
import cv2
import matplotlib.pyplot as plt
from PIL import Image, ImageDraw, ImageFont

# Set matplotlib style for professional scientific figures
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['DejaVu Sans', 'Arial', 'Helvetica']
plt.rcParams['axes.edgecolor'] = '#333333'
plt.rcParams['axes.linewidth'] = 0.8
plt.rcParams['xtick.color'] = '#333333'
plt.rcParams['ytick.color'] = '#333333'

def create_synthetic_ac_image(width=400, height=200, is_blurry=False, draw_bbox=False, has_pillarbox=False):
    """Generates a professional synthetic image representing an indoor split air conditioner."""
    # Create background canvas
    canvas_w = width + (200 if has_pillarbox else 0)
    canvas_h = height
    
    img = Image.new("RGB", (canvas_w, canvas_h), color="#F0F2F5")
    draw = ImageDraw.Draw(img)
    
    # Coordinates of the AC unit relative to the active canvas area
    offset_x = 100 if has_pillarbox else 0
    ac_x1, ac_y1 = offset_x + 50, 40
    ac_x2, ac_y2 = offset_x + 350, 140
    
    # 1. Draw wall shadow/background lines
    draw.line([(0, 160), (canvas_w, 160)], fill="#D1D5DB", width=2) # Wall-floor boundary line
    
    # 2. Draw AC unit body (rounded white rectangle)
    draw.rounded_rectangle([ac_x1, ac_y1, ac_x2, ac_y2], radius=15, fill="#FFFFFF", outline="#E5E7EB", width=2)
    
    # AC logo
    draw.text((offset_x + 180, 80), "COOL-AI", fill="#9CA3AF")
    
    # AC vent lines
    draw.rectangle([ac_x1 + 20, ac_y2 - 25, ac_x2 - 20, ac_y2 - 10], fill="#E5E7EB")
    draw.line([(ac_x1 + 30, ac_y2 - 17), (ac_x2 - 30, ac_y2 - 17)], fill="#9CA3AF", width=2) # main flap
    
    # AC display light
    draw.ellipse([ac_x2 - 50, ac_y1 + 20, ac_x2 - 40, ac_y1 + 30], fill="#10B981") # Green LED
    
    img_np = np.array(img)
    
    # 3. Apply blur if requested (Simulating Motion Blur)
    if is_blurry:
        # Create motion blur kernel (horizontal)
        size = 15
        kernel_motion_blur = np.zeros((size, size))
        kernel_motion_blur[int((size-1)/2), :] = np.ones(size)
        kernel_motion_blur = kernel_motion_blur / size
        img_np = cv2.filter2D(img_np, -1, kernel_motion_blur)
        
    # 4. Draw bounding box if requested (Green YOLO detection box)
    if draw_bbox:
        cv2.rectangle(img_np, (ac_x1 - 10, ac_y1 - 10), (ac_x2 + 10, ac_y2 + 10), (16, 185, 129), 3)
        cv2.putText(img_np, "airconditioner 94.2%", (ac_x1 - 10, ac_y1 - 20), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (16, 185, 129), 2)

    # 5. Add pillarboxes (solid black bars on left/right) if requested
    if has_pillarbox:
        img_np[:, :100] = 0 # Left black bar
        img_np[:, -100:] = 0 # Right black bar
        
    return Image.fromarray(img_np)

def generate_figure_1(output_dir):
    """Generates Figure 2.1: Hero Frame Extraction & Temporal Stabilization."""
    fig = plt.figure(figsize=(10, 5.5), dpi=150)
    
    # Subplot layout: 2 columns on top for images, 1 spanning bottom for line chart
    gs = fig.add_gridspec(2, 2, height_ratios=[1, 1])
    
    ax_blur = fig.add_subplot(gs[0, 0])
    ax_sharp = fig.add_subplot(gs[0, 1])
    ax_plot = fig.add_subplot(gs[1, :])
    
    # 1. Left image: Blurry Frame
    blurry_img = create_synthetic_ac_image(is_blurry=True)
    ax_blur.imshow(blurry_img)
    ax_blur.set_title("Discarded Frame (Shaky Panning Motion)\nLaplacian Sharpness: 18.4 (Low)", fontsize=9, color="#EF4444", fontweight="bold")
    ax_blur.axis("off")
    
    # 2. Right image: Hero Frame (Sharp)
    sharp_img = create_synthetic_ac_image(is_blurry=False)
    ax_sharp.imshow(sharp_img)
    ax_sharp.set_title("Selected 'Hero Frame' (Sharp & In-Focus)\nLaplacian Sharpness: 192.8 (High)", fontsize=9, color="#10B981", fontweight="bold")
    ax_sharp.axis("off")
    
    # 3. Bottom plot: Laplacian Sharpness Curve
    frames = np.arange(1, 11)
    # Synthesize sharpness values peaking at frame 6
    sharpness_scores = [22.4, 25.1, 18.4, 45.2, 110.5, 192.8, 140.2, 85.3, 31.6, 20.1]
    
    ax_plot.plot(frames, sharpness_scores, marker='o', color='#3B82F6', linewidth=2, label="Sharpness Curve")
    # Highlight other frames
    ax_plot.scatter(frames[sharpness_scores < np.max(sharpness_scores)], 
                    np.array(sharpness_scores)[sharpness_scores < np.max(sharpness_scores)], 
                    color='#EF4444', zorder=5)
    # Highlight peak
    ax_plot.scatter(6, 192.8, color='#10B981', s=100, edgecolors='black', linewidth=1.5, zorder=6, label="Selected Hero Frame (Frame 6)")
    
    # Draw vertical helper line
    ax_plot.axvline(x=6, color='#10B981', linestyle='--', alpha=0.7)
    ax_plot.annotate("Peak Sharpness\nFrame 6 (Selected)", xy=(6, 192.8), xytext=(6.5, 160),
                     arrowprops=dict(facecolor='black', shrink=0.08, width=1, headwidth=6),
                     fontsize=8, fontweight="bold")
                     
    ax_plot.set_title("Figure 2.1: Temporal Sliding Window Sharpness Analysis (Laplacian Variance)", fontsize=10, fontweight="bold", pad=10)
    ax_plot.set_xlabel("Frame Sequence (Temporal Sliding Window)", fontsize=8)
    ax_plot.set_ylabel("Laplacian Variance Score ($\sigma^2$)", fontsize=8)
    ax_plot.set_xticks(frames)
    ax_plot.set_xticklabels([f"F{x}" for x in frames])
    ax_plot.grid(True, linestyle=":", alpha=0.5)
    ax_plot.legend(fontsize=8, loc="upper right")
    
    plt.tight_layout()
    fig_path = os.path.join(output_dir, "hero_frame_stabilization.png")
    plt.savefig(fig_path, bbox_inches="tight")
    plt.close()
    print(f"Generated Figure 1: {fig_path}")

def generate_figure_2(output_dir):
    """Generates Figure 2.2: Bounding Box, Pillarbox Trimming, and Edge Normalization."""
    fig, axes = plt.subplots(1, 3, figsize=(11, 4), dpi=150)
    
    # 1. Screen 1: Original Image with Pillarbox + YOLO Box
    img_pillar = create_synthetic_ac_image(draw_bbox=True, has_pillarbox=True)
    axes[0].imshow(img_pillar)
    axes[0].set_title("Step 1: Video Frame Capture\nwith Pillarbox & YOLO Box", fontsize=8, fontweight="bold")
    axes[0].set_xlabel("Black pillarbox borders present\non left & right edges", fontsize=7)
    axes[0].set_xticks([])
    axes[0].set_yticks([])
    
    # 2. Screen 2: Bounding Box Crop (Contains Pillarbox remnants)
    # The bounding box was from x1=40 (which is inside the black bar area since AC starts at 50+100=150)
    # Let's crop from the raw pillarbox image: bounding box crop
    # AC coordinate in pillarbox image: x1 = 150, x2 = 450, box is x1-10=140 to x2+10=460. Let's crop it.
    img_pillar_np = np.array(img_pillar)
    crop_pillar = img_pillar_np[30:150, 140:460]
    axes[1].imshow(crop_pillar)
    axes[1].set_title("Step 2: Raw Bounding Box Crop\n(With Clutter & Border Noise)", fontsize=8, fontweight="bold")
    axes[1].set_xlabel("Black border and edge artifacts\nremain at margins", fontsize=7)
    axes[1].set_xticks([])
    axes[1].set_yticks([])
    
    # 3. Screen 3: Border Trimmed + 2% Safety Margin Crop
    # Trims black borders and applies a 2% inner safety crop
    clean_crop = img_pillar_np[42:138, 152:448] # Fully trimmed active content
    axes[2].imshow(clean_crop)
    axes[2].set_title("Step 3: Final Normalized Crop\n(Pillarbox Trimmed + 2% Edge Crop)", fontsize=8, fontweight="bold")
    axes[2].set_xlabel("Fully cleaned active content\noptimized for CLIP & LLM", fontsize=7)
    axes[2].set_xticks([])
    axes[2].set_yticks([])
    
    plt.suptitle("Figure 2.2: Bounding Box Extraction, Pillarbox Trimming, and Visual Optimization Pipeline", fontsize=10, fontweight="bold", y=0.98)
    plt.tight_layout()
    fig_path = os.path.join(output_dir, "bounding_box_and_cropping.png")
    plt.savefig(fig_path, bbox_inches="tight")
    plt.close()
    print(f"Generated Figure 2: {fig_path}")

def generate_figure_3(output_dir):
    """Generates Figure 2.3: Web Scraping and Sanitization Flow."""
    fig, axes = plt.subplots(1, 2, figsize=(10, 4.5), dpi=150)
    axes[0].axis('off')
    axes[1].axis('off')
    
    # 1. Draw Raw Scraping Code mockup (Visual Code Block)
    raw_html_text = (
        "<html>\n"
        " <head>\n"
        "  <script src='analytics.js'></script>  <!-- DECOMPOSED -->\n"
        "  <style> body { margin:0; } </style>  <!-- DECOMPOSED -->\n"
        " </head>\n"
        " <body>\n"
        "  <nav> Home | Air Conditioners </nav> <!-- DECOMPOSED -->\n"
        "  <div class='product-info'>\n"
        "   <table> <!-- DENSE TABLE ISOLATED -->\n"
        "    <tr>\n"
        "      <td><b>Energy Class</b></td>\n"
        "      <td>A+++</td>\n"
        "    </tr>\n"
        "    <tr>\n"
        "      <td><b>Refrigerant</b></td>\n"
        "      <td>R32</td>\n"
        "    </tr>\n"
        "   </table>\n"
        "  </div>\n"
        "  <footer> Contact support </footer>  <!-- DECOMPOSED -->\n"
        " </body>\n"
        "</html>"
    )
    
    axes[0].text(0.05, 0.95, "A. RAW UNSANITIZED SCRAPED HTML", fontsize=9, fontweight="bold", color="#EF4444")
    # Draw background box for HTML code
    rect_html = plt.Rectangle((0, 0), 1, 0.9, facecolor="#F8FAFC", edgecolor="#EF4444", linewidth=1.5)
    axes[0].add_patch(rect_html)
    axes[0].text(0.05, 0.1, raw_html_text, family="monospace", fontsize=7.5, verticalalignment="bottom", color="#475569")
    
    # 2. Draw Cleaned Structured Output Table mockup
    axes[1].text(0.05, 0.95, "B. CLEANED SPEC TABLES & EXTRACTED DATA", fontsize=9, fontweight="bold", color="#10B981")
    rect_clean = plt.Rectangle((0, 0), 1, 0.9, facecolor="#F8FAFC", edgecolor="#10B981", linewidth=1.5)
    axes[1].add_patch(rect_clean)
    
    cleaned_spec_text = (
        "=== ISOLATED HIGH-DENSITY LINE ===\n"
        "Energy Class | A+++ | Refrigerant | R32\n\n"
        "=== EXTRACTED & VERIFIED JSON SCHEMA ===\n"
        "{\n"
        "  \"brand\": \"COOL-AI\",\n"
        "  \"verified\": true,\n"
        "  \"source_quality\": \"high\",\n"
        "  \"specs\": {\n"
        "    \"energy_class\": \"A+++\",\n"
        "    \"refrigerant\": \"R32\",\n"
        "    \"capacity\": \"12000 BTU\",\n"
        "    \"inverter\": \"Yes\"\n"
        "  },\n"
        "  \"fields_found\": 4\n"
        "}"
    )
    axes[1].text(0.05, 0.1, cleaned_spec_text, family="monospace", fontsize=8, verticalalignment="bottom", color="#1E293B")
    
    # Draw arrow in the middle
    plt.suptitle("Figure 2.3: Web-Scraping Cleaning Pipeline (Decomposition & Spec Structuring)", fontsize=10, fontweight="bold", y=0.98)
    plt.tight_layout()
    fig_path = os.path.join(output_dir, "web_scraping_cleaning.png")
    plt.savefig(fig_path, bbox_inches="tight")
    plt.close()
    print(f"Generated Figure 3: {fig_path}")

if __name__ == "__main__":
    # 1. Save to App Data Artifacts directory (so it renders in the chat)
    output_directory_artifacts = r"C:\Users\chahd\.gemini\antigravity\brain\04e2c12c-5fe0-406f-afc1-7142860ab627\artifacts"
    os.makedirs(output_directory_artifacts, exist_ok=True)
    
    generate_figure_1(output_directory_artifacts)
    generate_figure_2(output_directory_artifacts)
    generate_figure_3(output_directory_artifacts)
    
    # 2. Save to Workspace Docs/Figures directory
    output_directory_docs = r"c:\Users\chahd\Desktop\DetectionAppPFE\docs\figures"
    os.makedirs(output_directory_docs, exist_ok=True)
    
    generate_figure_1(output_directory_docs)
    generate_figure_2(output_directory_docs)
    generate_figure_3(output_directory_docs)
    
    print("SUCCESS: All thesis visual figures generated in both app data and workspace docs folders!")


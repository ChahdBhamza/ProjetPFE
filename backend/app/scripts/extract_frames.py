import os
import subprocess
import argparse

def extract_frames_ffmpeg(video_path, output_dir, interval=10):
    """
    Extracts frames using FFmpeg for high performance.
    :param video_path: Path to the video file
    :param output_dir: Directory to save extracted frames
    :param interval: Extract every Nth frame
    """
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Clean the directory first
    for f in os.listdir(output_dir):
        if f.endswith(".jpg"):
            os.remove(os.path.join(output_dir, f))

    print(f"Starting FFmpeg extraction (every {interval} frames)...")
    
    # Try to find ffmpeg in the common WinGet path as a fallback
    ffmpeg_path = "ffmpeg"
    winget_path = r"C:\Users\chahd\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.1-full_build\bin\ffmpeg.exe"
    if os.path.exists(winget_path):
        ffmpeg_path = winget_path

    # FFmpeg command:
    # We use a raw string for the filter to avoid Python syntax warnings
    filter_str = rf"select='not(mod(n\,{interval}))'"
    
    cmd = [
        ffmpeg_path,
        "-i", video_path,
        "-vf", filter_str,
        "-vsync", "vfr",
        "-q:v", "2",
        os.path.join(output_dir, "frame_%04d.jpg")
    ]

    try:
        subprocess.run(cmd, check=True)
        print(f"Done! Frames saved to '{output_dir}'.")
    except FileNotFoundError:
        print("Error: FFmpeg not found. Please ensure FFmpeg is installed and in your PATH.")
    except subprocess.CalledProcessError as e:
        print(f"FFmpeg Error: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract frames using FFmpeg")
    parser.add_argument("--input", required=True, help="Path to input video")
    parser.add_argument("--output", default="extracted_frames", help="Output directory")
    parser.add_argument("--interval", type=int, default=10, help="Extract every Nth frame")
    
    args = parser.parse_args()
    
    # Note: If winget installation is fresh, the user might need to restart their terminal
    # for 'ffmpeg' to be recognized.
    extract_frames_ffmpeg(args.input, args.output, args.interval)

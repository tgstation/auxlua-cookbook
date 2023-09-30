import re
import numpy
from PIL import Image
from PIL.PngImagePlugin import PngInfo
import based
import os, shutil
import sys
import subprocess
from yt_dlp import YoutubeDL, DownloadError

def main(youtubeUrl, size = 1, sampling = "nearest", frameRate = 30, startPosition = 0, videoDuration = 600):
    frames = []
    sampling_real = Image.Resampling.NEAREST
    if sampling == "bicubic":
        sampling_real = Image.Resampling.BICUBIC
    dmiWidth = 11 * size
    dmiHeight = 10 * size
    skipFrames = 1
    if not os.path.exists("./temp"):
        os.mkdir("./temp")
    for filename in os.listdir("./temp"):
        file_path = os.path.join("./temp", filename)
        try:
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.unlink(file_path)
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)
        except Exception as e:
            print('Failed to delete %s. Reason: %s' % (file_path, e))
            return ("0",)
    videoPath = os.path.join("./temp", '_video.mp4')
    def longer_than_an_hour(info, *, incomplete):
        """Download only videos longer than a minute (or with unknown duration)"""
        duration = info.get('duration')
        if not duration or duration > 3600:
            return 'The video is too long'
    ydl_opts = {
        "noplaylist": True,
        "outtmpl": os.path.join("./temp", '_youtube.mp4'),
        "format": "mp4",
        "match_filter": longer_than_an_hour,
        "forceurl": True,
    }
    youtubeId = re.search("(v=|v/|vi=|vi/|youtu.be/|shorts/)([a-zA-Z0-9_-]+)", youtubeUrl)
    # Just in case it's garbage
    if not youtubeId or len(youtubeId.group(2)) > 16:
        return ("0",)
    
    ytVid = "https://www.youtube.com/watch?v="+youtubeId.group(2)

    title = ""
    with YoutubeDL(ydl_opts) as ydl:
        try:
            data = ydl.extract_info(ytVid)
        except DownloadError:
            return ("0",)
        if not data:
            return ("0",)
        title = data.get("title", "")
    success = subprocess.run(["ffmpeg", "-y", "-ss", str(startPosition), "-i", os.path.join("./temp", "_youtube.mp4"), "-t", str(videoDuration), videoPath])
    if success.returncode != 0:
        return ("0",)
    success = subprocess.run(["ffmpeg", "-y", "-i", videoPath, "-r", str(frameRate), os.path.join('temp', 'temp%05d.jpeg')])
    if success.returncode != 0:
        return ("0",)
    success = subprocess.run(["ffmpeg", "-y", "-i", videoPath, os.path.join('temp', '_audio.mp3')])
    if success.returncode != 0:
        return ("0",)
    frameCount = 0
    print("Loading frames")
    for file in os.listdir("./temp"):
        if not file.endswith(".jpeg"):
            continue
        with Image.open(os.path.join("./temp", file)) as f:
            newImage = f.resize((dmiWidth, dmiHeight), sampling_real)
            frames.append(numpy.insert(numpy.array(newImage, dtype=numpy.uint8), 3, 255, axis=2))
            frameCount += 1
    print("Loaded frames")

    based.createImage("temp", dmiWidth, dmiHeight, frames, frameCount, frameRate, skipFrames)
    print(f"Finished generating image for youtube video {ytVid}")
    return ("1", title)

if __name__ == "__main__":
    if len(sys.argv) >= 2:
        main(sys.argv[1])
    else:
        print("Expected 1 argument (youtube url)")
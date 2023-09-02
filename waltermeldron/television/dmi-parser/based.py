import numpy
from PIL import Image
from PIL.PngImagePlugin import PngInfo
import math
import os
import sys
import subprocess
from sanitize_filename import sanitize

def rgbaToInt(red, green, blue, alpha):
    return numpy.array([red, green, blue, alpha], dtype=numpy.uint8)

backgroundColor = rgbaToInt(192, 192, 192, 0)

def addToImage(image, targetImage, xTarget, yTarget):
    yPos = 0
    for y in targetImage:
        xPos = 0
        for x in y:
            image[yTarget + yPos, xTarget + xPos] = x
            xPos += 1
        yPos += 1

def emptyFrame(width, height):
    return numpy.full((height, width, 4), backgroundColor, dtype=numpy.uint8)

def buildMetadata(dmiWidth, dmiHeight, frameCount, frameRate, frameSkip):
    comment = "# BEGIN DMI\n"
    comment += "version = 4.0\n"
    comment += f"\twidth = {dmiWidth}\n"
    comment += f"\theight = {dmiHeight}\n"
    comment += "state = on\n"
    comment += "\tdirs = 1\n"
    comment += f"\tframes = {math.floor(frameCount / frameSkip)}\n"
    comment += f"\tdelay = {','.join((str(10 / frameRate),) * math.floor(frameCount / frameSkip))}\n"
    comment += "# END DMI\n"
    return comment

def buildData(dmiWidth, dmiHeight, frames, frameCount, frameSkip):
    frameCount = math.floor(frameCount / frameSkip)
    frameCountSqrt = math.ceil(math.sqrt(frameCount))
    pngWidth = frameCountSqrt * dmiWidth
    pngHeight = math.ceil(frameCount / frameCountSqrt) * dmiHeight
    resultImage = emptyFrame(pngWidth, pngHeight)

    truePosition = 0
    position = 0
    lastPercentComplete = 0
    for data in frames:
        truePosition += 1
        if truePosition % frameSkip != 0:
            continue
        percentComplete = position / frameCount
        if abs(lastPercentComplete - percentComplete) > 0.05:
            print(f"Progress: {math.floor(percentComplete * 100)}%")
            lastPercentComplete = percentComplete
        frameX = (position % frameCountSqrt) * dmiWidth
        frameY = math.floor(position / frameCountSqrt) * dmiHeight
        addToImage(resultImage, data, frameX, frameY)
        position += 1

    return resultImage

# const result = await encodePng(data, { colorType: 6, ancillaryChunks: [{ keyword: "Description", text: metadata, type: 'zTXt', compressionLevel: undefined }], ancillaryChunksAfterIHDR: true }); 
def createImage(directory, dmiWidth, dmiHeight, frames, frameCount, frameRate, frameSkip):
    print("Building metadata")
    metadata = buildMetadata(dmiWidth, dmiHeight, frameCount, frameRate, frameSkip)
    print("Built metadata")
    print("Building data")
    data = buildData(dmiWidth, dmiHeight, frames, frameCount, frameSkip)
    print("Built data")
    metadataPngInfo = PngInfo()
    metadataPngInfo.add_text("Description", metadata)

    image = Image.fromarray(data)
    image.save(os.path.join(directory, f"_{sanitize(directory)}_{dmiWidth}x{dmiHeight}.dmi"), format="png", pnginfo=metadataPngInfo)

def main():
    if len(sys.argv) < 3:
        print("Expected 2 args (directory, width, height: optional, frameRate: optional, skipFrames: optional)")
        return
    frames = []
    dmiWidth = int(sys.argv[2])
    dmiHeight = None
    frameRate = 30
    skipFrames = 1
    if len(sys.argv) >= 4:
        try:
            dmiHeight = int(sys.argv[3])
        except:
            dmiHeight = None
    if len(sys.argv) >= 5:
        frameRate = int(sys.argv[4])
    if len(sys.argv) >= 6:
        skipFrames = int(sys.argv[5])
    if not os.path.exists(sys.argv[1]):
        ytVid = input("Input youtube video to fetch: ")
        videoPath = os.path.join(sys.argv[1], '_video.mp4')
        subprocess.run(f"yt-dlp.exe -f mp4 -o {videoPath} {ytVid}")
        subprocess.run(f"ffmpeg -y -i {videoPath} -r {frameRate} {os.path.join(sys.argv[1], sys.argv[1] + '%05d.jpeg')}")
        subprocess.run(f"ffmpeg -y -i {videoPath} {os.path.join(sys.argv[1], '_audio.mp3')}")
    frameCount = 0
    print("Loading frames")
    for file in os.listdir(sys.argv[1]):
        if not file.endswith(".jpeg"):
            continue
        with Image.open(os.path.join(sys.argv[1], file)) as f:
            if dmiHeight == None:
                percentShrink = dmiWidth/f.width
                dmiHeight = int(float(f.height)*float(percentShrink))
            newImage = f.resize((dmiWidth, dmiHeight), Image.Resampling.NEAREST)
            frames.append(numpy.insert(numpy.array(newImage, dtype=numpy.uint8), 3, 255, axis=2))
            frameCount += 1
    print("Loaded frames")

    createImage(sys.argv[1], dmiWidth, dmiHeight, frames, frameCount, frameRate, skipFrames)
    print("Finished generating image")

if __name__ == "__main__":
    main()
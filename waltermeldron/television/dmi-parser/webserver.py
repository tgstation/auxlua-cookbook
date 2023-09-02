import os
import io
import gc
import subprocess
import re
from flask import Flask, request, send_file, abort, make_response, jsonify
import secrets
import string
import based_tv
import threading

authorization_token = ''.join(secrets.choice(string.ascii_uppercase + string.ascii_lowercase) for i in range(21))

app = Flask(__name__)

def hhmmss_to_seconds(string):
	new_time = 0
	separated_times = string.split(":")
	new_time = 60 * 60 * float(separated_times[0])
	new_time += 60 * float(separated_times[1])
	new_time += float(separated_times[2])
	return new_time

doingFetch = False
returnValue = ("0",)

def performFetch(youtubeUrl, size, sampling, frames, startTime, duration):
    global doingFetch, returnValue
    doingFetch = True
    returnValue = based_tv.main(youtubeUrl, size, sampling, frames, startTime, duration)
    doingFetch = False

@app.route("/check-fetch")
def check_fetch():
    if authorization_token != request.headers.get("Authorization", ""):
        abort(401)

    responseText = returnValue[0]
    if doingFetch:
        responseText = "Not ready"

    return make_response(responseText, 200)

@app.route("/perform-fetch")
def perform_fetch():
    if authorization_token != request.headers.get("Authorization", ""):
        abort(401)

    if doingFetch:
        abort(503)

    youtubeUrl = request.args.get("youtube-url", '')
    size = int(request.args.get("size", ''))
    sampling = request.args.get("sampling", '')
    frames = int(request.args.get("frames", ''))
    maxVideoLength = int(request.args.get("max-video-length", ''))
    startTime = int(request.args.get("start-time", '0'))
    duration = int(request.args.get("duration", str(maxVideoLength)))
    duration = min(duration, maxVideoLength)
    fetchThread = threading.Thread(target=performFetch, args=(youtubeUrl,size,sampling,frames,startTime,duration))
    fetchThread.start()
    return make_response("OK", 200)

@app.route("/get-settings-data")
def get_settings_data():
    if authorization_token != request.headers.get("Authorization", ""):
        abort(401)

    responseData = ""
    try:
        with open("./player_settings.json", "r") as f:
            responseData = f.read()
    except IOError as e:
        pass

    print("Fetching settings data")
    return make_response(responseData, 200)

@app.route("/set-settings-data")
def set_settings_data():
    if authorization_token != request.headers.get("Authorization", ""):
        abort(401)

    text = request.data.decode("utf-8")
    with open("./player_settings.json", "w") as f:
        f.write(text)
    print("Saving data")

    return make_response("OK", 200)

@app.route("/get-dmi")
def get_dmi():
    if authorization_token != request.headers.get("Authorization", ""):
        abort(401)

    size = int(request.args.get("size", ''))
    fileName = f"./temp/_temp_{11*size}x{10*size}.dmi"

    response = send_file(fileName, as_attachment=True, download_name='video.dmi')
    response.headers["video-title"] = returnValue[1].encode("ascii", errors="ignore")
    print("Sending icon")
    return response

@app.route("/get-audio")
def get_audio():
    if authorization_token != request.headers.get("Authorization", ""):
        abort(401)
    if os.path.exists("./temp/_audio.ogg"):
        os.remove("./temp/_audio.ogg")
    subprocess.run(["ffmpeg", "-i", "./temp/_audio.mp3", "-y", "-c:a", "libvorbis", "-b:a", "64k", "./temp/_audio.ogg"])

    ffprobe_result = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", "./temp/_audio.ogg"], capture_output=True)
    length = round(float(ffprobe_result.stdout.decode("utf-8")), 1)
    print("Sending audio")
    response = send_file("./temp/_audio.ogg", as_attachment=True, download_name='audio.ogg', mimetype="audio/ogg")
    response.headers["audio-length"] = str(length)
    return response

@app.route("/health-check")
def tts_health_check():
    gc.collect()
    return "OK", 200

if __name__ == "__main__":
    if os.getenv('TTS_LD_LIBRARY_PATH', "") != "":
        os.putenv('LD_LIBRARY_PATH', os.getenv('TTS_LD_LIBRARY_PATH'))
    from waitress import serve
    print(f"Authorization token is {authorization_token}")
    serve(app, host="0.0.0.0", port=30020, threads=2, backlog=4, connection_limit=24, channel_timeout=30)

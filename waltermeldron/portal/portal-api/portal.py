import os
import io
import gc
import subprocess
import re
from flask import Flask, request, send_file, abort, make_response, jsonify
import secrets
import string
import threading
import time

authorization_token = ''

default_auth_token = ''.join(secrets.choice(string.ascii_uppercase + string.ascii_lowercase) for i in range(21))

app = Flask(__name__)

serverMapping = {}

SERVER_1 = "server1"
SERVER_2 = "server2"

servers = [
    SERVER_1,
    SERVER_2
]

targetMapping = {
    SERVER_1: SERVER_2,
    SERVER_2: SERVER_1
}

untakenServers = servers.copy()

TRANSFER_NONE = 0
TRANSFER_SENDING = 1
TRANSFER_RECEIVED = 2

class GlobalContext:
    Data = ""
    From = ""
    Target = ""
    TransferState = TRANSFER_NONE
    ServerLink = ""
    TimeUntilDie = 0

context = GlobalContext()

@app.route("/check-transfer")
def check_fetch():
    if authorization_token != request.headers.get("Authorization", ""):
        abort(401)
    server = request.headers.get("Server", '')

    if context.TransferState == TRANSFER_NONE:
        return make_response("No transfer", 200)

    timeNow = time.time()
    if timeNow >= context.TimeUntilDie:
        context.TransferState = TRANSFER_NONE
        print("Timeout occured. Resetting state.")
        return make_response("Timeout", 200)

    if context.From == server:
        if context.TransferState == TRANSFER_RECEIVED:
            return make_response("Transferred", 200)
        else:
            return make_response("Transferring", 200)

    if context.Target != server:
        return make_response("Invalid target", 200)

    return make_response("Ready", 200)

@app.route("/receive-transfer")
def receive_transfer():
    if authorization_token != request.headers.get("Authorization", ""):
        abort(401)

    if context.TransferState != TRANSFER_SENDING:
        abort(400)

    server = request.headers.get("Server", '')
    serverLink = request.args.get("link", '')
    if context.Target != server:
        abort(401)
    
    context.TransferState = TRANSFER_RECEIVED
    context.ServerLink = serverLink
    context.TimeUntilDie = time.time() + 30
    print(f"Transferring data to {context.Target}")
    return make_response(context.Data, 200)

@app.route("/get-server-id")
def get_server_id():
    if authorization_token != request.headers.get("Authorization", ""):
        abort(401)

    server = request.args.get("link", '')
    if server in serverMapping:
        return jsonify(serverMapping[server])

    me = untakenServers.pop()
    returnData = {}
    returnData["me"] = me
    returnData["target"] = targetMapping[me]

    serverMapping[server] = returnData

    print(f"Initializing for {server}")
    return jsonify(returnData)

@app.route("/finish-transfer")
def finish_transfer():
    if authorization_token != request.headers.get("Authorization", ""):
        abort(401)

    if context.TransferState != TRANSFER_RECEIVED:
        abort(400)

    server = request.headers.get("Server", '')
    if context.From != server:
        abort(401)

    context.TransferState = TRANSFER_NONE
    print(f"Finishing transfer for {context.Target}")
    return make_response(context.ServerLink, 200)

@app.route("/make-transfer", methods=["POST"])
def make_transfer():
    if authorization_token != request.headers.get("Authorization", ""):
        abort(401)

    if context.TransferState != TRANSFER_NONE:
        abort(400)

    server = request.headers.get("Server", '')
    target = request.args.get("target", '')

    if server not in servers:
        abort(400)
    if target not in servers:
        abort(400)

    context.TransferState = TRANSFER_SENDING
    context.Data = request.get_json(force = True)
    context.From = server
    context.Target = target
    context.TimeUntilDie = time.time() + 30
    print(f"Making transfer to {context.Target}")
    return make_response("OK", 200)

@app.route("/health-check")
def tts_health_check():
    gc.collect()
    return "OK", 200

if __name__ == "__main__":
    from waitress import serve
    authorization_token = input("Set auth token: ")
    if(authorization_token == ''):
        authorization_token = default_auth_token
    print(f"Authorization token is {authorization_token}")
    serve(app, host="0.0.0.0", port=30020, threads=1, backlog=4, connection_limit=24, channel_timeout=30)

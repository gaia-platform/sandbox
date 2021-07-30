import os
import time
import sys
import threading
import queue
import json

from flask import request
from flask import Response
from flask import Flask
from flask import render_template
from flask import make_response

app = Flask(__name__)

msg_queue = queue.Queue()

read_path = "/tmp/pipe-from-gaia"
write_path = "/tmp/pipe-to-gaia"

if os.path.exists(read_path):
    os.remove(read_path)
if os.path.exists(write_path):
    os.remove(write_path)

os.mkfifo(write_path)
os.mkfifo(read_path)
 
def reader():
    while True:
        with open(read_path) as fifo:
            for line in fifo:
                msg_queue.put(line)

@app.route('/', methods=['GET'])
def index():
    # return the rendered template
    return render_template("index.html")

@app.route('/receive', methods=['GET'])
def receive():
    result = ''
    if not msg_queue.empty():
        result = msg_queue.get()
        msg_queue.task_done()

    if (len(result) == 0):
        result = '{ data: "none" }'
    return result.strip()

@app.route('/send', methods=['POST'])
def send():
    data = request.get_json()
    if 'database' in data and data['database'] == 'reset':
        msg_queue.queue.clear()
    if (data and len(data) > 0):
        with open(write_path, "w") as ofifo:
            ofifo.write(json.dumps(data) + '\n')

    return json.dumps({'success':True}), 200, {'ContentType':'application/json'} 

if __name__ == '__main__':
    th = threading.Thread(target=reader)
    th.daemon = True
    th.start()
    try:
        app.run(host='0.0.0.0')
    except RuntimeError:
        print("Exiting")
        pass

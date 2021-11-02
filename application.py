import sys

from flask import Flask
from flask import render_template

app = Flask(__name__)

@app.route('/', methods=['GET'])
def index():
    # return the rendered template
    return render_template("index.html", coordinator=sys.argv[1])

@app.route('/health', methods=['GET'])
def health():
    return 'OK'

if __name__ == '__main__':
    try:
        app.run(host='0.0.0.0')
    except RuntimeError:
        print("Exiting")
        pass

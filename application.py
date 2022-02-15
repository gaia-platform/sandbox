import sys

from flask import Flask, request
from flask import render_template

app = Flask(__name__)

def scenario(args):
    return args['scenario'] if 'scenario' in args else 'frequent_flier'

@app.route('/', methods=['GET'])
def index():
    # return the rendered template
    return render_template("index.html", coordinator=sys.argv[1], maintenance=sys.argv[2], scenario=scenario(request.args))

@app.route('/test', methods=['GET'])
def index_test():
    # return the rendered template
    return render_template("index.html", coordinator=sys.argv[1], maintenance="false", scenario=scenario(request.args))

@app.route('/health', methods=['GET'])
def health():
    return 'OK'

if __name__ == '__main__':
    try:
        app.run(host='0.0.0.0')
    except RuntimeError:
        print("Exiting")
        pass

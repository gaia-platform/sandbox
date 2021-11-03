# Gaia Sandbox
A web-based environment to test and learn about the Gaia Platform for free!
# Sandbox development setup
## Website development
You'll need to

* Install Flask via Python 3 with Pip in order to launch the website
* Aquire dependencies via npm in order to make changes to the JavaScript code

### Installing Flask
[Download and install](https://www.python.org/downloads/) the latest version of Python 3 (which should come with Pip). Next, clone the repository and run the following:
```bash
cd {where_you_cloned_the_repo}
pip install -r requirements.txt
```
This will install Flask if you don't already have it installed. You are now ready to launch the Flask server with `./start_sandbox.sh`. All HTML/website sources are contained under the `Website` directory. If you intend to make changes to the JavaScript code, you'll need to install dependencies.

### Installing other dependencies
[Install](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm) the latest Node.js and npm. Then run the following:
```bash
cd {where_you_cloned_the_repo}
npm i
```
Once all dependencies are installed, you can make changes to the code and recompile them with `npm run build` (do this in the `Website` directory).

**You may stop here if you just want to develop website UI and don't want to interact with MQTT or the sandbox simulations.**

## MQTT topic listing and debugging

If you find that you need to listen to MQTT topics or directly publish to topics, please read this section.

All of the MQTT topics used in the sandbox are in the file [MQTT Communication Specifications Doc](https://github.com/gaia-platform/sandbox/blob/main/MQTT%20Communication%20Specs.md). There you can see the topic structure as well as which topics are published/subscribed to by the sandbox and simulation.

To interact with MQTT directly, please download `mqtt-explorer.zip` located at the root of this repo, unzip it, and open `index.html`. This is a simple, pre-authenticated, applet which will let you communicate directly with the MQTT broker. Prefix your MQTT topics with `[UUID]/` and replace `[UUID]` with either your `REMOTE_CLIENT_ID` for publishing or your `appUUID` for subscribing. You can view your UUIDs by clicking the "Show REMOTE_CLIENT_ID" or "Show Subscribe UUID" buttons in the top right of the sandbox.

## Sandbox visual development
Note: This is only necessary for simulation development

You'll need to

* Install Godot 3.3.2 or later
* Download Godot export templates
* (optionally) Configure external editors

### Installing Godot
1. Go to [Godot's download page](https://godotengine.org/download/) and install the latest 64-bit Standard version. The Mono version (for C# support) is not required.
2. Scroll down a bit further to download the export templates (be sure to match the version of Godot you installed).
3. Add Godot to your system path such that `godot` can be called from the command line. `start_sandbox.sh` uses this to compile the godot project before deployment.
### Configuring Godot and external editors
1. Launch Godot and select "Import" from the right column. Navigate to `{where_you_cloned_the_repo}/SandboxVisual` and select the `project.godot` file to open the project in Godot.
2. In the menu bar, under Editor > Manage Export Templates..., select "Install From File" and select the Godot Export Template you downloaded in a previous step (it's a `.tpz` file)
3. If you prefer to use a different code editor than the built in one, follow the instructions [here](https://docs.godotengine.org/en/stable/getting_started/editor/external_editor.html).
    * If you use VSCode, the [godot-tools](https://marketplace.visualstudio.com/items?itemName=geequlim.godot-tools) addon offers great IntelliSense support in addition to code highlighting and debugging.
### Deploying the visual component inside the sandbox
`start_sandbox.sh` uses the `godot` CLI to export the Godot game for embedding into the Flask server. To make this work for sure (on Linux), run
```bash
. ./start_sandbox.sh
```
The extra period out front will run the script with your environment variables (such as PATH).

The above command will launch the sandbox without communicating with a coordinator. To enable communication with a coordinator (necessary in production) specify the coordinator name with the `-c` option.
```bash
. ./start_sandbox.sh -c <the coordinator name>
```
Do *not* use the name sandbox_coordinator unless running in production.
___
Please contact [Steve Harris](mailto:steve@gaiaplatform.io) for questions.

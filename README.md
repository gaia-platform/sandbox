# Gaia Sandbox
A web-based environment to test and learn about the Gaia Platform for free!
# Sandbox development setup
## Website development
You'll need Python 3 with Pip. Clone the repository and run the following:
```bash
cd {where_you_cloned_the_repo}/Website
pip install -r requirements.txt
```
This will install Flask if you don't already have it installed. You are now ready to launch the Flask server with `./start_sandbox.sh`. All HTML/website sources are contained under the `Website` directory.
## Sandbox visual development
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
___
Please contact [Steve Harris](mailto:steve@gaiaplatform.io) or [Kenneth Yang](kenneth@gaiaplatform.io) for questions.
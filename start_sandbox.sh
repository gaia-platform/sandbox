#!/bin/bash
godot --no-window --path ./SandboxVisual --export "HTML5"
sed -i "16s/.*/\t\t\tbackground-color: white;/" static/visual/index.html # Change loading screen to white
sed -i "58s/.*/\t\t\tbackground-color: gray;/" static/visual/index.html # Change loading progress bar to gray
sed -i "195s/.*/\t\t\t\t\tstatusIndeterminate.children[i].style.borderTopColor = 'gray';/" static/visual/index.html # Change loading wheel to gray
python3 application.py
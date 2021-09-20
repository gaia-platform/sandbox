#!/bin/bash

DEBUG=false

if [ $# -eq 1 ]; then
    if [ "$1" = "--debug" ]; then
        DEBUG=true
    else
        echo "Unrecognized argument: $1"
        exit 1
    fi	
fi

if [ $DEBUG = true ]; then
    echo "Running in debug mode"
    godot --no-window --path ./SandboxVisual --export-debug "HTML5"
else
    godot --no-window --path ./SandboxVisual --export "HTML5"
fi
sed -i "16s/.*/\t\t\tbackground-color: #f4f6f8;/" static/visual/index.html # Change loading screen to white
sed -i "58s/.*/\t\t\tbackground-color: gray;/" static/visual/index.html # Change loading progress bar to gray
sed -i "195s/.*/\t\t\t\t\tstatusIndeterminate.children[i].style.borderTopColor = 'gray';/" static/visual/index.html # Change loading wheel to gray
python3 application.py

#!/bin/bash
godot --no-window --path ../SandboxVisual --export "HTML5"
python3 sandbox.py
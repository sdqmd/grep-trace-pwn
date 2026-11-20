"""Misc helpers. Devs love wrapping dangerous things in friendly names."""
import os
import subprocess

DOCS_DIR = os.path.join(os.path.dirname(__file__), "docs")


def run_cmd(cmd):
    # Flow 2 sink, hidden behind a wrapper. grep for subprocess finds this.
    # grep for run_cmd finds who calls it.
    out = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
    return out.stdout + out.stderr


def read_doc(name):
    # Flow 3 sink. os.path.join does NOT sanitize "../".
    path = os.path.join(DOCS_DIR, name)
    with open(path) as f:
        return f.read()

"""Misc helpers. FIXED: no shell, and a path check that actually checks.
Compare: diff -u flask_app/utils.py flask_app_fixed/utils.py"""
import os
import subprocess

DOCS_DIR = os.path.realpath(os.path.join(os.path.dirname(__file__), "docs"))


def run_cmd(argv):
    # FIXED: argv is a list, no shell=True. Metacharacters are just bytes in an argument.
    out = subprocess.run(argv, capture_output=True, text=True, timeout=5)
    return out.stdout + out.stderr


def safe_path(name):
    # FIXED: resolve, then prove it is still inside DOCS_DIR.
    path = os.path.realpath(os.path.join(DOCS_DIR, name))
    if not path.startswith(DOCS_DIR + os.sep):
        raise ValueError("path escapes docs dir")
    return path


def read_doc(name):
    with open(safe_path(name)) as f:
        return f.read()

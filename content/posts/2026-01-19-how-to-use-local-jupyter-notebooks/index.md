---
title: "Running JupyterLab Locally on a MacBook Pro"
date: 2026-01-19
description: "A quick guide to running JupyterLab locally on M-series chips using uv, with tips for custom kernels and managing secrets."
summary: "Get JupyterLab running on your Mac in minutes with uv, custom project kernels, and handle secrets properly with dotenv."
tags:
- jupyter
- mac
- python
- uv
keywords:
- JupyterLab
- Jupyter Notebook
- Mac
- Apple Silicon
- M1
- M2
- M3
- M4
- ARM
- Python
- uv
- Astral
- Virtual Environment
- dotenv

draft: false

cover:
   # image: "img/jupyter-mac-local.png"
    #alt: "JupyterLab running on a Mac"
    #relative: true

slug: "jupyterlab-local-mac-apple-silicon"
---

A simple portable way to run Jupyter notebooks on my local machine with local data.

Enabling rapid prototyping that can be switched over to [Google Colab](https://colab.google) easily by saving and uploading my `.ipynb` files.

`jupyter-lab` is a binary that runs a local server that manages different python kernels for isolated UI-driven development.

## Install JupyterLab via UV

`uv` is an awesome package manager for python and it handles virtual environments too. [Install docs](https://docs.astral.sh/uv/getting-started/installation/). It can be thought of as a better `pip` with `venv`.

```bash
# This installs JupyterLab in an isolated environment and adds jupyter to your PATH (typically ~/.local/bin/).
uv tool install jupyterlab --with pip
```

> `--with pip` adds pip the the venv / kernel for use in the notebooks (otherwise not included).

## Launching

Create a notebooks directory and run:

```bash
mkdir -p ~/notebooks
cd ~/notebooks && jupyter-lab
```

JupyterLab auto-opens in your browser at `http://localhost:8888`.

## Custom Kernels for using different Python versions

In notebooks, your kernel uses a predefined python version. There are common situations where you want to run different python versions in different notebooks.

### Create a Project Kernel

```bash
mkdir -p ~/notebooks/py-3.13
cd ~/notebooks/py-3.13

# Install a specific Python if needed
uv python install 3.13

# Create venv with that Python (to use %pip install (Jupyter's built-in magic) we pass --seed)
uv venv --python 3.13 --seed

# Install ipykernel (uv auto-detects .venv)
uv pip install ipykernel

# Register as a Jupyter kernel
uv run python -m ipykernel install --user \
  --name python3.13 \
  --display-name "Python 3.13"
```

You can also add common / shared dependencies to this kernel / .venv:

```bash
uv pip install --python ~/notebooks/py-3.13/.venv pandas numpy requests
```

Now "Python 3.13" appears in JupyterLab's kernel picker.

## Managing Secrets with dotenv

Never hardcode API keys in notebooks. Use `python-dotenv` to load secrets from a `.env` file:

```bash
# In your project venv
%pip install python-dotenv
```

Create a `.env` file in your project directory:

```bash
# ~/notebooks/my-project/.env
API_KEY=...
DATABASE_URL=postgres://...
```

Load secrets in your notebook:

```python
from dotenv import load_dotenv
import os

load_dotenv()
api_key = os.getenv("API_KEY")
```

## Cleanup

To remove JupyterLab:

```bash
uv tool uninstall jupyterlab
```

Remove custom kernels:

```bash
jupyter kernelspec list
jupyter kernelspec remove <kernel-name>
```

## Wrapping Up

To upgrade, run `uv tool upgrade jupyterlab`. I've found the combination of a local notebook, with a lot of unified memory, to be very powerful.
# Python Package Management on macOS

## The Problem

On macOS it is common to have five or more Python installations at once,
installed by different tools at different times. When you type `pip install something`
and get `command not found`, or install a package and then find the command is still missing,
the root cause is always the same: you addressed the wrong Python.

---

## Key Concepts

### A Python package

Everything distributed via PyPI (the Python Package Index) is called a **package** —
whether it is a library you import in code (`requests`, `pydantic`) or a command-line
tool you run in a terminal (`piper`, `black`, `httpie`). The same `pip install` mechanism
installs both.

### pip is not a standalone tool

`pip` is a **module bundled inside a specific Python installation**, not an independent
program. When you have five Pythons you have five separate pips. Your shell's `PATH`
determines which one (if any) the bare name `pip` resolves to — and on macOS it often
resolves to nothing, because no installer bothered to create that alias.

The same applies to `pip3`: it may or may not exist depending on how Python was installed.

### The reliable command

Always address pip through an explicit Python interpreter:

```bash
python3 -m pip install <package>
```

This invokes pip *as a module of that exact `python3`*, so the installed package lands
in the right place. It works regardless of whether a `pip` or `pip3` alias exists.

To see which `python3` your shell resolves to:

```bash
which python3       # → /opt/homebrew/bin/python3
python3 --version   # → Python 3.13.x
```

---

## Where Pythons Come From on macOS

| Location | Source |
| --- | --- |
| `/opt/homebrew/bin/python3` | `brew install python` — or pulled in as a Homebrew dependency |
| `/usr/bin/python3` | Xcode Command Line Tools stub — minimal, managed by Apple |
| `~/.pyenv/versions/*/bin/python` | `pyenv` — explicit version manager |
| `/opt/miniconda3/bin/python` | Conda / Miniconda, if ever installed |
| `/Library/Frameworks/Python.framework/...` | python.org installer |

Every one of these has its own `site-packages` directory where installed packages land.
Installing into one Python does not make packages visible to any of the others.

---

## Two Installation Strategies

### Strategy 1 — `python3 -m pip` (for libraries)

Use this when you need a package importable in a Python script or project:

```bash
python3 -m pip install requests
```

The package lands in the `site-packages` of whichever `python3` is active.

**Limitation:** all packages installed this way share the same `site-packages`, so
version conflicts between projects are possible. For serious project work, use a
virtual environment (`python3 -m venv .venv && source .venv/bin/activate`) to isolate
each project's dependencies.

### Strategy 2 — `pipx` (for CLI tools)

Use this when you are installing a command-line tool, not a library.
`pipx` creates an isolated virtual environment per tool automatically,
installs the package into it, and exposes only the command on your `PATH`.

```bash
brew install pipx
pipx install <package>
```

Benefits:

- The tool is on your `PATH` immediately after install.
- Its dependencies never pollute any shared `site-packages`.
- No version conflicts between different CLI tools.
- `pipx list` shows everything installed this way.
- `pipx upgrade <package>` / `pipx uninstall <package>` for maintenance.

---

## Practical Example: piper-tts

`piper-tts` is a CLI tool for offline text-to-speech synthesis. Because it is a
command-line tool (not a library to import), `pipx` is the right choice:

```bash
brew install pipx
pipx install piper-tts
pipx ensurepath
```

`pipx ensurepath` adds `~/.local/bin` to your shell's `PATH` and writes the change to
`~/.zshrc`. Open a new terminal tab (or run `source ~/.zshrc`) after this step —
otherwise the `piper` command will not be found even though it is installed.

After that, the `piper` command is available system-wide.

Download voice models via curl — each voice needs an `.onnx` model file and an `.onnx.json`
config file. Do **not** use `python3 -m piper` for this: piper lives in pipx's isolated venv,
not in the system `python3`, so that command will fail with "No module named piper".

```bash
mkdir -p ~/Models/piper && cd ~/Models/piper

# Russian — Irina
curl -L -o ru_RU-irina-medium.onnx \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx"
curl -L -o ru_RU-irina-medium.onnx.json \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx.json"

# German — Thorsten emotional
curl -L -o de_DE-thorsten_emotional-medium.onnx \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/thorsten_emotional/medium/de_DE-thorsten_emotional-medium.onnx"
curl -L -o de_DE-thorsten_emotional-medium.onnx.json \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/thorsten_emotional/medium/de_DE-thorsten_emotional-medium.onnx.json"

# English — Bryce
curl -L -o en_US-bryce-medium.onnx \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/bryce/medium/en_US-bryce-medium.onnx"
curl -L -o en_US-bryce-medium.onnx.json \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/bryce/medium/en_US-bryce-medium.onnx.json"
```

The list of available voices can be found at the [Piper Voice site](https://rhasspy.github.io/piper-samples/).

Test a voice (macOS `afplay` plays WAV files):

```bash
echo "Здравствуйте" | piper \
  --model ~/Models/piper/ru_RU-irina-medium.onnx \
  --output_file /tmp/test.wav && afplay /tmp/test.wav
```

```bash
echo "Hello" | piper \
  --model ~/Models/piper/en_US-bryce-medium.onnx \
  --output_file /tmp/test.wav && afplay /tmp/test.wav
```

---

## Quick Diagnostic

When something is not found or behaves unexpectedly:

```bash
which python3           # which interpreter is active
python3 --version       # its version
python3 -m pip list     # packages visible to it
pipx list               # CLI tools installed via pipx
```

---

## Summary

| Situation | Command |
| --- | --- |
| Install a library for use in code | `python3 -m pip install <package>` |
| Install a CLI tool | `pipx install <package>` |
| Never rely on | bare `pip` or `pip3` |

# WissensNest — Voice Roadmap

## Vision

WissensNest should be reachable without a keyboard. A family member walks into the kitchen
and says *"What temperature for roasting chicken?"* — and hears the answer. The developer
asks about an STM32 register while soldering — hands too full to type. The same infrastructure
that runs the chat also runs the voice, and everything stays local.

![Home assistant vision](../../Images/22_01_WissensNest_Voice_HomeVision.svg)

Three zones connect over the local network:

| Zone | Hardware | Role |
| --- | --- | --- |
| **Voice nodes** | Raspberry Pi 5 + USB mic + speaker | Capture and play voice in the room |
| **Brain** | MacBook Pro M3 36 GB | All software: WissensNest, Ollama, Whisper, Piper |
| **Smart home** | Zigbee / Wi-Fi devices via Home Assistant | Devices the model can control |

A phone or browser can also reach the Blazor UI directly for typed chat.

---

## Shared Audio Services (implemented — Whisper STT and Piper TTS both running)

Both services run as long-lived HTTP servers on the MacBook.

### Whisper.cpp — Speech-to-Text (port 9000)

Install Whisper.cpp

```bash
brew install whisper-cpp
```

Prepare model directory

```bash
mkdir -p ~/Models
```

Download model

```bash
# Recommended: large-v3 (~3.1 GB, best multilingual accuracy for RU/DE/EN)
curl -L -o ~/Models/ggml-large-v3.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"

# Alternative: base (~150 MB, faster but unreliable for non-English)
curl -L -o ~/Models/ggml-base.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
```

`--language auto` is required for multilingual use — without it the server defaults to English
and will transliterate or mistranscribe Russian and German speech.

Start the server

```bash
whisper-server --model ~/Models/ggml-large-v3.bin --host 0.0.0.0 --port 9000 --language auto
```

Exposes `POST /inference` — send a WAV file as `multipart/form-data`, receive JSON with a `text` field.

`prod-execute.sh` supports a `--voice` flag that starts whisper-server automatically alongside
the API and UI and stops it cleanly on Ctrl+C:

```bash
./CICD/prod-run-osx.sh --voice
```

Check if it works by the following command

```bash
curl -s http://localhost:9000/inference \
  -F file="@$(find "$(brew --cellar)/whisper-cpp" -name "jfk.wav" | head -1)" \
  -F response_format=json
```

### Piper TTS — Text-to-Speech (port 5002)

Install via `pipx` (not `pip`) — it creates an isolated environment and puts the `piper`
command on your `PATH` without polluting any shared Python:

```bash
brew install pipx
pipx install piper-tts
pipx ensurepath   # adds ~/.local/bin to PATH; open a new terminal tab after this
```

Download voice models via curl — each voice needs an `.onnx` file and an `.onnx.json` config:

```bash
mkdir -p ~/Models/piper && cd ~/Models/piper

curl -L -o ru_RU-irina-medium.onnx \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx"
curl -L -o ru_RU-irina-medium.onnx.json \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx.json"

curl -L -o de_DE-thorsten_emotional-medium.onnx \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/thorsten_emotional/medium/de_DE-thorsten_emotional-medium.onnx"
curl -L -o de_DE-thorsten_emotional-medium.onnx.json \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/thorsten_emotional/medium/de_DE-thorsten_emotional-medium.onnx.json"

curl -L -o en_US-bryce-medium.onnx \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/bryce/medium/en_US-bryce-medium.onnx"
curl -L -o en_US-bryce-medium.onnx.json \
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/bryce/medium/en_US-bryce-medium.onnx.json"
```

The list of available voices can be found at the [Piper Voice site](https://rhasspy.github.io/piper-samples/).

Validate with a spoken test (macOS `afplay` plays WAV files):

```bash
echo "Здравствуйте" | piper \
  --model ~/Models/piper/ru_RU-irina-medium.onnx \
  --output_file /tmp/test.wav && afplay /tmp/test.wav
```

The FastAPI wrapper `CICD/piper-server.py` (implemented in Stage 5.2) exposes three endpoints
on port 5002: `GET /voices` (list of installed models), `POST /api/tts` (synthesize), and
`GET /health`. Start it with `python3 CICD/piper-server.py`. The `--voice` flag in
`prod-execute.sh` starts both whisper-server and piper-server.py automatically.

---

## Three Integration Approaches

![Voice architecture](../../Images/22_02_WissensNest_Voice_Architecture.svg)

### Approach A — Voice in the Blazor UI ✅ Implemented (Stage 5.3)

A mic toggle and speaker toggle in `Chat.razor`. The user clicks the mic to record; audio
flows via `IJSStreamReference` to a circuit-scoped `VoiceService`; the transcript fills the
chat input; after each assistant response the TTS path synthesizes via Piper and plays back
through the browser's `AudioContext`.

**Key files:**

- `wwwroot/js/voice.js` — `MediaRecorder` start/stop; audio returned as a `Blob` via
  `IJSStreamReference` (bypasses Blazor's 32 KB SignalR message limit); `AudioContext` WAV
  playback; `cleanupRecorder()` called on every `startRecording` to recover from crashed circuits.
- `WissensNest.UI/Services/VoiceService.cs` — circuit-scoped; three JS-interop methods
  (`StartRecordingAsync`, `StopRecordingAsync → byte[]`, `PlayAudioAsync`) and one thread-pool
  method (`ProcessAudioAsync(byte[], string? language = null)` — ffmpeg + Whisper, called via
  `Task.Run` to avoid holding the Blazor circuit lock while processing).
- `WissensNest.UI/Services/AudioConverter.cs` — static; writes temp file, runs
  `ffmpeg -ar 16000 -ac 1 -f wav`, reads result, deletes temps.
- `CICD/piper-server.py` — updated to resolve the `piper` binary via `shutil.which` with a
  fallback to `~/.local/bin/piper` (pipx installs it there but does not add it to the
  process PATH automatically).

The mic button cycles through four visual states: idle (purple), recording (red pulse),
transcribing (amber), and error (red with tooltip). The TTS speaker toggle shows a red
tapered slash — thin-to-wide like a blade — across the icon when TTS is off, and a filled
active style when on. A compact STT language selector (Auto / RU / DE / EN) sits below the
TTS button; `Auto` lets Whisper detect the language, while explicit selection avoids
misdetection when speaking a non-native language with a foreign accent.

**Key constraint:** `MediaRecorder` requires HTTPS or `localhost`. For LAN access from a
phone the UI must be served over HTTPS (e.g. Caddy with a self-signed cert).
WebM/Opus → WAV conversion via `ffmpeg` (Homebrew).

### Approach B — `WissensNest.VoiceClient` Console App

A standalone .NET console application that runs on the MacBook (and later on a Raspberry Pi).
NAudio captures microphone input with silence-triggered VAD (voice activity detection).
The loop is: record until silence → `ISttService.TranscribeAsync` → `IWissensNestClient.StreamChatAsync`
→ `ITtsService.SynthesizeAsync` → play audio.

Assembly: `Src/Clients/WissensNest.VoiceClient` — references `WissensNest.Voice`,
`WissensNest.Client`, `WissensNest.Contracts`.

### Approach C — Always-On Wake Word (Raspberry Pi)

Extends Approach B with an `openWakeWord` Python sidecar running on the RPi.
The sidecar streams audio chunks and fires an HTTP event on wake-word detection.
`WakeWordDetector` in `VoiceClient` polls the sidecar and triggers the record loop on detection.
Run as a `systemd` service on the RPi for always-on operation.

---

## Shared Foundation: `WissensNest.Voice` ✅ Implemented

`Src/Foundation/WissensNest.Voice` — implemented in Stage 5.2. Both Approach A and Approach B inject it.

```csharp
ISttService  — Task<string> TranscribeAsync(byte[] audioWav, string? language = null, CancellationToken)
ITtsService  — Task<byte[]> SynthesizeAsync(string text, string? voice, CancellationToken)
```

Implementations: `WhisperSttService` (HTTP to port 9000), `PiperTtsService` (HTTP to port 5002).
`ServiceCollectionExtensions.AddVoice(config)` registers both + named HTTP clients.
Swapping the backend (e.g. Kokoro TTS) requires changing one registration line.

`CICD/piper-server.py` — FastAPI wrapper for Piper; exposes `POST /api/tts` and `GET /health`;
voices resolved from `~/Models/piper/`; configurable via env vars.

---

## Home Control Integration

A `WissensNest.Tools.HomeControl` assembly will add a `home_control` tool:

- **Action parameters:** `turn_on`, `turn_off`, `toggle`, `set_brightness`, `set_temperature`
- **Entity parameter:** Home Assistant entity ID (e.g. `light.living_room_lamp`)
- Calls `POST /api/services/{domain}/{service}` on Home Assistant with a Bearer token

Once voice is working end-to-end, *"turn on the living room lamp"* spoken aloud becomes a
Home Assistant state change with no keyboard involved.

---

## Stage Plan

| Stage | Deliverable | Status |
| --- | --- | --- |
| **5.1** | Audio services running on MacBook; validated with `curl` | ✅ Done |
| **5.2** | `WissensNest.Voice` assembly — `ISttService`, `ITtsService`, HTTP implementations; `piper-server.py` | ✅ Done |
| **5.3** | Approach A: mic toggle in Blazor UI; transcript → chat input; TTS playback | ✅ Done |
| **5.4** | Approach B: `WissensNest.VoiceClient` console app; NAudio VAD loop; runs on MacBook | Planned |
| **5.5** | Approach C: wake word on RPi; `openWakeWord` sidecar; `systemd` service | Planned |
| **5.6** | `WissensNest.Tools.HomeControl`; validated via voice end-to-end | Planned |

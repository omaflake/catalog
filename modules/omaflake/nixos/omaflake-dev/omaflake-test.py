"""omaflake Test – checks the Mac integrations from inside a NixOS guest (lab recipe).

Camera: shows /dev/video42 ("Mac Camera") in mpv; the Mac's camera runs only while the window is open.
Sound: plays a short test tone through the default output (the Mac's speakers).
Microphone: records a few seconds from the default input, shows the peak level and plays it back.
Status: what the omaflake agent has on for this VM, PipeWire outputs/inputs.
"""

import json
import math
import os
import struct
import subprocess
import tempfile
import threading
import wave

import gi

gi.require_version("Gtk", "4.0")
from gi.repository import GLib, Gtk  # noqa: E402

CAMERA = "/dev/video42"
WELCOME = "/run/omaflake-agent/welcome.json"  # what the Mac enabled for this VM (omaflake agent)
RATE = 48000
RECORD_SECONDS = 4


def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def tone_file():
    path = os.path.join(tempfile.gettempdir(), "omaflake-test-tone.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for i in range(RATE):  # 1 s, 440 Hz then 880 Hz, faded in and out
            f = 440 if i < RATE // 2 else 880
            fade = min(1.0, i / 2400, (RATE - i) / 2400)
            frames += struct.pack("<h", int(0.4 * fade * 32767 * math.sin(2 * math.pi * f * i / RATE)))
        w.writeframes(bytes(frames))
    return path


def peak(path):
    with wave.open(path, "rb") as w:
        data = w.readframes(w.getnframes())
        width = w.getsampwidth()
    if width != 2 or not data:
        return 0.0
    samples = struct.unpack(f"<{len(data) // 2}h", data)
    return max(abs(s) for s in samples) / 32768


class TestWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="omaflake Test")
        self.set_default_size(460, 420)
        self.camera = None

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        for side in ("top", "bottom", "start", "end"):
            getattr(box, f"set_margin_{side}")(18)
        self.set_child(box)

        self.status = Gtk.Label(xalign=0)
        self.status.add_css_class("dim-label")
        box.append(self.section("Status", self.status, "Refresh", self.refresh))

        self.cam_label = Gtk.Label(label="Opens the Mac's camera in mpv. Close the window to turn it off.", xalign=0, wrap=True)
        self.cam_button = Gtk.Button(label="Show Camera")
        self.cam_button.connect("clicked", self.toggle_camera)
        box.append(self.section("Camera", self.cam_label, button=self.cam_button))

        self.sound_label = Gtk.Label(label="Plays a short two-tone sound on the Mac's speakers.", xalign=0, wrap=True)
        box.append(self.section("Sound", self.sound_label, "Play Tone", self.play_tone))

        self.mic_label = Gtk.Label(label=f"Records {RECORD_SECONDS} s, shows the level and plays it back.", xalign=0, wrap=True)
        self.level = Gtk.LevelBar(min_value=0, max_value=1)
        mic = self.section("Microphone", self.mic_label, "Record", self.record)
        mic.append(self.level)
        box.append(mic)

        self.refresh()

    def section(self, title, body, label=None, action=None, button=None):
        frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        head = Gtk.Box(spacing=8)
        heading = Gtk.Label(label=title, xalign=0, hexpand=True)
        heading.add_css_class("heading")
        head.append(heading)
        if button is None and label:
            button = Gtk.Button(label=label)
            button.connect("clicked", lambda _b: action())
        if button:
            head.append(button)
        frame.append(head)
        frame.append(body)
        return frame

    def set_text(self, label, text):
        GLib.idle_add(label.set_text, text)

    # Status

    @staticmethod
    def features():
        try:
            with open(WELCOME) as f:
                return json.load(f).get("features", [])
        except (OSError, ValueError):
            return []

    def refresh(self):
        sinks = [l for l in run(["pactl", "list", "short", "sinks"]).splitlines() if l.strip()]
        sources = [l for l in run(["pactl", "list", "short", "sources"]).splitlines() if l.strip() and ".monitor" not in l]
        agent = run(["systemctl", "is-active", "omaflake-agent"]).strip() or "?"
        session = run(["systemctl", "--user", "is-active", "omaflake-agent-session"]).strip() or "?"
        features = self.features()
        lines = [
            f"omaflake agent: {agent}, session part: {session}",
            f"On for this VM: {', '.join(features) if features else 'nothing yet (no welcome from the Mac)'}",
            f"Camera: {'on' if 'camera' in features else 'off for this VM'}",
            f"Sound outputs: {len(sinks)}, microphone inputs: {len(sources)}",
        ]
        self.status.set_text("\n".join(lines))

    # Camera

    def toggle_camera(self, _button):
        if self.camera and self.camera.poll() is None:
            self.camera.terminate()
            return
        if "camera" not in self.features():
            self.cam_label.set_text("No camera device – switch the camera on for this VM (omaflake app or omaf set --camera).")
            return
        self.camera = subprocess.Popen(["mpv", "--title=omaflake Test – Camera", "--profile=low-latency", f"av://v4l2:{CAMERA}"])
        self.cam_button.set_label("Hide Camera")
        self.cam_label.set_text("Camera window open – the Mac's camera light is on.")
        threading.Thread(target=self.wait_camera, daemon=True).start()

    def wait_camera(self):
        self.camera.wait()
        GLib.idle_add(self.cam_button.set_label, "Show Camera")
        self.set_text(self.cam_label, "Camera closed – the Mac's camera light goes off.")

    # Sound

    def play_tone(self):
        def work():
            self.set_text(self.sound_label, "Playing …")
            r = subprocess.run(["pw-play", tone_file()], capture_output=True, text=True)
            self.set_text(self.sound_label, "Played. Heard two tones?" if r.returncode == 0 else f"Failed: {r.stderr.strip()}")
        threading.Thread(target=work, daemon=True).start()

    # Microphone

    def record(self):
        def work():
            path = os.path.join(tempfile.gettempdir(), "omaflake-test-mic.wav")
            self.set_text(self.mic_label, f"Recording {RECORD_SECONDS} s – say something …")
            p = subprocess.Popen(["pw-record", "--rate", str(RATE), "--channels", "1", "--format", "s16", path],
                                 stderr=subprocess.PIPE, text=True)
            try:
                p.wait(timeout=RECORD_SECONDS)
            except subprocess.TimeoutExpired:
                p.terminate()
                p.wait()
            try:
                level = peak(path)
            except (OSError, wave.Error, EOFError) as e:
                self.set_text(self.mic_label, f"Recording failed: {e}")
                return
            GLib.idle_add(self.level.set_value, level)
            if level < 0.01:
                self.set_text(self.mic_label, "Silence – is the microphone switched on for this VM, and allowed on the Mac?")
                return
            self.set_text(self.mic_label, f"Peak {level:.0%} – playing it back …")
            subprocess.run(["pw-play", path], capture_output=True)
            self.set_text(self.mic_label, f"Peak {level:.0%} – played back.")
        threading.Thread(target=work, daemon=True).start()


class TestApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.omaflake.Test")

    def do_activate(self):
        (self.props.active_window or TestWindow(self)).present()


if __name__ == "__main__":
    TestApp().run(None)

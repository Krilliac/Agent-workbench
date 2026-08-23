#!/usr/bin/env python3
"""Capture a screenshot of the whole screen or a single window (Windows).

Registry entry: see ~/.claude/scripts/README.md

Usage:
  python screenshot.py out.png                       # full virtual screen
  python screenshot.py out.png --title "Application" # first matching window title
  python screenshot.py out.png --title "x" --raise    # foreground it first, then capture
  python screenshot.py --list                         # list visible top-level window titles

Notes:
  * Uses PIL ImageGrab (all_screens=True) so multi-monitor setups work.
  * Calls SetProcessDpiAwareness so window rects match physical pixels on
    scaled displays; without it a 150% display returns logical coords and the
    crop lands in the wrong place.
  * --raise uses SetForegroundWindow, which Windows may refuse if the calling
    process does not own the foreground. The capture still happens; it may
    just catch an occluded window. Prefer launching the target yourself and
    giving it a moment to paint.
"""
from __future__ import annotations

import argparse
import ctypes
import sys
import time

try:
    from PIL import ImageGrab
except ImportError:  # pragma: no cover - environment guard
    sys.exit("screenshot.py requires Pillow: python -m pip install pillow")

# Window titles routinely carry emoji and box-drawing glyphs; the default
# cp1252 console encoding raises UnicodeEncodeError on them mid-listing.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

user32 = ctypes.windll.user32


def _set_dpi_aware() -> None:
    """Match window rects to physical pixels on scaled displays."""
    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(2)  # PROCESS_PER_MONITOR_DPI_AWARE
    except (AttributeError, OSError):
        try:
            user32.SetProcessDPIAware()
        except (AttributeError, OSError):
            pass


class _Rect(ctypes.Structure):
    _fields_ = [
        ("left", ctypes.c_long), ("top", ctypes.c_long),
        ("right", ctypes.c_long), ("bottom", ctypes.c_long),
    ]


def visible_windows() -> list[tuple[int, str]]:
    """Every visible top-level window that has a non-empty title."""
    found: list[tuple[int, str]] = []
    proto = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_int, ctypes.POINTER(ctypes.c_int))

    def _cb(hwnd, _lparam):
        if not user32.IsWindowVisible(hwnd):
            return True
        length = user32.GetWindowTextLengthW(hwnd)
        if length <= 0:
            return True
        buf = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buf, length + 1)
        if buf.value.strip():
            found.append((hwnd, buf.value))
        return True

    user32.EnumWindows(proto(_cb), None)
    return found


def find_window(title_substring: str) -> tuple[int, str] | None:
    needle = title_substring.lower()
    for hwnd, title in visible_windows():
        if needle in title.lower():
            return hwnd, title
    return None


def window_bbox(hwnd: int) -> tuple[int, int, int, int]:
    """Physical-pixel bbox, preferring the DWM frame over the legacy rect.

    GetWindowRect includes the invisible resize border on Windows 10/11, which
    shows up as a dead margin around the capture. DWMWA_EXTENDED_FRAME_BOUNDS
    is what the compositor actually draws.
    """
    rect = _Rect()
    try:
        hresult = ctypes.windll.dwmapi.DwmGetWindowAttribute(
            ctypes.c_void_p(hwnd),
            ctypes.c_uint(9),  # DWMWA_EXTENDED_FRAME_BOUNDS
            ctypes.byref(rect),
            ctypes.sizeof(rect),
        )
        if hresult != 0:
            raise OSError(hresult)
    except (AttributeError, OSError):
        user32.GetWindowRect(hwnd, ctypes.byref(rect))
    return rect.left, rect.top, rect.right, rect.bottom


def capture(out_path: str, title: str = "", do_raise: bool = False,
            delay: float = 0.0) -> str:
    _set_dpi_aware()
    bbox = None
    label = "full screen"
    if title:
        hit = find_window(title)
        if not hit:
            titles = "\n  ".join(t for _, t in visible_windows()) or "(none)"
            sys.exit("no visible window matching %r. Open windows:\n  %s"
                     % (title, titles))
        hwnd, matched = hit
        label = matched
        if do_raise:
            user32.ShowWindow(hwnd, 9)  # SW_RESTORE
            user32.SetForegroundWindow(hwnd)
            time.sleep(max(delay, 0.35))
        elif delay:
            time.sleep(delay)
        bbox = window_bbox(hwnd)
    elif delay:
        time.sleep(delay)

    image = ImageGrab.grab(bbox=bbox, all_screens=True)
    image.save(out_path)
    print("captured %s -> %s (%dx%d)" % (label, out_path, image.width, image.height))
    return out_path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("out", nargs="?", help="output .png path")
    parser.add_argument("--title", default="", help="capture window whose title contains this")
    parser.add_argument("--raise", dest="do_raise", action="store_true",
                        help="bring the window to the foreground first")
    parser.add_argument("--delay", type=float, default=0.0,
                        help="seconds to wait before capturing")
    parser.add_argument("--list", action="store_true", help="list visible window titles and exit")
    args = parser.parse_args()

    if args.list:
        _set_dpi_aware()
        for hwnd, title in visible_windows():
            print("%10d  %s" % (hwnd, title))
        return

    if not args.out:
        parser.error("out path is required unless --list is given")
    capture(args.out, args.title, args.do_raise, args.delay)


if __name__ == "__main__":
    main()

"""Run the desktop rules adapter inside Android's embedded CPython."""
from pathlib import Path
import threading
import traceback

_worker = None
_cancel = None


def stop():
    global _worker, _cancel
    if _cancel is not None:
        _cancel.set()
    if _worker is not None:
        _worker.join(timeout=2)
    _worker = _cancel = None


def start(endpoint):
    global _worker, _cancel
    stop()
    destination = Path(endpoint)
    _cancel = threading.Event()
    cancel = _cancel

    def run():
        try:
            from local_bridge import serve
            serve(destination, cancel)
        except Exception:
            destination.with_suffix('.error').write_text(traceback.format_exc(), encoding='utf-8')

    _worker = threading.Thread(target=run, name='GuildOffline', daemon=True)
    _worker.start()

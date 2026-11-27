"""macOS Messages integration for kvpn.

Uses the private Messages database read-only. Imported only when automatic SMS
entry is enabled on macOS; callers fall back to manual input on failure.
"""

import re
import sqlite3
import time
from pathlib import Path

SMS_CODE = re.compile(rb"KVPN\s+OTP\s+number\s*:\s*\[([0-9]{6})\]", re.I)
APPLE_EPOCH = 978307200


def extract_sms_code(text, attributed_body):
    """Best-effort extraction, including ASCII text in Messages' typedstream."""
    for value in (text, attributed_body):
        if isinstance(value, str):
            value = value.encode("utf-8")
        if isinstance(value, bytes):
            match = SMS_CODE.search(value)
            if match:
                return match.group(1).decode("ascii")
    return None


class MessagesCodeReader:
    """Read only newly received Messages rows; never modify the database."""

    def __init__(self, path=None):
        path = Path(path) if path is not None else Path.home() / "Library/Messages/chat.db"
        self.conn = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True, timeout=1)
        try:
            self.baseline = self.conn.execute(
                "SELECT COALESCE(MAX(ROWID), 0) FROM message"
            ).fetchone()[0]
            self.started_at = time.time() - APPLE_EPOCH
        except BaseException:
            self.close()
            raise

    def close(self):
        self.conn.close()

    def wait(self, timeout=60):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            rows = self.conn.execute(
                "SELECT text, attributedBody, date FROM message "
                "WHERE ROWID > ? AND is_from_me = 0 ORDER BY ROWID DESC",
                (self.baseline,),
            ).fetchall()
            for text, body, date in rows:
                if date is None:
                    continue
                # Modern macOS uses nanoseconds; older databases use seconds.
                nanoseconds = date > 100_000_000_000
                received_at = date / 1_000_000_000 if nanoseconds else date
                cutoff = self.started_at if nanoseconds else int(self.started_at)
                if received_at < cutoff:
                    continue
                code = extract_sms_code(text, body)
                if code:
                    return code
            # Keep the original baseline: Messages may populate a row's body later.
            time.sleep(min(1, max(0, deadline - time.monotonic())))
        return None


def _explain_messages_access():
    print("Cannot access Messages for automatic SMS entry.")
    print("  Open System Settings > Privacy & Security > Full Disk Access.")
    print("  Allow the app running kvpn (Terminal, iTerm2, Emacs, etc.), then quit and reopen it.")
    print("  Also check that your iPhone's KVPN texts appear in Mac Messages.")
    print("Continuing with manual code entry. Use --no-auto-sms for manual SMS or email authentication.")


def receive_sms_code(send_sms):
    """Snapshot Messages, invoke send_sms once, then wait for the new OTP.

    Return None for unavailable Messages access or timeout. Sending errors and
    KeyboardInterrupt propagate, with the database connection always closed.
    """
    reader = None
    try:
        reader = MessagesCodeReader()
    except (OSError, sqlite3.Error):
        _explain_messages_access()

    try:
        send_sms()
        print("Code sent via SMS. It may take up to a minute to arrive.")
        if reader is None:
            return None
        print("Waiting up to 60 seconds for a KVPN SMS in Messages...")
        try:
            otp = reader.wait()
        except sqlite3.Error:
            _explain_messages_access()
            return None
        if otp:
            print("KVPN SMS code received; continuing authentication.")
        else:
            print("No new KVPN SMS found; enter the code manually.")
        return otp
    finally:
        if reader is not None:
            reader.close()

import importlib.util
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "tools", "test", "check_log.py")
spec = importlib.util.spec_from_file_location("check_log", SOURCE)
check_log = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check_log)


def problems(lines):
    errors = []
    for n, line in enumerate(lines, 1):
        match = check_log.LINE.match(line)
        if not match:
            errors.append(f"{n}: bad format {line!r}")
            continue
        direction, *_, ident, seq, ack, flags, win, length, mss = match.groups()
        flags = int(flags, 16)
        if direction == "SEND":
            if int(ident) == 0:
                errors.append(f"{n}: id=0")
            if flags & 0x02 and mss != "1460":
                errors.append(f"{n}: SYN without mss=1460")
            if not flags & 0x02 and mss != "-":
                errors.append(f"{n}: MSS on non-SYN")
            if int(win) != 65535:
                errors.append(f"{n}: window {win}")
            if int(length) > 1460:
                errors.append(f"{n}: len {length}")
    return errors

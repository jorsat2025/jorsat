#!/usr/bin/env python3
import json
import time
from pathlib import Path
from datetime import datetime, timezone

EVE = Path("/opt/suricata/var/log/suricata/eve.json")
EBPF = Path("/tmp/ebpf-squid.log")

WINDOW_SECONDS = 3


def parse_suricata_ts(ts: str) -> float:
    # Ej: 2026-05-20T12:30:10.123456-0300
    ts = ts.replace("+0000", "+00:00")
    if len(ts) > 5 and (ts[-5] in ["+", "-"]) and ts[-3] != ":":
        ts = ts[:-2] + ":" + ts[-2:]
    return datetime.fromisoformat(ts).timestamp()


def follow(path: Path):
    with path.open("r", errors="ignore") as f:
        f.seek(0, 2)
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.2)
                continue
            yield line.strip()


recent_ebpf = []

print("[+] Correlando Suricata eve.json con eBPF Squid log...")

for line in follow(EVE):
    try:
        event = json.loads(line)
    except Exception:
        continue

    if event.get("event_type") != "alert":
        continue

    ts = parse_suricata_ts(event["timestamp"])
    alert = event.get("alert", {})

    sid = alert.get("signature_id")
    sig = alert.get("signature")
    severity = alert.get("severity")

    src_ip = event.get("src_ip")
    src_port = event.get("src_port")
    dest_ip = event.get("dest_ip")
    dest_port = event.get("dest_port")
    proto = event.get("proto")
    flow_id = event.get("flow_id")

    print("\n=== SURICATA ALERT ===")
    print(f"time={event.get('timestamp')}")
    print(f"sid={sid} severity={severity}")
    print(f"signature={sig}")
    print(f"flow_id={flow_id}")
    print(f"{src_ip}:{src_port} -> {dest_ip}:{dest_port} proto={proto}")

    print("possible_os_context=mirar eventos eBPF cercanos en /tmp/ebpf-squid.log")
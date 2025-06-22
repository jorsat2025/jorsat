import psycopg2
import json
import time
import os
import re
from datetime import datetime
import pytz

DB_CONFIG = {
    'host': '10.10.10.6',
    'port': '5432',
    'dbname': 'suricata',
    'user': 'suriuser',
    'password': 'murdok45'
}

EVE_JSON_PATHS = [
    "/opt/suricata/var/log/suricata/eve.json",
    "/opt/suricata/var/log/suricata/eve-q1.json"
]

FAST_LOG_PATHS = [
    "/opt/suricata/var/log/suricata/fast.log",
    "/opt/suricata/var/log/suricata/fast-log-q1.log"
]

TZ = pytz.timezone('America/Argentina/Buenos_Aires')

last_inserted = {
    "alerts": {},  # Por archivo
    "drops": {}
}

def parse_fast_line(line):
    try:
        if '[Drop]' not in line:
            return None

        match = re.search(r"\\[(\\d+):(\\d+):(\\d+)\\] (.*?) \\\*\\\*\\\].*?\\{(\\w+)\\} ([\\d.]+):(\\d+) -> ([\\d.]+):(\\d+)", line)
        if not match:
            return None

        parts = line.split("  ")
        timestamp_naive = datetime.strptime(parts[0], "%m/%d/%Y-%H:%M:%S.%f")
        timestamp = TZ.localize(timestamp_naive)

        return {
            'timestamp': timestamp,
            'src_ip': match.group(6),
            'src_port': int(match.group(7)),
            'dest_ip': match.group(8),
            'dest_port': int(match.group(9)),
            'protocol': match.group(5),
            'drop_reason': match.group(4).strip()
        }
    except Exception as e:
        print(f"[!] Error al parsear línea fast.log: {e}")
        return None

def insert_drops(conn):
    for path in FAST_LOG_PATHS:
        if not os.path.exists(path):
            continue
        with open(path, "r") as f:
            for line in f:
                drop = parse_fast_line(line)
                if not drop:
                    continue
                if last_inserted["drops"].get(path) and drop['timestamp'] <= last_inserted["drops"][path]:
                    continue

                with conn.cursor() as cur:
                    cur.execute("""
                        INSERT INTO drops (timestamp, src_ip, src_port, dest_ip, dest_port, protocol, drop_reason)
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """, (
                        drop['timestamp'], drop['src_ip'], drop['src_port'],
                        drop['dest_ip'], drop['dest_port'], drop['protocol'],
                        drop['drop_reason']
                    ))
                    print(f"[+] Drop insertado desde {os.path.basename(path)}: {drop['src_ip']} -> {drop['dest_ip']} {drop['drop_reason']}")
                    last_inserted["drops"][path] = drop['timestamp']
        conn.commit()

def insert_alerts(conn):
    for path in EVE_JSON_PATHS:
        if not os.path.exists(path):
            continue
        with open(path, 'r') as f:
            for line in f:
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue

                if event.get("event_type") != "alert":
                    continue

                timestamp_utc = datetime.strptime(event["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
                timestamp = timestamp_utc.astimezone(TZ)

                if last_inserted["alerts"].get(path) and timestamp <= last_inserted["alerts"][path]:
                    continue

                src_ip = event.get("src_ip")
                dst_ip = event.get("dest_ip")
                src_port = event.get("src_port")
                dst_port = event.get("dest_port")
                proto = event.get("proto")
                alert = event.get("alert", {})
                signature = alert.get("signature")
                category = alert.get("category")
                severity = alert.get("severity")

                with conn.cursor() as cur:
                    cur.execute("""
                        INSERT INTO alerts (timestamp, src_ip, src_port, dest_ip, dest_port, protocol, alert_signature, alert_category, alert_severity)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        timestamp, src_ip, src_port, dst_ip, dst_port,
                        proto, signature, category, severity
                    ))
                    print(f"[+] Alerta insertada desde {os.path.basename(path)}: {src_ip} -> {dst_ip} {signature}")
                    last_inserted["alerts"][path] = timestamp
        conn.commit()

def main():
    print("[🚀] Insertando alertas y drops de Suricata (q0 + q1) en PostgreSQL...")
    while True:
        try:
            with psycopg2.connect(**DB_CONFIG) as conn:
                insert_alerts(conn)
                insert_drops(conn)
        except Exception as e:
            print(f"[!] Error en la conexión o inserción: {e}")
        time.sleep(10)

if __name__ == "__main__":
    main()

import psycopg2
import json
import time
from datetime import datetime
import re

DB_CONFIG = {
    'host': '10.10.10.6',
    'port': '5432',
    'dbname': 'suricata',
    'user': 'suriuser',
    'password': 'murdok45'
}

EVE_JSON_PATH = "/opt/suricata/var/log/suricata/eve.json"
FAST_LOG_PATH = "/opt/suricata/var/log/suricata/fast.log"

last_inserted = {
    "alerts": None,
    "drops": None
}

def parse_fast_line(line):
    try:
        if '[Drop]' not in line:
            return None

        match = re.search(r"\[(\d+):(\d+):(\d+)\] (.*?) \[\*\*\].*?\{(\w+)\} ([\d.]+):(\d+) -> ([\d.]+):(\d+)", line)
        if not match:
            return None

        parts = line.split("  ")
        timestamp = datetime.strptime(parts[0], "%m/%d/%Y-%H:%M:%S.%f")
        sid, rev, gid = match.group(1), match.group(2), match.group(3)
        signature = match.group(4).strip()
        protocol = match.group(5).strip()
        src_ip, src_port = match.group(6), int(match.group(7))
        dst_ip, dst_port = match.group(8), int(match.group(9))

        return {
            'timestamp': timestamp,
            'src_ip': src_ip,
            'src_port': src_port,
            'dest_ip': dst_ip,
            'dest_port': dst_port,
            'protocol': protocol,
            'drop_reason': signature
        }
    except Exception as e:
        print(f"[!] Error al parsear línea fast.log: {e}")
        return None

def insert_drops(conn):
    with open(FAST_LOG_PATH, "r") as f:
        for line in f:
            drop = parse_fast_line(line)
            if not drop:
                continue

            if last_inserted["drops"] and drop['timestamp'] <= last_inserted["drops"]:
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
                print(f"[+] Drop insertado: {drop['src_ip']} -> {drop['dest_ip']} {drop['drop_reason']}")
                last_inserted["drops"] = drop['timestamp']

    conn.commit()

def insert_alerts(conn):
    with open(EVE_JSON_PATH, 'r') as f:
        for line in f:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            if event.get("event_type") != "alert":
                continue

            timestamp = datetime.strptime(event["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
            if last_inserted["alerts"] and timestamp <= last_inserted["alerts"]:
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
                print(f"[+] Alerta insertada: {src_ip} -> {dst_ip} {signature}")
                last_inserted["alerts"] = timestamp

    conn.commit()

def main():
    print("[🚀] Insertando alertas y drops de Suricata en PostgreSQL...")
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

from flask import Flask, render_template, jsonify
from flask_cors import CORS
import psycopg2
import psycopg2.extras
from collections import Counter
import geoip2.database
import os

app = Flask(__name__)
CORS(app)

DB_CONFIG = {
    'host': '10.10.10.6',
    'port': '5432',
    'dbname': 'suricata',
    'user': 'suriuser',
    'password': 'murdok45'
}

GEOIP_DB_PATH = "/opt/geoip/GeoLite2-City.mmdb"
PRIVATE_IP_PREFIXES = [
    '10.', '172.16.', '172.17.', '172.18.', '172.19.', '172.20.', '172.21.', '172.22.', '172.23.',
    '172.24.', '172.25.', '172.26.', '172.27.', '172.28.', '172.29.', '172.30.', '172.31.', '192.168.', '127.'
]

def is_private_ip(ip):
    return any(ip.startswith(prefix) for prefix in PRIVATE_IP_PREFIXES)

def query_db(query):
    with psycopg2.connect(**DB_CONFIG) as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute(query)
            return cur.fetchall()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/mapa.html')
def mapa():
    return render_template('mapa.html')

@app.route('/alerts')
def get_alerts():
    query = """
        SELECT alert_signature AS valor, COUNT(*) AS cantidad
        FROM suri_schema.alerts
        GROUP BY alert_signature
        ORDER BY cantidad DESC
        LIMIT 20
    """
    results = query_db(query)
    enriched = [{"valor": row["valor"], "cantidad": row["cantidad"], "estado": "bloqueado"} for row in results]
    return jsonify(enriched)

@app.route('/drops')
def get_drops():
    query = """
        SELECT drop_reason AS valor, COUNT(*) AS cantidad
        FROM suri_schema.drops
        GROUP BY drop_reason
        ORDER BY cantidad DESC
        LIMIT 20
    """
    drops_data = query_db(query)
    enriched = [{"valor": row["valor"] or "desconocido", "cantidad": row["cantidad"], "estado": "bloqueado"} for row in drops_data]
    return jsonify(enriched)

@app.route('/dns')
def get_dns():
    query = """
        SELECT query AS valor, COUNT(*) as cantidad
        FROM suri_schema.dns_events
        GROUP BY query
        ORDER BY cantidad DESC
        LIMIT 20
    """
    dns_data = query_db(query)
    drop_domains = query_db("SELECT DISTINCT dest_ip FROM suri_schema.drops")
    drop_ips = set([row["dest_ip"] for row in drop_domains])

    enriched = []
    for row in dns_data:
        estado = "bloqueado" if row["valor"] in drop_ips else "permitido"
        enriched.append({**row, "estado": estado})
    return jsonify(enriched)

@app.route('/http')
def get_http():
    query = """
        SELECT http_host AS valor, COUNT(*) as cantidad
        FROM suri_schema.http_events
        GROUP BY http_host
        ORDER BY cantidad DESC
        LIMIT 20
    """
    http_data = query_db(query)
    drop_domains = query_db("SELECT DISTINCT dest_ip FROM suri_schema.drops")
    drop_ips = set([row["dest_ip"] for row in drop_domains])

    enriched = []
    for row in http_data:
        estado = "bloqueado" if row["valor"] in drop_ips else "permitido"
        enriched.append({**row, "estado": estado})
    return jsonify(enriched)

@app.route('/summary/<event_type>')
def get_chart_data(event_type):
    table_map = {
        'alerts': ('suri_schema.alerts', 'src_ip'),
        'drops': ('suri_schema.drops', 'src_ip'),
        'dns': ('suri_schema.dns_events', 'src_ip'),
        'http': ('suri_schema.http_events', 'src_ip')
    }
    if event_type not in table_map:
        return jsonify([])

    table, field = table_map[event_type]
    query = f"SELECT {field} FROM {table} ORDER BY timestamp DESC LIMIT 500"
    results = query_db(query)
    counter = Counter([row[field] for row in results if row[field]])

    return jsonify({
        "total": len(results),
        "top_values": counter.most_common(10)
    })

@app.route('/geo-alerts')
def geo_alerts():
    if not os.path.exists(GEOIP_DB_PATH):
        return jsonify({"error": "GeoIP database not found"}), 500

    geo_coords = []
    with geoip2.database.Reader(GEOIP_DB_PATH) as reader:
        query = """
            SELECT src_ip, dest_ip, alert_signature AS signature, severity
            FROM suri_schema.alerts
            ORDER BY timestamp DESC
            LIMIT 200
        """
        results = query_db(query)
        for row in results:
            ip = row["src_ip"]
            if is_private_ip(ip):
                continue
            try:
                response = reader.city(ip)
                lat = response.location.latitude
                lon = response.location.longitude
                geo_coords.append({
                    "ip": ip,
                    "dest_ip": row["dest_ip"],
                    "signature": row["signature"],
                    "severity": row.get("severity"),
                    "country": response.country.name or "Desconocido",
                    "city": response.city.name or "Desconocido",
                    "latitude": lat,
                    "longitude": lon
                })
            except:
                continue

    return jsonify(geo_coords)

@app.route('/geo-connections')
def geo_connections():
    if not os.path.exists(GEOIP_DB_PATH):
        return jsonify({"error": "GeoIP database not found"}), 500

    connections = []
    with geoip2.database.Reader(GEOIP_DB_PATH) as reader:
        query = """
            SELECT DISTINCT src_ip, dest_ip
            FROM suri_schema.alerts
            WHERE dest_ip IS NOT NULL
            ORDER BY timestamp DESC
            LIMIT 200
        """
        results = query_db(query)
        for row in results:
            src_ip = row["src_ip"]
            dest_ip = row["dest_ip"]
            if is_private_ip(src_ip) or is_private_ip(dest_ip):
                continue
            try:
                src_resp = reader.city(src_ip)
                dst_resp = reader.city(dest_ip)
                connections.append({
                    "src": {
                        "ip": src_ip,
                        "lat": src_resp.location.latitude,
                        "lon": src_resp.location.longitude
                    },
                    "dest": {
                        "ip": dest_ip,
                        "lat": dst_resp.location.latitude,
                        "lon": dst_resp.location.longitude
                    }
                })
            except:
                continue

    return jsonify(connections)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

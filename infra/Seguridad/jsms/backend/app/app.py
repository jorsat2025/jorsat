from flask import Flask, render_template, jsonify
import psycopg2
import psycopg2.extras
from collections import Counter

app = Flask(__name__)

DB_CONFIG = {
    'host': '10.10.10.6',
    'port': '5432',
    'dbname': 'suricata',
    'user': 'suriuser',
    'password': 'murdok45'
}

def query_db(query):
    with psycopg2.connect(**DB_CONFIG) as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute(query)
            return cur.fetchall()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/alerts')
def get_alerts():
    query = '''
        SELECT alert_signature AS valor, COUNT(*) AS cantidad
        FROM suri_schema.alerts
        GROUP BY alert_signature
        ORDER BY cantidad DESC
        LIMIT 20
    '''
    results = query_db(query)
    return jsonify([dict(row) for row in results])

@app.route('/drops')
def get_drops():
    query = '''
        SELECT drop_reason AS valor, COUNT(*) AS cantidad
        FROM suri_schema.drops
        GROUP BY drop_reason
        ORDER BY cantidad DESC
        LIMIT 20
    '''
    drops_data = query_db(query)

    enriched = []
    for row in drops_data:
        enriched.append({
            "valor": row["valor"] or "desconocido",
            "cantidad": row["cantidad"],
            "estado": "bloqueado"
        })
    return jsonify(enriched)


@app.route('/dns')
def get_dns():
    query = '''
        SELECT query AS valor, COUNT(*) as cantidad
        FROM suri_schema.dns_events
        GROUP BY query
        ORDER BY cantidad DESC
        LIMIT 20
    '''
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
    query = '''
        SELECT http_host AS valor, COUNT(*) as cantidad
        FROM suri_schema.http_events
        GROUP BY http_host
        ORDER BY cantidad DESC
        LIMIT 20
    '''
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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

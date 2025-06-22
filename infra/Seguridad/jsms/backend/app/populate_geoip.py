import psycopg2
import geoip2.database
from datetime import datetime

# Configuración de base de datos
DB_CONFIG = {
    'host': '10.10.10.6',
    'port': 5432,
    'dbname': 'suricata',
    'user': 'suriuser',
    'password': 'murdok45'
}

# Ruta al archivo GeoIP
GEOIP_DB_PATH = "/opt/geoip/GeoLite2-City.mmdb"

# Verifica si una IP es privada
PRIVATE_IP_PREFIXES = ('10.', '192.168.', '172.')

def is_private_ip(ip):
    return ip.startswith(PRIVATE_IP_PREFIXES)

def connect_db():
    return psycopg2.connect(**DB_CONFIG)

def get_missing_ips(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT DISTINCT a.src_ip
            FROM suri_schema.alerts a
            WHERE a.src_ip::text NOT LIKE '10.%'
              AND a.src_ip::text NOT LIKE '192.168.%'
              AND a.src_ip::text NOT LIKE '172.%'
              AND NOT EXISTS (
                SELECT 1 FROM suri_schema.ip_geolocation g
                WHERE g.ip = a.src_ip
              )
        """)
        return [row[0] for row in cur.fetchall()]

def enrich_ips(ips):
    if not ips:
        print("No hay IPs públicas nuevas para geolocalizar.")
        return

    with connect_db() as conn, conn.cursor() as cur, geoip2.database.Reader(GEOIP_DB_PATH) as reader:
        for ip in ips:
            try:
                response = reader.city(ip)
                lat = response.location.latitude
                lon = response.location.longitude
                country = response.country.name or "Desconocido"
                city = response.city.name or "Desconocido"
                cur.execute("""
                    INSERT INTO suri_schema.ip_geolocation (ip, country, city, latitude, longitude, last_updated)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, (ip, country, city, lat, lon, datetime.now()))
                print(f"[✓] {ip} geolocalizada: {country}, {city}")
            except Exception as e:
                print(f"[!] {ip} no se pudo geolocalizar: {e}")
        conn.commit()

if __name__ == "__main__":
    conn = connect_db()
    ips = get_missing_ips(conn)
    enrich_ips(ips)
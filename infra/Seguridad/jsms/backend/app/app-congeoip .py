@app.route('/geo-alerts')
def geo_alerts():
    if not os.path.exists(GEOIP_DB_PATH):
        return jsonify({"error": "GeoIP database not found"}), 500

    geo_data = []

    try:
        with geoip2.database.Reader(GEOIP_DB_PATH) as reader:
            query = """
                SELECT DISTINCT dest_ip, alert_signature
                FROM suri_schema.alerts
                WHERE dest_ip IS NOT NULL
                ORDER BY timestamp DESC
                LIMIT 500
            """
            results = query_db(query)

            for row in results:
                ip = row["dest_ip"]
                if is_private_ip(ip):
                    continue
                try:
                    response = reader.city(ip)
                    lat = response.location.latitude
                    lon = response.location.longitude
                    country = response.country.name or "Desconocido"
                    city = response.city.name or "Desconocido"
                    geo_data.append({
                        "ip": ip,
                        "signature": row["alert_signature"],
                        "country": country,
                        "city": city,
                        "latitude": float(lat),
                        "longitude": float(lon)
                    })
                except:
                    continue

        return jsonify(geo_data)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

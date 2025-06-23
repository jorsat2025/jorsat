from scapy.all import rdpcap, IP, TCP, UDP, ICMP
from collections import Counter

pcap_file = "trafico.pcap"  # Cambiar si está en otra ruta

packets = rdpcap(pcap_file)

ip_packets = [p for p in packets if IP in p]
tcp_packets = [p for p in ip_packets if TCP in p]
udp_packets = [p for p in ip_packets if UDP in p]
icmp_packets = [p for p in ip_packets if ICMP in p]

print("📦 Total de paquetes:", len(packets))
print("🌐 IP:", len(ip_packets), " | TCP:", len(tcp_packets), " | UDP:", len(udp_packets), " | ICMP:", len(icmp_packets))

src_ips = Counter(p[IP].src for p in ip_packets)
dst_ips = Counter(p[IP].dst for p in ip_packets)

print("\n🔝 IPs origen más frecuentes:")
for ip, count in src_ips.most_common(10):
    print(f"  {ip} → {count} veces")

print("\n🔝 IPs destino más frecuentes:")
for ip, count in dst_ips.most_common(10):
    print(f"  {ip} → {count} veces")

tcp_ports = Counter(p[TCP].dport for p in tcp_packets)
udp_ports = Counter(p[UDP].dport for p in udp_packets)

print("\n🔝 Puertos TCP destino:")
for port, count in tcp_ports.most_common(10):
    print(f"  {port} → {count} veces")

print("\n🔝 Puertos UDP destino:")
for port, count in udp_ports.most_common(10):
    print(f"  {port} → {count} veces")
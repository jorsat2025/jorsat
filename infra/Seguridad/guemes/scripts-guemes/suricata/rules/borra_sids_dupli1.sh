root@Guemes:~# cat renumsids.sh
#!/bin/bash

RULES_DIR="/opt/suricata/var/lib/suricata/rules"
BACKUP_DIR="/opt/suricata/var/lib/suricata/backup_rules"
TMP_FILE="/tmp/rules_clean.tmp"
SIDS_SEEN="/tmp/sids_seen.tmp"
NEW_SID=9000000

mkdir -p "$BACKUP_DIR"
> "$SIDS_SEEN"

echo "📦 Backup en: $BACKUP_DIR"
echo "⚙️  Renumerando SIDs duplicados..."

for file in "$RULES_DIR"/*.rules; do
  cp "$file" "$BACKUP_DIR/"
  > "$TMP_FILE"
  while IFS= read -r line; do
    sid=$(echo "$line" | grep -o 'sid:[0-9]\+;' | cut -d: -f2 | tr -d ';')
    if [[ -n "$sid" ]]; then
      if grep -qx "$sid" "$SIDS_SEEN"; then
        echo "$line" | sed "s/sid:$sid;/sid:$NEW_SID;/" >> "$TMP_FILE"
        echo "🔁 SID duplicado $sid renumerado como $NEW_SID"
        ((NEW_SID++))
      else
        echo "$sid" >> "$SIDS_SEEN"
        echo "$line" >> "$TMP_FILE"
      fi
    else
      echo "$line" >> "$TMP_FILE"
    fi
  done < "$file"
  mv "$TMP_FILE" "$file"
done

rm -f "$SIDS_SEEN"
echo "✅ Renumeración finalizada sin duplicados. Archivos originales guardados en: $BACKUP_DIR"

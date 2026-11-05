#!/bin/bash
set -uo pipefail

exec 9>/run/helios-watch-auth.lock
flock -n 9 || exit 2

mkdir -p /var/lib/helios
touch /var/lib/helios/blocked.txt

for ip in $(cat /var/lib/helios/blocked.txt); do
    firewall-cmd --ipset=helios-blacklist --add-entry="$ip" >/dev/null 2>&1 || true
done

journalctl -u sshd --since "-10 minutes" -o cat --no-pager |
awk '/Failed password|Failed publickey|Invalid user/ {
    for (i=1; i<NF; i++) {
        if ($i=="from") {
            print $(i+1)
            break
        }
    }
}' | sort | uniq -c |
while read -r count ip; do
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || continue
    [[ "$ip" == "192.168.56.1" ]] && continue

    if (( count > 5 )); then
        if ! grep -Fxq "$ip" /var/lib/helios/blocked.txt; then
            if firewall-cmd --ipset=helios-blacklist --add-entry="$ip" >/dev/null 2>&1; then
                echo "$ip" >> /var/lib/helios/blocked.txt
                logger -t helios-watch-auth "BLACKLIST $ip"
            fi
        fi
    fi
done
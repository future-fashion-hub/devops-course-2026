#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo " [OK] $desc"
        ((PASS++))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"

check "Вход от имени root запрещён" \
      "no" \
      "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"

check "Парольная аутентификация отключена" \
      "no" \
      "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

check "Порт SSH отличается от 22" \
      "yes" \
      "$(sudo sshd -T | awk '/^port/{if ($2 != 22) print "yes"; else print "no"}')"

check "MaxAuthTries равен 3" \
      "3" \
      "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"

check "Межсетевой экран активен" \
      "active" \
      "$(sudo ufw status | awk '/^Status:/{print $2}')"

check "Политика входящего трафика равна deny" \
      "deny" \
      "$(sudo ufw status verbose | awk '/^Default:/{gsub(/[(),]/,""); print $2}')"

echo "[3] Учётные записи"

awk -F: '$3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"
check "Nginx активен" "active" "$(systemctl is-active nginx)"
check "HTTP перенаправляет на HTTPS" "301" "$(curl -s -o /dev/null -w '%{http_code}' http://devops.local/)"
check "HTTPS проверяет сертификат" "200" "$(curl -s --cacert /home/devops/devops.crt -o /dev/null -w '%{http_code}' https://devops.local/)"
check "Конфигурация Nginx корректна" "yes" "$(sudo nginx -t >/dev/null 2>&1 && echo yes || echo no)"
echo "[5] Контейнеризация"
check "Docker активен" "active" "$(systemctl is-active docker)"
check "PostgreSQL healthy" "healthy" "$(docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null)"
check "Порты 5000 и 5432 не открыты во внешнюю сеть" "yes" "$(ss -H -tln | awk '$4 ~ /:(5000|5432)$/ && $4 !~ /^127\.0\.0\.1:/ {bad=1} END {print bad ? "no" : "yes"}')"
check "Права .env равны 600" "600" "$(stat -c '%a' /home/devops/app/.env)"
echo "Пройдено: $PASS, не пройдено: $FAIL"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1

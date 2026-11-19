#!/bin/bash

# Настройки
EMAIL="admin@example.com"
ACCESS="/var/log/nginx/access.log"
ERROR="/var/log/nginx/error.log"
DIR="/var/lib/nginx-report"

mkdir -p "$DIR"

# Не запускаем две копии одновременно
exec 9>"$DIR/lock"
flock -n 9 || exit 0

NOW=$(date '+%Y-%m-%d %H:%M:%S %z')

# При первом запуске запоминаем текущее состояние логов
if [ ! -f "$DIR/time" ]; then
    echo "$NOW" > "$DIR/time"
    wc -l < "$ACCESS" > "$DIR/access_count"
    wc -l < "$ERROR" > "$DIR/error_count"
    echo "Первый запуск: состояние логов сохранено"
    exit 0
fi

LAST=$(cat "$DIR/time")
A_OLD=$(cat "$DIR/access_count")
E_OLD=$(cat "$DIR/error_count")
A_NEW=$(wc -l < "$ACCESS")
E_NEW=$(wc -l < "$ERROR")

# Если лог обнулился, читаем с первой строки
if (( A_NEW < A_OLD )); then A_OLD=0; fi
if (( E_NEW < E_OLD )); then E_OLD=0; fi

# Берём только строки, появившиеся после прошлого запуска
: > "$DIR/new_access"
: > "$DIR/new_error"
if (( A_NEW > A_OLD )); then
    sed -n "$((A_OLD + 1)),${A_NEW}p" "$ACCESS" > "$DIR/new_access"
fi
if (( E_NEW > E_OLD )); then
    sed -n "$((E_OLD + 1)),${E_NEW}p" "$ERROR" > "$DIR/new_error"
fi

# Формируем отчёт
{
    echo "Отчёт Nginx"
    echo "Период: $LAST — $NOW"
    echo
    echo "ТОП-10 IP:"
    awk '{print $1}' "$DIR/new_access" | sort | uniq -c | sort -nr | head -10
    echo
    echo "ТОП-10 URL:"
    awk '{print $7}' "$DIR/new_access" | sort | uniq -c | sort -nr | head -10
    echo
    echo "HTTP-коды:"
    awk '{print $9}' "$DIR/new_access" | sort | uniq -c | sort -nr
    echo
    echo "Ошибки:"
    cat "$DIR/new_error"
} > "$DIR/report.txt"

# Обновляем состояние только после успешной отправки
if mail -s "Nginx report" "$EMAIL" < "$DIR/report.txt"; then
    echo "$NOW" > "$DIR/time"
    echo "$A_NEW" > "$DIR/access_count"
    echo "$E_NEW" > "$DIR/error_count"
fi

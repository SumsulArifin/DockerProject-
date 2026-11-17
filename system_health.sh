#!/usr/bin/env bash
#
# system_health.sh - collect CPU/memory/disk/load metrics, log them, and
# warn (or fail) when configurable thresholds are exceeded. Designed to be
# run periodically (cron or systemd timer) on a production server.
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
LOG_FILE="${HEALTH_LOG_FILE:-$(dirname "$(readlink -f "$0")")/health_log.txt}"
MAX_LOG_BYTES=$((5 * 1024 * 1024)) # rotate past 5MB
KEEP_ROTATED=3

DISK_THRESHOLD=80
CPU_THRESHOLD=90
MEM_THRESHOLD=85
JSON_OUTPUT=false

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Collects CPU, memory, disk, load average, and top-memory-process metrics,
appends a timestamped entry to health_log.txt, and warns when thresholds
are exceeded.

Options:
  --disk <percent>   Disk usage warning threshold (default: ${DISK_THRESHOLD})
  --cpu <percent>     CPU usage warning threshold (default: ${CPU_THRESHOLD})
  --mem <percent>     Memory usage warning threshold (default: ${MEM_THRESHOLD})
  --json              Also print the collected metrics as a JSON object
  -h, --help           Show this help message

Exit codes:
  0  healthy - all metrics below their thresholds
  1  warning - at least one metric exceeded its threshold
  2  critical - at least one metric exceeded (threshold + 10)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --disk)
      DISK_THRESHOLD="$2"
      shift 2
      ;;
    --cpu)
      CPU_THRESHOLD="$2"
      shift 2
      ;;
    --mem)
      MEM_THRESHOLD="$2"
      shift 2
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

rotate_log_if_needed() {
  [ -f "${LOG_FILE}" ] || return 0
  local size
  size=$(stat -c%s "${LOG_FILE}" 2>/dev/null || stat -f%z "${LOG_FILE}")
  if [ "${size}" -ge "${MAX_LOG_BYTES}" ]; then
    for i in $(seq $((KEEP_ROTATED - 1)) -1 1); do
      [ -f "${LOG_FILE}.${i}" ] && mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i + 1))"
    done
    mv "${LOG_FILE}" "${LOG_FILE}.1"
  fi
}

# CPU usage: sample /proc/stat twice, 1s apart, and compute the delta.
read_cpu_total() {
  # Fields after "cpu": user nice system idle iowait irq softirq steal
  read -r _ user nice system idle iowait irq softirq steal _ < <(grep '^cpu ' /proc/stat)
  local idle_all=$((idle + iowait))
  local non_idle=$((user + nice + system + irq + softirq + steal))
  local total=$((idle_all + non_idle))
  echo "${total} ${idle_all}"
}

cpu_usage_percent() {
  read -r total1 idle1 < <(read_cpu_total)
  sleep 1
  read -r total2 idle2 < <(read_cpu_total)
  local total_delta=$((total2 - total1))
  local idle_delta=$((idle2 - idle1))
  if [ "${total_delta}" -le 0 ]; then
    echo "0.0"
    return
  fi
  awk -v td="${total_delta}" -v id="${idle_delta}" 'BEGIN { printf "%.1f", (1 - id/td) * 100 }'
}

mem_usage_percent() {
  awk '
    /^MemTotal:/ { total = $2 }
    /^MemAvailable:/ { avail = $2 }
    END { printf "%.1f", (1 - avail/total) * 100 }
  ' /proc/meminfo
}

load_average() {
  awk '{ print $1, $2, $3 }' /proc/loadavg
}

# Emits "mountpoint usage_percent" per line for every real mounted filesystem.
disk_usage_lines() {
  df -P -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR>1 { gsub("%","",$5); print $6, $5 }'
}

top_processes_by_mem() {
  ps -eo pid,comm,%mem --sort=-%mem --no-headers | head -n 5
}

CPU_USAGE="$(cpu_usage_percent)"
MEM_USAGE="$(mem_usage_percent)"
read -r LOAD1 LOAD5 LOAD15 < <(load_average)
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

STATUS="healthy"
EXIT_CODE=0
WARNINGS=()

check_threshold() {
  local label="$1" value="$2" threshold="$3"
  local critical_threshold
  critical_threshold=$(awk -v t="${threshold}" 'BEGIN { c = t + 10; print (c > 99 ? 99 : c) }')

  if awk -v v="${value}" -v c="${critical_threshold}" 'BEGIN { exit !(v >= c) }'; then
    WARNINGS+=("[WARNING] ${label} usage critical: ${value}% (threshold ${threshold}%, critical ${critical_threshold}%)")
    EXIT_CODE=2
  elif awk -v v="${value}" -v t="${threshold}" 'BEGIN { exit !(v >= t) }'; then
    WARNINGS+=("[WARNING] ${label} usage high: ${value}% (threshold ${threshold}%)")
    [ "${EXIT_CODE}" -lt 1 ] && EXIT_CODE=1
  fi
}

check_threshold "CPU" "${CPU_USAGE}" "${CPU_THRESHOLD}"
check_threshold "Memory" "${MEM_USAGE}" "${MEM_THRESHOLD}"

DISK_JSON_PARTS=()
while read -r mountpoint usage; do
  [ -n "${mountpoint}" ] || continue
  check_threshold "Disk(${mountpoint})" "${usage}" "${DISK_THRESHOLD}"
  DISK_JSON_PARTS+=("{\"mountpoint\":\"${mountpoint}\",\"usage_percent\":${usage}}")
done < <(disk_usage_lines)

if [ "${EXIT_CODE}" -eq 1 ]; then
  STATUS="warning"
elif [ "${EXIT_CODE}" -eq 2 ]; then
  STATUS="critical"
fi

TOP_PROCS="$(top_processes_by_mem)"

rotate_log_if_needed

{
  echo "[${TIMESTAMP}] status=${STATUS} cpu=${CPU_USAGE}% mem=${MEM_USAGE}% load=${LOAD1},${LOAD5},${LOAD15}"
  while read -r mountpoint usage; do
    [ -n "${mountpoint}" ] && echo "  disk ${mountpoint}: ${usage}%"
  done < <(disk_usage_lines)
  echo "  top 5 processes by memory:"
  echo "${TOP_PROCS}" | sed 's/^/    /'
  for w in "${WARNINGS[@]+"${WARNINGS[@]}"}"; do
    echo "  ${w}"
  done
} >> "${LOG_FILE}"

for w in "${WARNINGS[@]+"${WARNINGS[@]}"}"; do
  echo "${w}"
done

if [ "${JSON_OUTPUT}" = true ]; then
  DISK_JSON=$(IFS=,; echo "${DISK_JSON_PARTS[*]+${DISK_JSON_PARTS[*]}}")
  TOP_PROC_JSON=$(echo "${TOP_PROCS}" | awk '{printf "%s{\"pid\":\"%s\",\"command\":\"%s\",\"mem_percent\":%s}", sep, $1, $2, $3; sep=","}')
  printf '{"timestamp":"%s","status":"%s","cpu_percent":%s,"mem_percent":%s,"load_average":[%s,%s,%s],"disk":[%s],"top_processes":[%s]}\n' \
    "${TIMESTAMP}" "${STATUS}" "${CPU_USAGE}" "${MEM_USAGE}" "${LOAD1}" "${LOAD5}" "${LOAD15}" "${DISK_JSON}" "${TOP_PROC_JSON}"
fi

exit "${EXIT_CODE}"

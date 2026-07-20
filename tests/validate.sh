#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_file="${repo_root}/configs/monitoring/docker-compose.yml"
prometheus_dir="${repo_root}/configs/monitoring/prometheus"

printf 'Checking Bash syntax...\n'
mapfile -d '' shell_files < <(find "$repo_root" -type f -name '*.sh' -print0)

if [[ "${#shell_files[@]}" -eq 0 ]]; then
    printf 'No shell scripts were found.\n' >&2
    exit 1
fi

for file in "${shell_files[@]}"; do
    bash -n "$file"
    printf '[PASS] %s\n' "${file#"$repo_root"/}"
done

if ! command -v docker >/dev/null 2>&1; then
    printf 'Docker is unavailable; Compose and promtool checks were skipped.\n'
    exit 0
fi

printf 'Checking Docker Compose rendering...\n'
docker compose -f "$compose_file" config --quiet
printf '[PASS] Docker Compose configuration\n'

printf 'Checking Prometheus configuration and alert rules...\n'
docker run --rm \
    --entrypoint=/bin/promtool \
    -v "${prometheus_dir}:/etc/prometheus:ro" \
    prom/prometheus:v3.13.1 \
    check config /etc/prometheus/prometheus.yml

printf '[PASS] Prometheus configuration and rules\n'

#!/usr/bin/env bash
# ============================================================
#  HPA Monitor — jalankan di terminal terpisah saat k6 running
#  Usage: bash watch-hpa.sh
# ============================================================
echo "=============================================="
echo "  KerjaDekat HPA Monitor (Ctrl+C untuk stop)"
echo "=============================================="
echo ""

while true; do
  clear
  echo "=== $(date '+%H:%M:%S') — HPA Status ==="
  kubectl get hpa -n kerjadekat
  echo ""
  echo "=== Pod Count ==="
  kubectl get pods -n kerjadekat -o wide --no-headers | \
    awk '{printf "  %-50s %-10s %-8s %s\n", $1, $3, $5, $7}'
  echo ""
  echo "=== Resource Usage ==="
  kubectl top pods -n kerjadekat 2>/dev/null || echo "  (metrics belum ready)"
  echo ""
  echo "--- Refresh setiap 5 detik ---"
  sleep 5
done

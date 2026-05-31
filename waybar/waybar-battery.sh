#!/usr/bin/env bash
# Scan all BAT* in /sys/class/power_supply and output waybar JSON

total=0
count=0
charging=false

for bat in /sys/class/power_supply/BAT*; do
  [ -d "$bat" ] || continue
  cap=$(cat "$bat/capacity" 2>/dev/null) || continue
  status=$(cat "$bat/status" 2>/dev/null)
  total=$((total + cap))
  count=$((count + 1))
  [ "$status" = "Charging" ] && charging=true
done

if [ "$count" -eq 0 ]; then
  echo '{"text":"N/A","class":"none"}'
  exit 0
fi

avg=$((total / count))
icon="⊕"
class="normal"

if [ "$avg" -le 15 ]; then
  class="critical"
elif [ "$avg" -le 30 ]; then
  class="warning"
fi

tooltip=""
i=1
for bat in /sys/class/power_supply/BAT*; do
  [ -d "$bat" ] || continue
  cap=$(cat "$bat/capacity" 2>/dev/null) || continue
  status=$(cat "$bat/status" 2>/dev/null)
  [ -n "$tooltip" ] && tooltip="${tooltip}\n"
  tooltip="${tooltip}BAT${i}: ${cap}% (${status})"
  i=$((i + 1))
done

printf '{"text":"%s %d%%","class":"%s","tooltip":"%s"}' \
  "$icon" "$avg" "$class" "$tooltip"

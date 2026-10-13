#!/bin/bash
# macOS용. 앱 프로세스의 스레드 수와 메모리를 1초마다 찍는다. Ctrl+C로 끝낸다.
# 서브 창을 열고 닫으면서 REUSE_WINDOWS=true/false의 차이를 본다.
#   bash tool/watch_threads.sh

while true; do
  pid=$(pgrep -x multi_window_sample | head -n 1)
  if [ -n "$pid" ]; then
    threads=$(ps -M -p "$pid" | tail -n +2 | wc -l | tr -d ' ')
    rss_kb=$(ps -o rss= -p "$pid" | tr -d ' ')
    printf '%s  threads=%s  rss=%sMB\n' "$(date +%H:%M:%S)" "$threads" "$((rss_kb / 1024))"
  fi
  sleep 1
done

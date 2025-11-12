#!/bin/bash
INTERFACE="veth1"
PCAP1="/home/ryuoo0/security/Parser/pcap/normal.pcap"
PCAP2="/home/ryuoo0/security/Parser/pcap/attack_01.pcap"
TCPREPLAY_BIN="$(which tcpreplay 2>/dev/null || echo /usr/sbin/tcpreplay)"

# 파일이 준비될 때까지 대기
wait_for_file(){
  while [ ! -f "$1" ]; do
    sleep 5
  done
}

while true; do
  wait_for_file "$PCAP1"
  "$TCPREPLAY_BIN" -i "$INTERFACE" "$PCAP1" || true

  wait_for_file "$PCAP2"
  "$TCPREPLAY_BIN" -i "$INTERFACE" "$PCAP2" || true
done

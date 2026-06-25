#!/bin/bash
IP=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -1)
echo "서버 IP: $IP"
flutter run --dart-define=BASE_URL=http://$IP:3000 "$@"

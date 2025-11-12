#!/bin/bash

echo "======================================================================="
echo "===   OT Security Monitoring System - Quick Start   ==="
echo "======================================================================="
echo ""

# 네트워크 인터페이스 확인
echo "[1/4] Available network interfaces:"
ip link show | grep -E "^[0-9]+:" | awk '{print "  - " $2}' | sed 's/:$//'
echo ""

# .env 파일 확인
if [ ! -f .env ]; then
    echo "[ERROR] .env file not found!"
    echo "Please create .env file from .env.example"
    exit 1
fi

echo "[2/4] Current configuration:"
echo "  Network Interface: $(grep NETWORK_INTERFACE .env | cut -d'=' -f2)"
echo "  Parser Mode: $(grep PARSER_MODE .env | cut -d'=' -f2)"
echo "  Elasticsearch: $(grep ELASTICSEARCH_HOST .env | cut -d'=' -f2):$(grep ELASTICSEARCH_PORT .env | cut -d'=' -f2)"
echo "  Redis: $(grep REDIS_HOST .env | cut -d'=' -f2):$(grep REDIS_PORT .env | cut -d'=' -f2)"
echo ""

# 빌드 옵션
read -p "[3/4] Rebuild Docker images? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "[INFO] Building Docker images..."
    docker-compose build
else
    echo "[INFO] Skipping build..."
fi
echo ""

# 실행
echo "[4/4] Starting services..."
docker-compose up -d

echo ""
echo "======================================================================="
echo "[SUCCESS] Services started!"
echo ""
echo "Monitor logs:"
echo "  - All services:  docker-compose logs -f"
echo "  - Parser only:   docker-compose logs -f parser"
echo "  - Redis only:    docker-compose logs -f redis"
echo ""
echo "Check status:"
echo "  docker-compose ps"
echo ""
echo "Stop services:"
echo "  docker-compose stop"
echo ""
echo "Remove services:"
echo "  docker-compose down"
echo "======================================================================="

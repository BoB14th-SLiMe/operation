#!/bin/bash

# ============================================
# OT 보안 모니터링 시스템 - Docker Compose 실행 스크립트
# ============================================

set -e  # 에러 발생 시 즉시 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 함수: 정보 출력
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# 함수: 경고 출력
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 함수: 에러 출력
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================
# 0. 작업 디렉토리 확인
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

info "작업 디렉토리: $PROJECT_ROOT"
cd "$PROJECT_ROOT"

# ============================================
# 1. 사전 확인
# ============================================
info "OT 보안 모니터링 시스템 시작 중..."

# Docker 설치 확인
if ! command -v docker &> /dev/null; then
    error "Docker가 설치되어 있지 않습니다."
    exit 1
fi

# Docker Compose 설치 확인
if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose가 설치되어 있지 않습니다."
    exit 1
fi

info "Docker 버전: $(docker --version)"
info "Docker Compose 버전: $(docker-compose --version)"

# ============================================
# 2. Parser 바이너리 확인
# ============================================
if [ ! -f "Parser/build/parser" ]; then
    error "Parser 바이너리가 없습니다: Parser/build/parser"
    error "먼저 C++ Parser를 빌드해주세요."
    error ""
    error "빌드 방법:"
    error "  cd Parser/build"
    error "  cmake .."
    error "  make"
    exit 1
fi

info "Parser 바이너리 확인: Parser/build/parser"
chmod +x Parser/build/parser
info "실행 권한 부여 완료"

# ============================================
# 3. 환경 변수 확인
# ============================================
if [ ! -f "operation/.env" ]; then
    warn ".env 파일이 없습니다. operation/.env.example을 복사합니다..."
    if [ -f "operation/.env.example" ]; then
        cp operation/.env.example operation/.env
        warn "operation/.env 파일을 수정한 후 다시 실행해주세요."
        exit 0
    else
        warn ".env.example이 없습니다. 기본값으로 진행합니다."
    fi
fi

info "환경 변수 확인 완료"

# ============================================
# 4. 기존 컨테이너 확인
# ============================================
cd operation

if docker-compose ps | grep -q "Up"; then
    warn "실행 중인 컨테이너가 있습니다."
    read -p "기존 컨테이너를 중지하고 다시 시작하시겠습니까? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "기존 컨테이너 중지 중..."
        docker-compose down
    else
        info "취소되었습니다."
        exit 0
    fi
fi

# ============================================
# 5. Docker Compose 실행
# ============================================
info "Docker Compose 시작 중..."
docker-compose up -d

# ============================================
# 6. 서비스 상태 확인
# ============================================
info "서비스 시작 대기 중 (30초)..."
sleep 30

info "서비스 상태 확인:"
docker-compose ps

# ============================================
# 7. 헬스체크
# ============================================
info "헬스체크 수행 중..."

# Redis
if docker exec ot-security-redis redis-cli ping | grep -q "PONG"; then
    info "✓ Redis: 정상"
else
    error "✗ Redis: 비정상"
fi

# Kafka
if docker exec ot-security-kafka kafka-topics --bootstrap-server localhost:9092 --list &> /dev/null; then
    info "✓ Kafka: 정상"
else
    error "✗ Kafka: 비정상"
fi

# Parser
if docker-compose ps cpp-parser | grep -q "Up"; then
    info "✓ C++ Parser: 실행 중"
else
    warn "✗ C++ Parser: 중지됨"
fi

# JSONL Sender
if docker-compose ps jsonl-sender | grep -q "Up"; then
    info "✓ JSONL Sender: 실행 중"
else
    warn "✗ JSONL Sender: 중지됨"
fi

# ============================================
# 8. 접속 정보 출력
# ============================================
echo ""
info "=========================================="
info "OT 보안 모니터링 시스템 시작 완료!"
info "=========================================="
echo ""
info "📊 모니터링 도구:"
info "  - Kafka UI:        http://localhost:8090"
info "  - Redis Commander: http://localhost:8081"
echo ""
info "🔌 서비스 엔드포인트:"
info "  - Redis:     localhost:6379"
info "  - Kafka:     localhost:9092"
info "  - Zookeeper: localhost:2181"
echo ""
info "📝 로그 확인:"
info "  cd operation"
info "  docker-compose logs -f"
info "  docker-compose logs -f cpp-parser"
info "  docker-compose logs -f jsonl-sender"
echo ""
info "🛑 중지:"
info "  cd operation"
info "  docker-compose down"
echo ""

# ============================================
# 9. Parser 로그 모니터링 (선택적)
# ============================================
read -p "Parser 로그를 실시간으로 확인하시겠습니까? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Parser 로그 모니터링 시작 (Ctrl+C로 종료)..."
    docker-compose logs -f cpp-parser jsonl-sender
fi

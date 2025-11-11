#!/bin/bash

# ============================================
# Parser 바이너리 직접 빌드 및 실행 스크립트
# ============================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${CYAN}[✓]${NC} $1"; }
header() { echo -e "${BLUE}[>>>]${NC} $1"; }

# 작업 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PARSER_DIR="$PROJECT_ROOT/Parser"

cd "$SCRIPT_DIR"

# ============================================
# 1. 사전 확인
# ============================================
clear
echo ""
header "=========================================="
header "  Parser 빌드 및 Docker 실행"
header "=========================================="
echo ""

# Root 권한 확인
if [ "$EUID" -ne 0 ]; then 
    error "이 스크립트는 root 권한이 필요합니다."
    error "sudo ./build-and-run.sh 로 실행하세요."
    exit 1
fi

# Docker 확인
if ! command -v docker &> /dev/null; then
    error "Docker가 설치되어 있지 않습니다."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose가 설치되어 있지 않습니다."
    exit 1
fi

success "Docker 환경 확인 완료"

# ============================================
# 2. Parser 디렉토리 확인
# ============================================
if [ ! -d "$PARSER_DIR" ]; then
    error "Parser 디렉토리가 없습니다: $PARSER_DIR"
    exit 1
fi

success "Parser 디렉토리 확인: $PARSER_DIR"

# ============================================
# 3. 빌드 옵션 선택
# ============================================
echo ""
info "빌드 옵션을 선택하세요:"
echo "  1) 로컬에서 빌드 (CMake + make)"
echo "  2) 이미 빌드된 바이너리 사용 (기본)"
echo ""
read -p "선택 [1-2] (기본: 2): " BUILD_OPTION
BUILD_OPTION=${BUILD_OPTION:-2}

if [ "$BUILD_OPTION" = "1" ]; then
    # ============================================
    # 로컬 빌드
    # ============================================
    header "로컬 빌드 시작"
    
    info "필수 패키지 설치 중..."
    apt-get update
    apt-get install -y \
        build-essential \
        cmake \
        pkg-config \
        libpcap-dev \
        libcurl4-openssl-dev \
        libhiredis-dev \
        nlohmann-json3-dev
    
    success "패키지 설치 완료"
    
    # 빌드 디렉토리 생성
    mkdir -p "$PARSER_DIR/build"
    cd "$PARSER_DIR/build"
    
    info "CMake 구성 중..."
    cmake ..
    
    info "컴파일 중... (시간이 소요될 수 있습니다)"
    make -j$(nproc)
    
    if [ ! -f "$PARSER_DIR/build/parser" ]; then
        error "빌드 실패! parser 바이너리가 생성되지 않았습니다."
        exit 1
    fi
    
    success "빌드 완료: $PARSER_DIR/build/parser"
    
    cd "$SCRIPT_DIR"

elif [ "$BUILD_OPTION" = "2" ]; then
    # ============================================
    # 기존 바이너리 확인
    # ============================================
    if [ ! -f "$PARSER_DIR/build/parser" ]; then
        error "빌드된 바이너리가 없습니다: $PARSER_DIR/build/parser"
        error "먼저 바이너리를 Parser/build/parser 위치에 복사하세요."
        exit 1
    fi
    
    success "기존 바이너리 확인: $PARSER_DIR/build/parser"
    
    # 바이너리 정보 출력
    info "바이너리 정보:"
    ls -lh "$PARSER_DIR/build/parser"
    file "$PARSER_DIR/build/parser"

else
    error "잘못된 선택입니다."
    exit 1
fi

# ============================================
# 4. .env 파일 확인
# ============================================
echo ""
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    warn ".env 파일이 없습니다. 기본값으로 생성합니다."
    
    cat > "$ENV_FILE" <<'EOF'
# Elasticsearch Configuration
ELASTICSEARCH_HOST=100.126.141.58
ELASTICSEARCH_PORT=9200
ELASTICSEARCH_USERNAME=
ELASTICSEARCH_PASSWORD=
ELASTICSEARCH_INDEX_PREFIX=ics-packets

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0
REDIS_POOL_SIZE=8
REDIS_ASYNC_WRITERS=2
REDIS_ASYNC_QUEUE_SIZE=10000
REDIS_TIMEOUT_MS=1000

# Parser Configuration
NETWORK_INTERFACE=veth1
BPF_FILTER=
PARSER_MODE=realtime
ROLLING_INTERVAL=0
OUTPUT_DIR=/data/output
PARSER_THREADS=0

# Logging
LOG_LEVEL=INFO

# Resource Limits
PARSER_MEMORY_LIMIT=2g
PARSER_CPU_LIMIT=2.0
REDIS_MEMORY_LIMIT=512M

# Advanced Options
ES_BULK_SIZE=100
ES_BULK_FLUSH_INTERVAL_MS=100
REDIS_STREAM_MAX_LEN=100000
REDIS_ASSET_CACHE_TTL=3600
EOF
    
    success ".env 파일 생성 완료"
    warn "필요시 .env 파일을 수정하세요: nano $ENV_FILE"
    echo ""
    read -p "지금 수정하시겠습니까? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} "$ENV_FILE"
    fi
fi

# .env 로드
set -a
source "$ENV_FILE"
set +a

success "환경 변수 로드 완료"

# ============================================
# 5. 설정 정보 표시
# ============================================
echo ""
header "=========================================="
header "  현재 설정"
header "=========================================="
echo ""

info "네트워크: ${NETWORK_INTERFACE}"
info "모드: ${PARSER_MODE}"
info "Elasticsearch: ${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}"
info "Redis: ${REDIS_HOST}:${REDIS_PORT}"
echo ""

read -p "이 설정으로 계속하시겠습니까? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "취소되었습니다."
    exit 0
fi

# ============================================
# 6. Docker 이미지 빌드
# ============================================
echo ""
header "Docker 이미지 빌드 중..."

cd "$PARSER_DIR"

# Dockerfile이 있는지 확인
if [ ! -f "Dockerfile" ]; then
    error "Dockerfile이 없습니다: $PARSER_DIR/Dockerfile"
    error "앞서 제공한 Dockerfile을 Parser/Dockerfile로 저장하세요."
    exit 1
fi

docker build -t ics-parser:latest .

if [ $? -ne 0 ]; then
    error "Docker 이미지 빌드 실패!"
    exit 1
fi

success "Docker 이미지 빌드 완료"

cd "$SCRIPT_DIR"

# ============================================
# 7. 기존 컨테이너 정리
# ============================================
echo ""
info "기존 컨테이너 확인 중..."

COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

if docker-compose -f "$COMPOSE_FILE" ps 2>/dev/null | grep -q "Up"; then
    warn "실행 중인 컨테이너가 있습니다."
    docker-compose -f "$COMPOSE_FILE" ps
    echo ""
    
    info "기존 컨테이너를 중지합니다..."
    docker-compose -f "$COMPOSE_FILE" down
    success "중지 완료"
fi

# ============================================
# 8. 컨테이너 시작
# ============================================
echo ""
header "=========================================="
header "  컨테이너 시작"
header "=========================================="
echo ""

info "Docker Compose로 시작 중..."
docker-compose -f "$COMPOSE_FILE" up -d

if [ $? -ne 0 ]; then
    error "컨테이너 시작 실패!"
    exit 1
fi

# ============================================
# 9. 서비스 초기화 대기
# ============================================
echo ""
info "서비스 초기화 중..."

info "Redis 대기 중..."
for i in {1..15}; do
    if docker exec redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
        success "Redis 준비 완료 (${i}초)"
        break
    fi
    echo -n "."
    sleep 1
done
echo ""

info "Parser 초기화 중 (10초)..."
sleep 10

# ============================================
# 10. 헬스체크
# ============================================
echo ""
header "=========================================="
header "  헬스체크"
header "=========================================="
echo ""

# Redis
if docker exec redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
    success "✓ Redis: 정상"
else
    error "✗ Redis: 비정상"
fi

# Parser
if docker-compose -f "$COMPOSE_FILE" ps 2>/dev/null | grep "parser" | grep -q "Up"; then
    success "✓ Parser: 실행 중"
    
    sleep 3
    PARSER_LOGS=$(docker-compose -f "$COMPOSE_FILE" logs --tail=30 parser 2>/dev/null)
    
    if echo "$PARSER_LOGS" | grep -q "Starting\|Capture"; then
        success "  ✓ 패킷 캡처 시작"
    fi
    
    if echo "$PARSER_LOGS" | grep -qi "redis.*connect\|redis.*success"; then
        success "  ✓ Redis 연결"
    fi
    
    if echo "$PARSER_LOGS" | grep -qi "elasticsearch.*connect\|elasticsearch.*success"; then
        success "  ✓ Elasticsearch 연결"
    fi
    
    if echo "$PARSER_LOGS" | grep -qi "error\|fail"; then
        warn "  ⚠️  에러 로그 감지 (확인 필요)"
    fi
else
    error "✗ Parser: 중지됨"
    error "로그를 확인하세요:"
    docker-compose -f "$COMPOSE_FILE" logs parser
fi

# ============================================
# 11. 서비스 상태
# ============================================
echo ""
header "=========================================="
header "  서비스 상태"
header "=========================================="
echo ""

docker-compose -f "$COMPOSE_FILE" ps

# ============================================
# 12. 데이터 확인
# ============================================
echo ""
info "데이터 전송 확인 중 (15초 대기)..."
sleep 15

# Redis Stream
STREAM_COUNT=0
for protocol in modbus_tcp s7comm xgt-fen dnp3 dns; do
    STREAM_NAME="stream:protocol:${protocol}"
    LEN=$(docker exec redis redis-cli XLEN "$STREAM_NAME" 2>/dev/null || echo "0")
    if [ "$LEN" != "0" ] && [ ! -z "$LEN" ]; then
        info "  Redis Stream [$protocol]: $LEN 메시지"
        STREAM_COUNT=$((STREAM_COUNT + 1))
    fi
done

if [ $STREAM_COUNT -gt 0 ]; then
    success "Redis에 데이터 확인 (${STREAM_COUNT}개 프로토콜)"
else
    warn "Redis에 아직 데이터가 없습니다 (트래픽 확인 필요)"
fi

# Elasticsearch
ES_URL="http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}"
if curl -s --connect-timeout 5 "$ES_URL/_cat/indices?v" 2>/dev/null | grep -q "${ELASTICSEARCH_INDEX_PREFIX}"; then
    success "Elasticsearch 인덱스 생성 확인"
    
    DOC_COUNT=$(curl -s "$ES_URL/${ELASTICSEARCH_INDEX_PREFIX}-*/_count" 2>/dev/null | grep -oP '"count"\s*:\s*\K[0-9]+')
    if [ ! -z "$DOC_COUNT" ]; then
        info "  문서 수: ${DOC_COUNT}"
    fi
else
    warn "Elasticsearch 인덱스 아직 없음"
fi

# ============================================
# 13. 완료
# ============================================
echo ""
header "=========================================="
header "  시스템 시작 완료!"
header "=========================================="
echo ""

info "📊 모니터링:"
echo "  - Kibana:   http://${ELASTICSEARCH_HOST}:5601"
echo "  - Backend:  http://${ELASTICSEARCH_HOST}:8080"
echo "  - Frontend: http://${ELASTICSEARCH_HOST}:5173"
echo ""

info "📝 유용한 명령어:"
echo "  # 실시간 로그"
echo "  docker-compose -f $COMPOSE_FILE logs -f parser"
echo ""
echo "  # Redis 확인"
echo "  docker exec redis redis-cli INFO stats"
echo "  docker exec redis redis-cli XLEN stream:protocol:modbus_tcp"
echo ""
echo "  # 컨테이너 중지"
echo "  docker-compose -f $COMPOSE_FILE down"
echo ""
echo "  # 재시작"
echo "  docker-compose -f $COMPOSE_FILE restart parser"
echo ""

read -p "실시간 로그를 보시겠습니까? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    header "실시간 로그 (Ctrl+C로 종료)"
    echo ""
    sleep 2
    docker-compose -f "$COMPOSE_FILE" logs -f parser
fi

echo ""
success "완료!"
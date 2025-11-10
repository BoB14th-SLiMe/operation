#!/bin/bash

# ============================================
# 실시간 ICS 패킷 분석 시스템 (AI PC - Parser Stack)
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

# ============================================
# 작업 디렉토리 확인
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$SCRIPT_DIR"

# ============================================
# 1. 사전 확인 (Docker, Root)
# ============================================
clear
echo ""
header "=========================================="
header "  실시간 ICS 파서 스택 (AI PC) 시작"
header "=========================================="
echo ""

if ! command -v docker &> /dev/null; then
    error "Docker가 설치되어 있지 않습니다." && exit 1
fi
if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose가 설치되어 있지 않습니다." && exit 1
fi
success "Docker 환경 확인 완료"

if [ "$EUID" -ne 0 ]; then 
    warn "패킷 캡처를 위해 root 권한(sudo)이 강력히 권장됩니다."
    read -p "계속 진행하시겠습니까? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi
fi

# ============================================
# 2. 환경 변수 설정 (.env)
# ============================================
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    error ".env 파일이 없습니다: $ENV_FILE"
    info "기본 .env 파일을 생성합니다..."
    
    cat > "$ENV_FILE" <<'EOF'
# ============================================
# OT Security Monitoring System - Environment Variables
# ============================================

# ============================================
# 1. Elasticsearch Configuration (Dashboard PC)
# ============================================
ELASTICSEARCH_HOST=100.126.141.58
ELASTICSEARCH_PORT=9200
ELASTICSEARCH_USERNAME=
ELASTICSEARCH_PASSWORD=
ELASTICSEARCH_INDEX_PREFIX=ics-packets

# ============================================
# 2. Redis Configuration (Local)
# ============================================
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0
REDIS_POOL_SIZE=8
REDIS_ASYNC_WRITERS=2
REDIS_ASYNC_QUEUE_SIZE=10000
REDIS_TIMEOUT_MS=1000

# ============================================
# 3. Parser Configuration
# ============================================
NETWORK_INTERFACE=veth1
BPF_FILTER=
PARSER_MODE=realtime
ROLLING_INTERVAL=0
OUTPUT_DIR=/data/output
PARSER_THREADS=0

# ============================================
# 4. Logging
# ============================================
LOG_LEVEL=INFO

# ============================================
# 5. Resource Limits
# ============================================
PARSER_MEMORY_LIMIT=2g
PARSER_CPU_LIMIT=2.0
REDIS_MEMORY_LIMIT=512M

# ============================================
# 6. Advanced Options
# ============================================
ES_BULK_SIZE=100
ES_BULK_FLUSH_INTERVAL_MS=100
REDIS_STREAM_MAX_LEN=100000
REDIS_ASSET_CACHE_TTL=3600
EOF
    
    success ".env 파일이 생성되었습니다."
    warn "⚠️  .env 파일을 확인하고 필요한 설정을 수정하세요!"
    warn "특히 ELASTICSEARCH_HOST와 NETWORK_INTERFACE를 확인하세요."
    echo ""
    read -p "지금 바로 .env 파일을 수정하시겠습니까? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} "$ENV_FILE"
    fi
fi

# .env 파일 로드
set -a
source "$ENV_FILE"
set +a

success "환경 변수 로드 완료"

# ============================================
# 3. 설정 정보 표시
# ============================================
echo ""
header "=========================================="
header "  현재 설정 정보"
header "=========================================="
echo ""

info "📡 네트워크:"
echo "  - 캡처 인터페이스: ${NETWORK_INTERFACE}"
echo "  - BPF 필터: ${BPF_FILTER:-없음}"
echo ""

info "⚙️  Parser:"
echo "  - 모드: ${PARSER_MODE}"
echo "  - 워커 스레드: ${PARSER_THREADS:-자동}"
echo "  - 출력 디렉토리: ${OUTPUT_DIR}"
if [ "${PARSER_MODE}" = "with-files" ]; then
    echo "  - 롤링 간격: ${ROLLING_INTERVAL} 분"
fi
echo ""

info "🔴 Redis (로컬):"
echo "  - 호스트: ${REDIS_HOST}:${REDIS_PORT}"
echo "  - DB: ${REDIS_DB}"
echo "  - Pool 크기: ${REDIS_POOL_SIZE}"
echo "  - Async Writers: ${REDIS_ASYNC_WRITERS}"
echo ""

info "🟢 Elasticsearch (원격):"
echo "  - 호스트: ${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}"
echo "  - 인덱스 접두사: ${ELASTICSEARCH_INDEX_PREFIX}"
echo "  - Bulk 크기: ${ES_BULK_SIZE}"
echo "  - Flush 간격: ${ES_BULK_FLUSH_INTERVAL_MS}ms"
echo ""

info "💾 리소스 제한:"
echo "  - Parser 메모리: ${PARSER_MEMORY_LIMIT}"
echo "  - Parser CPU: ${PARSER_CPU_LIMIT}"
echo "  - Redis 메모리: ${REDIS_MEMORY_LIMIT}"
echo ""

read -p "이 설정으로 계속 진행하시겠습니까? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "취소되었습니다."
    info ".env 파일을 수정하려면: nano $ENV_FILE"
    exit 0
fi

# ============================================
# 4. 네트워크 인터페이스 확인
# ============================================
echo ""
info "사용 가능한 네트워크 인터페이스:"
if command -v ip &> /dev/null; then
    ip link show | grep -E "^[0-9]+:" | awk '{print "  - " $2}' | sed 's/:$//' | sed 's/@.*//'
fi
echo ""

if [ "${NETWORK_INTERFACE}" != "any" ]; then
    if ip link show "${NETWORK_INTERFACE}" > /dev/null 2>&1; then
        success "인터페이스 '${NETWORK_INTERFACE}' 확인됨"
    else
        error "인터페이스 '${NETWORK_INTERFACE}'를 찾을 수 없습니다!"
        warn "컨테이너 시작 후 'any'로 폴백됩니다."
        read -p "계속 진행하시겠습니까? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# ============================================
# 5. 원격 Elasticsearch 연결 확인
# ============================================
echo ""
info "원격 Elasticsearch 연결 테스트..."
ES_URL="http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}"

if curl -s --connect-timeout 5 "$ES_URL" > /dev/null 2>&1; then
    success "원격 Elasticsearch 연결 성공: $ES_URL"
    
    # 클러스터 정보 가져오기
    CLUSTER_INFO=$(curl -s "$ES_URL")
    ES_VERSION=$(echo "$CLUSTER_INFO" | grep -oP '"number"\s*:\s*"\K[^"]+' | head -1)
    CLUSTER_NAME=$(echo "$CLUSTER_INFO" | grep -oP '"cluster_name"\s*:\s*"\K[^"]+')
    
    if [ ! -z "$ES_VERSION" ]; then
        info "  - 클러스터: $CLUSTER_NAME"
        info "  - 버전: $ES_VERSION"
    fi
else
    error "⚠️  원격 Elasticsearch 연결 실패: $ES_URL"
    error "Dashboard PC가 실행 중인지, .env 파일의 IP 주소가 맞는지 확인하세요."
    read -p "연결에 실패했지만 강제로 진행하시겠습니까? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "취소되었습니다."
        exit 1
    fi
fi

# ============================================
# 6. 디렉토리 확인
# ============================================
PARSER_DIR="$PROJECT_ROOT/Parser"
if [ ! -d "$PARSER_DIR" ]; then
    error "Parser 디렉토리가 없습니다: $PARSER_DIR"
    exit 1
fi

if [ ! -d "$PARSER_DIR/build" ] || [ ! -f "$PARSER_DIR/build/parser" ]; then
    error "Parser 바이너리가 없습니다: $PARSER_DIR/build/parser"
    error "먼저 Parser를 빌드하세요: cd $PARSER_DIR && mkdir -p build && cd build && cmake .. && make"
    exit 1
fi

success "Parser 바이너리 확인"

if [ -d "$PARSER_DIR/assets" ]; then
    ASSET_COUNT=$(ls -1 "$PARSER_DIR/assets"/*.csv 2>/dev/null | wc -l)
    success "Assets 디렉토리 확인 (${ASSET_COUNT}개 CSV 파일)"
else
    warn "Assets 디렉토리가 없습니다 (자산 매핑 불가)"
fi

# ============================================
# 7. 기존 컨테이너 확인 및 정리
# ============================================
echo ""
info "기존 컨테이너 상태 확인..."
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

if docker-compose -f "$COMPOSE_FILE" ps 2>/dev/null | grep -q "Up"; then
    warn "실행 중인 컨테이너가 있습니다."
    docker-compose -f "$COMPOSE_FILE" ps
    echo ""
    read -p "기존 컨테이너를 중지하고 새로 시작하시겠습니까? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "기존 컨테이너 중지 중..."
        docker-compose -f "$COMPOSE_FILE" down
        success "중지 완료"
    else
        info "취소되었습니다."
        exit 0
    fi
fi

# ============================================
# 8. Docker Compose 실행
# ============================================
echo ""
header "=========================================="
header "  컨테이너 시작"
header "=========================================="
echo ""

info "컨테이너 빌드 및 시작 중..."
docker-compose -f "$COMPOSE_FILE" up -d --build

if [ $? -ne 0 ]; then
    error "컨테이너 시작 실패!"
    exit 1
fi

# ============================================
# 9. 서비스 시작 대기
# ============================================
echo ""
info "서비스 초기화 대기 중..."

info "Redis 시작 대기..."
for i in {1..12}; do
    if docker exec redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
        success "Redis 준비 완료 (${i}초)"
        break
    fi
    echo -n "."
    sleep 1
done
echo ""

info "Parser 초기화 대기 (10초)..."
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
    success "Redis: 정상"
else
    error "Redis: 비정상"
fi

# Parser
if docker-compose -f "$COMPOSE_FILE" ps 2>/dev/null | grep "parser" | grep -q "Up"; then
    success "Parser: 실행 중"
    
    sleep 2
    PARSER_LOGS=$(docker-compose -f "$COMPOSE_FILE" logs parser 2>/dev/null | tail -20)
    
    if echo "$PARSER_LOGS" | grep -q "Starting packet capture"; then
        success "  ✓ 패킷 캡처 시작됨"
    fi
    
    if echo "$PARSER_LOGS" | grep -q "Redis connection established"; then
        success "  ✓ Redis 연결 성공"
    fi
    
    if echo "$PARSER_LOGS" | grep -q "Elasticsearch connection established"; then
        success "  ✓ Elasticsearch 연결 성공"
    fi
    
    if echo "$PARSER_LOGS" | grep -qi "error\|failed"; then
        warn "  ⚠️  로그에서 에러 감지됨 (상세 확인 필요)"
    fi
else
    error "Parser: 중지됨"
    error "로그를 확인하세요:"
    docker-compose -f "$COMPOSE_FILE" logs parser
fi

# ============================================
# 11. 서비스 상태 출력
# ============================================
echo ""
header "=========================================="
header "  서비스 상태"
header "=========================================="
echo ""
docker-compose -f "$COMPOSE_FILE" ps

# ============================================
# 12. 데이터 흐름 확인
# ============================================
echo ""
info "데이터 전송 확인 중 (15초 대기)..."
sleep 15

# Redis Stream 확인
STREAM_COUNT=0
for protocol in modbus_tcp s7comm xgt-fen dnp3 dns; do
    STREAM_NAME="stream:protocol:${protocol}"
    LEN=$(docker exec redis redis-cli XLEN "$STREAM_NAME" 2>/dev/null || echo "0")
    if [ "$LEN" != "0" ] && [ ! -z "$LEN" ]; then
        STREAM_COUNT=$((STREAM_COUNT + 1))
    fi
done

if [ $STREAM_COUNT -gt 0 ]; then
    success "Redis Stream에 데이터가 있습니다 (${STREAM_COUNT}개 프로토콜)"
else
    warn "Redis Stream에 아직 데이터가 없습니다"
fi

# Elasticsearch 인덱스 확인
if curl -s "$ES_URL/_cat/indices?v" 2>/dev/null | grep -q "${ELASTICSEARCH_INDEX_PREFIX}"; then
    success "Elasticsearch에 '${ELASTICSEARCH_INDEX_PREFIX}' 인덱스가 생성되었습니다!"
    
    # 문서 수 확인
    DOC_COUNT=$(curl -s "$ES_URL/${ELASTICSEARCH_INDEX_PREFIX}-*/_count" 2>/dev/null | grep -oP '"count"\s*:\s*\K[0-9]+')
    if [ ! -z "$DOC_COUNT" ] && [ "$DOC_COUNT" -gt 0 ]; then
        success "  총 ${DOC_COUNT}개 문서 인덱싱됨"
    fi
else
    warn "Elasticsearch에 아직 '${ELASTICSEARCH_INDEX_PREFIX}' 인덱스가 없습니다"
    warn "네트워크 트래픽이 발생하고 있는지 확인하세요"
fi

# ============================================
# 13. 최종 안내
# ============================================
echo ""
header "=========================================="
header "  시스템 시작 완료!"
header "=========================================="
echo ""

info "📊 데이터 확인 (Dashboard PC):"
echo "  - Kibana:   http://${ELASTICSEARCH_HOST}:5601"
echo "  - Backend:  http://${ELASTICSEARCH_HOST}:8080"
echo "  - Frontend: http://${ELASTICSEARCH_HOST}:5173"
echo ""

info "🔌 서비스 엔드포인트:"
echo "  - Redis (로컬):           localhost:${REDIS_PORT}"
echo "  - Elasticsearch (원격):   $ES_URL"
echo ""

info "📡 데이터 흐름:"
echo "  Network (${NETWORK_INTERFACE}) → Parser (${PARSER_MODE}) → Redis + Elasticsearch"
echo ""

info "📝 유용한 명령어:"
echo "  # 실시간 로그 보기"
echo "  docker-compose -f $COMPOSE_FILE logs -f parser"
echo ""
echo "  # Redis 통계 확인"
echo "  docker exec redis redis-cli INFO stats"
echo ""
echo "  # Redis Stream 확인"
echo "  docker exec redis redis-cli XLEN stream:protocol:modbus_tcp"
echo ""
echo "  # Elasticsearch 인덱스 확인"
echo "  curl -s $ES_URL/_cat/indices?v | grep ics-packets"
echo ""
echo "  # 시스템 중지"
echo "  docker-compose -f $COMPOSE_FILE down"
echo ""

info "⚙️  설정 변경:"
echo "  nano $ENV_FILE"
echo ""

# ============================================
# 14. 실시간 모니터링 선택
# ============================================
read -p "실시간 파서 로그를 확인하시겠습니까? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    header "=========================================="
    header "  실시간 로그 모니터링 (Ctrl+C로 종료)"
    header "=========================================="
    echo ""
    sleep 2
    docker-compose -f "$COMPOSE_FILE" logs -f parser
fi

echo ""
success "스크립트 종료"
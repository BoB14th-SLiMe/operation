#!/bin/bash

# ============================================
# Elasticsearch 연결 및 데이터 확인 스크립트
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
cd "$SCRIPT_DIR"

# .env 파일 로드
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
    success ".env 파일 로드 완료"
else
    error ".env 파일을 찾을 수 없습니다!"
    exit 1
fi

ES_HOST="${ELASTICSEARCH_HOST:-100.126.141.58}"
ES_PORT="${ELASTICSEARCH_PORT:-9200}"
ES_URL="http://${ES_HOST}:${ES_PORT}"
INDEX_PREFIX="${ELASTICSEARCH_INDEX_PREFIX:-ics-packets}"

clear
echo ""
header "=========================================="
header "  Elasticsearch 연결 테스트"
header "=========================================="
echo ""

# ============================================
# 1. Elasticsearch 연결 확인
# ============================================
echo ""
info "1️⃣  Elasticsearch 연결 확인..."
echo "  - URL: $ES_URL"
echo ""

if curl -s --connect-timeout 5 "$ES_URL" > /dev/null 2>&1; then
    success "✅ Elasticsearch 연결 성공!"
    
    # 클러스터 정보
    CLUSTER_INFO=$(curl -s "$ES_URL")
    ES_VERSION=$(echo "$CLUSTER_INFO" | grep -oP '"number"\s*:\s*"\K[^"]+' | head -1)
    CLUSTER_NAME=$(echo "$CLUSTER_INFO" | grep -oP '"cluster_name"\s*:\s*"\K[^"]+')
    
    info "  - Cluster: $CLUSTER_NAME"
    info "  - Version: $ES_VERSION"
    echo ""
else
    error "❌ Elasticsearch 연결 실패!"
    error "Dashboard PC가 실행 중인지, IP 주소가 올바른지 확인하세요."
    exit 1
fi

# ============================================
# 2. 인덱스 확인
# ============================================
echo ""
info "2️⃣  ICS 패킷 인덱스 확인..."
echo "  - Index Pattern: ${INDEX_PREFIX}-*"
echo ""

INDICES=$(curl -s "$ES_URL/_cat/indices?v" | grep "$INDEX_PREFIX")

if [ -z "$INDICES" ]; then
    warn "⚠️  '${INDEX_PREFIX}' 인덱스가 아직 생성되지 않았습니다."
    warn "Parser가 실행 중이고 네트워크 트래픽이 있는지 확인하세요."
    echo ""
else
    success "✅ 인덱스 발견!"
    echo ""
    echo "$INDICES" | while read line; do
        echo "  $line"
    done
    echo ""
fi

# ============================================
# 3. 문서 수 확인
# ============================================
echo ""
info "3️⃣  인덱싱된 문서 수 확인..."
echo ""

DOC_COUNT=$(curl -s "$ES_URL/${INDEX_PREFIX}-*/_count" 2>/dev/null | grep -oP '"count"\s*:\s*\K[0-9]+')

if [ ! -z "$DOC_COUNT" ]; then
    if [ "$DOC_COUNT" -gt 0 ]; then
        success "✅ 총 ${DOC_COUNT}개 문서가 인덱싱되었습니다!"
    else
        warn "⚠️  인덱스는 있지만 문서가 없습니다. (0개)"
    fi
else
    warn "⚠️  문서 수를 확인할 수 없습니다."
fi
echo ""

# ============================================
# 4. 프로토콜별 통계
# ============================================
if [ ! -z "$DOC_COUNT" ] && [ "$DOC_COUNT" -gt 0 ]; then
    echo ""
    info "4️⃣  프로토콜별 통계..."
    echo ""
    
    PROTOCOLS=("modbus_tcp" "s7comm" "xgt-fen" "dnp3" "dns" "arp" "tcp_session")
    
    for protocol in "${PROTOCOLS[@]}"; do
        COUNT=$(curl -s -X POST "$ES_URL/${INDEX_PREFIX}-*/_count" \
            -H 'Content-Type: application/json' \
            -d "{\"query\":{\"match\":{\"protocol\":\"$protocol\"}}}" 2>/dev/null \
            | grep -oP '"count"\s*:\s*\K[0-9]+')
        
        if [ ! -z "$COUNT" ] && [ "$COUNT" -gt 0 ]; then
            printf "  %-20s: %'10d packets\n" "$protocol" "$COUNT"
        fi
    done
    echo ""
fi

# ============================================
# 5. 최근 문서 샘플
# ============================================
if [ ! -z "$DOC_COUNT" ] && [ "$DOC_COUNT" -gt 0 ]; then
    echo ""
    info "5️⃣  최근 문서 샘플 (최근 3개)..."
    echo ""
    
    SAMPLE=$(curl -s -X POST "$ES_URL/${INDEX_PREFIX}-*/_search" \
        -H 'Content-Type: application/json' \
        -d '{
            "size": 3,
            "sort": [{"@timestamp": {"order": "desc"}}],
            "_source": ["@timestamp", "protocol", "src_ip", "dst_ip", "src_port", "dst_port"]
        }' 2>/dev/null)
    
    echo "$SAMPLE" | python3 -m json.tool 2>/dev/null | grep -A 20 "hits" || \
        echo "  (샘플 데이터를 파싱할 수 없습니다)"
    
    echo ""
fi

# ============================================
# 6. Parser 상태 확인
# ============================================
echo ""
info "6️⃣  Parser 컨테이너 상태..."
echo ""

if docker ps --format "{{.Names}}" | grep -q "ot-security-parser"; then
    success "✅ Parser 컨테이너 실행 중"
    
    # 최근 로그 확인
    echo ""
    info "Parser 최근 로그 (마지막 10줄):"
    echo ""
    docker logs --tail 10 ot-security-parser 2>/dev/null | sed 's/^/  /'
    echo ""
else
    warn "⚠️  Parser 컨테이너가 실행 중이지 않습니다!"
    echo ""
    info "다음 명령으로 시작하세요:"
    echo "  cd $SCRIPT_DIR"
    echo "  docker-compose up -d"
    echo ""
fi

# ============================================
# 7. Redis 상태 확인
# ============================================
echo ""
info "7️⃣  Redis 상태 확인..."
echo ""

if docker exec ot-security-redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
    success "✅ Redis 정상 작동"
    
    # Stream 확인
    echo ""
    info "Redis Stream 상태:"
    for protocol in modbus_tcp s7comm xgt-fen dnp3 dns; do
        STREAM_LEN=$(docker exec ot-security-redis redis-cli XLEN "stream:protocol:${protocol}" 2>/dev/null || echo "0")
        if [ "$STREAM_LEN" != "0" ] && [ ! -z "$STREAM_LEN" ]; then
            printf "  %-20s: %'10d messages\n" "$protocol" "$STREAM_LEN"
        fi
    done
    echo ""
else
    warn "⚠️  Redis가 응답하지 않습니다!"
    echo ""
fi

# ============================================
# 8. 종합 결과
# ============================================
echo ""
header "=========================================="
header "  종합 결과"
header "=========================================="
echo ""

# Elasticsearch
if [ ! -z "$DOC_COUNT" ] && [ "$DOC_COUNT" -gt 0 ]; then
    success "✅ Elasticsearch: 정상 (${DOC_COUNT}개 문서)"
else
    warn "⚠️  Elasticsearch: 데이터 없음 또는 연결 실패"
fi

# Parser
if docker ps --format "{{.Names}}" | grep -q "ot-security-parser"; then
    success "✅ Parser: 실행 중"
else
    warn "⚠️  Parser: 중지됨"
fi

# Redis
if docker exec ot-security-redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
    success "✅ Redis: 정상"
else
    warn "⚠️  Redis: 비정상"
fi

echo ""
header "=========================================="
echo ""

# ============================================
# 9. 유용한 명령어
# ============================================
info "📝 유용한 명령어:"
echo ""
echo "  # Elasticsearch 인덱스 확인"
echo "  curl -s $ES_URL/_cat/indices?v | grep ics-packets"
echo ""
echo "  # 문서 수 확인"
echo "  curl -s $ES_URL/${INDEX_PREFIX}-*/_count"
echo ""
echo "  # 최근 10개 문서 검색"
echo "  curl -s -X POST $ES_URL/${INDEX_PREFIX}-*/_search -H 'Content-Type: application/json' -d '{\"size\":10,\"sort\":[{\"@timestamp\":{\"order\":\"desc\"}}]}'"
echo ""
echo "  # Parser 실시간 로그"
echo "  docker logs -f ot-security-parser"
echo ""
echo "  # Redis 모니터링"
echo "  docker exec -it ot-security-redis redis-cli MONITOR"
echo ""
echo "  # 이 스크립트 다시 실행"
echo "  ./test-elasticsearch.sh"
echo ""

success "테스트 완료!"
#!/bin/bash

# ============================================
# Elasticsearch 연동 테스트 스크립트
# ============================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} e$1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

test_step() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# ============================================
# 작업 디렉토리 확인
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$SCRIPT_DIR"

# ============================================
# 환경 변수 로드
# ============================================
if [ -f .env ]; then
    source .env
else
    warn ".env 파일이 없습니다. 기본값을 사용합니다."
    ELASTICSEARCH_HOST="100.126.141.58"
    ELASTICSEARCH_PORT="9200"
fi

info "=========================================="
info "Elasticsearch 연동 테스트 시작"
info "=========================================="
info "Elasticsearch: ${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}"
echo ""

# ============================================
# 1. Elasticsearch 연결 테스트
# ============================================
test_step "1. Elasticsearch 연결 테스트"
if curl -s "http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}" > /dev/null 2>&1; then
    info "✓ Elasticsearch 연결 성공"
    curl -s "http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}" | jq '.' 2>/dev/null || curl -s "http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}"
else
    error "✗ Elasticsearch 연결 실패"
    error "Dashboard PC의 Elasticsearch가 실행 중인지 확인하세요."
    exit 1
fi
echo ""

# ============================================
# 2. Parser 컨테이너 확인
# ============================================
test_step "2. Parser 컨테이너 확인"
if docker-compose ps cpp-parser | grep -q "Up"; then
    info "✓ Parser 컨테이너 실행 중"
else
    warn "✗ Parser 컨테이너가 실행되지 않았습니다."
    read -p "Parser를 시작하시겠습니까? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose up -d cpp-parser
        sleep 5
    else
        exit 1
    fi
fi
echo ""

# ============================================
# 3. JSONL Sender 확인
# ============================================
test_step "3. JSONL Sender 확인"
if docker-compose ps jsonl-sender | grep -q "Up"; then
    info "✓ JSONL Sender 실행 중"
else
    warn "✗ JSONL Sender가 실행되지 않았습니다."
    read -p "JSONL Sender를 시작하시겠습니까? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose up -d jsonl-sender
        sleep 5
    else
        exit 1
    fi
fi
echo ""

# ============================================
# 4. 테스트 JSONL 파일 생성
# ============================================
test_step "4. 테스트 JSONL 파일 생성"
info "테스트 데이터 생성 중..."

docker exec ot-security-cpp-parser sh -c 'cat > /data/parser-output/test_$(date +%Y%m%d_%H%M%S).jsonl << "EOF"
{"timestamp":"2025-01-03T10:00:00Z","src_ip":"192.168.1.10","dst_ip":"192.168.1.20","protocol":"TCP","src_port":12345,"dst_port":80,"bytes":1024,"severity":"low","description":"Normal HTTP traffic"}
{"timestamp":"2025-01-03T10:00:01Z","src_ip":"192.168.1.11","dst_ip":"192.168.1.21","protocol":"UDP","src_port":53123,"dst_port":53,"bytes":512,"severity":"low","description":"DNS query"}
{"timestamp":"2025-01-03T10:00:02Z","src_ip":"192.168.1.12","dst_ip":"192.168.1.22","protocol":"TCP","src_port":44321,"dst_port":443,"bytes":2048,"severity":"medium","description":"HTTPS traffic"}
{"timestamp":"2025-01-03T10:00:03Z","src_ip":"192.168.1.13","dst_ip":"192.168.1.23","protocol":"TCP","src_port":23456,"dst_port":22,"bytes":4096,"severity":"high","description":"SSH connection"}
{"timestamp":"2025-01-03T10:00:04Z","src_ip":"10.0.0.100","dst_ip":"192.168.1.24","protocol":"TCP","src_port":65000,"dst_port":3389,"bytes":8192,"severity":"critical","description":"Suspicious RDP access"}
EOF'

info "✓ 테스트 JSONL 파일 생성 완료"

# 파일 확인
info "생성된 파일 목록:"
docker exec ot-security-cpp-parser ls -lh /data/parser-output/
echo ""

# ============================================
# 5. Sender 로그 확인
# ============================================
test_step "5. JSONL Sender 로그 확인 (10초 대기)"
sleep 10
docker-compose logs --tail=20 jsonl-sender
echo ""

# ============================================
# 6. Elasticsearch 인덱스 확인
# ============================================
test_step "6. Elasticsearch 인덱스 확인"
info "생성된 인덱스 목록:"
curl -s "http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/_cat/indices?v" | grep ot-security || warn "아직 인덱스가 생성되지 않았습니다."
echo ""

# ============================================
# 7. 데이터 개수 확인
# ============================================
test_step "7. Elasticsearch 데이터 개수 확인"
COUNT=$(curl -s "http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/ot-security-packets-*/_count" 2>/dev/null | jq -r '.count' 2>/dev/null || echo "0")
if [ "$COUNT" -gt 0 ]; then
    info "✓ 저장된 문서 수: ${COUNT}개"
else
    warn "⚠️  저장된 문서가 없습니다. 잠시 후 다시 확인하세요."
fi
echo ""

# ============================================
# 8. 샘플 데이터 조회
# ============================================
test_step "8. 샘플 데이터 조회 (최근 5개)"
curl -s -X GET "http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/ot-security-packets-*/_search" \
  -H 'Content-Type: application/json' \
  -d '{
    "size": 5,
    "sort": [{"@timestamp": "desc"}],
    "query": {"match_all": {}}
  }' 2>/dev/null | jq '.hits.hits[] | {timestamp: ._source["@timestamp"], src_ip: ._source.src_ip, dst_ip: ._source.dst_ip, severity: ._source.severity}' 2>/dev/null || warn "데이터 조회 실패"
echo ""

# ============================================
# 9. 심각도별 통계
# ============================================
test_step "9. 심각도별 통계"
curl -s -X GET "http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/ot-security-packets-*/_search" \
  -H 'Content-Type: application/json' \
  -d '{
    "size": 0,
    "aggs": {
      "severity_stats": {
        "terms": {
          "field": "severity.keyword",
          "size": 10
        }
      }
    }
  }' 2>/dev/null | jq '.aggregations.severity_stats.buckets[] | {severity: .key, count: .doc_count}' 2>/dev/null || warn "통계 조회 실패"
echo ""

# ============================================
# 10. 결과 요약
# ============================================
info "=========================================="
info "테스트 결과 요약"
info "=========================================="

# Parser 상태
if docker-compose ps cpp-parser | grep -q "Up"; then
    info "✓ Parser: 실행 중"
else
    error "✗ Parser: 중지됨"
fi

# Sender 상태
if docker-compose ps jsonl-sender | grep -q "Up"; then
    info "✓ JSONL Sender: 실행 중"
else
    error "✗ JSONL Sender: 중지됨"
fi

# Elasticsearch 연결
if curl -s "http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}" > /dev/null 2>&1; then
    info "✓ Elasticsearch: 연결됨"
else
    error "✗ Elasticsearch: 연결 실패"
fi

# 데이터 확인
COUNT=$(curl -s "http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/ot-security-packets-*/_count" 2>/dev/null | jq -r '.count' 2>/dev/null || echo "0")
if [ "$COUNT" -gt 0 ]; then
    info "✓ 데이터: ${COUNT}개 문서 저장됨"
else
    warn "⚠️  데이터: 아직 저장되지 않음"
fi

echo ""
info "=========================================="
info "모니터링 명령어"
info "=========================================="
info "Parser 로그:       docker-compose logs -f cpp-parser"
info "Sender 로그:       docker-compose logs -f jsonl-sender"
info "Elasticsearch 쿼리:"
echo "  curl -X GET \"http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/ot-security-packets-*/_search?pretty\""
echo ""

info "테스트 완료!"

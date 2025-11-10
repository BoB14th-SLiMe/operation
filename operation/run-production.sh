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
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${CYAN}[✓]${NC} $1"; }

# ============================================
# 작업 디렉토리 확인
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

info "스크립트 위치 (SCRIPT_DIR): $SCRIPT_DIR"
info "프로젝트 루트 (PROJECT_ROOT): $PROJECT_ROOT"
cd "$SCRIPT_DIR"

# ============================================
# 1. 사전 확인 (Docker, Root)
# ============================================
clear
echo ""
info "=========================================="
info "  실시간 ICS 파서 스택 (AI PC) 시작"
info "=========================================="
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
# 2. 디렉토리 및 파일 확인
# ============================================
info "프로젝트 구조 확인 중..."

COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
    error "docker-compose.yml 파일이 없습니다: $COMPOSE_FILE"
    exit 1
fi
success "$COMPOSE_FILE 확인"

PARSER_DIR="$PROJECT_ROOT/Parser"
if [ ! -d "$PARSER_DIR" ]; then
    error "Parser 디렉토리가 없습니다: $PARSER_DIR"
    exit 1
fi
success "Parser 디렉토리 확인"

if [ -d "$PARSER_DIR/assets" ]; then
    success "Assets 디렉토리 확인"
else
    warn "Assets 디렉토리가 없습니다 (자산 매핑 불가)"
fi

# ============================================
# 3. 환경 변수 설정 (.env)
# ============================================
ENV_FILE="$PROJECT_ROOT/operation/.env"
if [ ! -f "$ENV_FILE" ]; then
    info ".env 파일이 없어 기본값($ENV_FILE)으로 생성합니다."
    warn "--- !!! 중요 !!! ---"
    warn "ELASTICSEARCH_HOST를 Dashboard PC의 IP로 수정해야 합니다."
    cat > "$ENV_FILE" <<EOF
# --- Dashboard PC 정보 ---
# Dashboard PC에서 실행 중인 Elasticsearch의 IP 주소를 입력하세요.
ELASTICSEARCH_HOST=100.126.141.58
ELASTICSEARCH_PORT=9200

# --- AI PC (현재 장비) 설정 ---
CAPTURE_INTERFACE=eth0
EOF
    success ".env 생성 완료. $ENV_FILE 파일을 수정하세요."
    read -p "지금 바로 수정하시겠습니까? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} "$ENV_FILE"
    fi
fi
source "$ENV_FILE"

success "환경 변수 로드 완료"

# ============================================
# 4. 네트워크 인터페이스 확인
# ============================================
info "사용 가능한 네트워크 인터페이스:"
if command -v ip &> /dev/null; then
    ip link show | grep -E "^[0-9]+:" | awk '{print "  - " $2}' | sed 's/:$//'
fi
echo ""
read -p "캡처할 인터페이스를 변경하시겠습니까? (현재: ${CAPTURE_INTERFACE:-eth0}) (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "인터페이스 이름 입력: " NEW_INTERFACE
    if [ ! -z "$NEW_INTERFACE" ]; then
        sed -i "s/^CAPTURE_INTERFACE=.*/CAPTURE_INTERFACE=$NEW_INTERFACE/" "$ENV_FILE"
        CAPTURE_INTERFACE="$NEW_INTERFACE"
        success "인터페이스 변경: $CAPTURE_INTERFACE"
        source "$ENV_FILE"
    fi
fi

# ============================================
# 5. 원격 Elasticsearch 연결 확인
# ============================================
info "원격 Elasticsearch 연결 테스트 ($ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT)..."
ES_URL="http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}"

if ! curl -s --connect-timeout 5 "$ES_URL" > /dev/null 2>&1; then
    error "⚠️  원격 Elasticsearch 연결 실패: $ES_URL"
    error "Dashboard PC가 실행 중인지, .env 파일의 IP 주소가 맞는지 확인하세요."
    read -p "연결에 실패했지만 강제로 진행하시겠습니까? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "취소되었습니다."
        exit 1
    fi
else
    success "원격 Elasticsearch 연결 성공: $ES_URL"
fi

# ============================================
# 6. 기존 컨테이너 확인 및 정리
# ============================================
info "기존 컨테이너 상태 확인..."
if docker-compose -f "$COMPOSE_FILE" ps 2>/dev/null | grep -q "Up"; then
    warn "실행 중인 파서 스택(parser, redis) 컨테이너가 있습니다."
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
# 7. Docker Compose 실행 (parser, redis)
# ============================================
echo ""
info "=========================================="
info "  AI PC 스택 (Parser, Redis) 시작"
info "=========================================="
echo ""

info "컨테이너 빌드 및 시작 중..."
docker-compose -f "$COMPOSE_FILE" up -d --build

# ============================================
# 8. 서비스 시작 대기
# ============================================
info "서비스 시작 대기 중..."

# ES, Kibana 대기 제거

info "Redis 시작 대기 중..."
for i in {1..6}; do
    if docker exec redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
        success "Redis 준비 완료 (${i}5초)"
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

info "Parser 초기화 대기 중 (10초)..."
sleep 10

# ============================================
# 9. 헬스체크
# ============================================
echo ""
info "=========================================="
info "  헬스체크 (AI PC)"
info "=========================================="
echo ""

if docker exec redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
    success "Redis (로컬): 정상"
else
    error "Redis (로컬): 비정상"
fi

# ES, Kibana 로컬 헬스체크 제거

if docker-compose -f "$COMPOSE_FILE" ps 2>/dev/null | grep "parser" | grep -q "Up"; then
    success "Parser (로컬): 실행 중"
    sleep 2
    if docker-compose -f "$COMPOSE_FILE" logs parser 2>/dev/null | grep -q "Starting packet capture"; then
        success "  패킷 캡처 시작됨"
    elif docker-compose -f "$COMPOSE_FILE" logs parser 2>/dev/null | grep -q "ERROR"; then
        warn "  초기화 중 에러 발생 (로그 확인 필요)"
    fi
else
    error "Parser (로컬): 중지됨"
    docker-compose -f "$COMPOSE_FILE" logs parser
fi

# ============================================
# 10. 서비스 상태 출력
# ============================================
echo ""
info "=========================================="
info "  서비스 상태 (AI PC)"
info "=========================================="
docker-compose -f "$COMPOSE_FILE" ps

# ============================================
# 11. 데이터 흐름 확인
# ============================================
echo ""
info "원격 데이터 전송 확인 중 (10초 대기)..."
sleep 10

if curl -s "$ES_URL/_cat/indices?v" 2>/dev/null | grep -q "ics-packets"; then
    success "원격 Elasticsearch($ES_URL)에 'ics-packets' 인덱스가 생성되었습니다!"
else
    warn "아직 원격 Elasticsearch에 'ics-packets' 인덱스가 없습니다."
    warn "네트워크 트래픽이 발생하고 있는지, Parser 로그에 에러가 없는지 확인하세요."
fi

# ============================================
# 12. 접속 정보
# ============================================
echo ""
info "=========================================="
info "  AI PC 시스템 시작 완료!"
info "=========================================="
echo ""
info "📊 데이터 확인 (Dashboard PC):"
info "  - Kibana:   http://(Dashboard PC IP):5601"
info "  - Backend:  http://(Dashboard PC IP):8080"
info "  - Frontend: http://(Dashboard PC IP):5173"
echo ""
info "🔌 서비스 엔드포인트:"
info "  - Redis (로컬):           localhost:6379"
info "  - Elasticsearch (원격):   $ES_URL"
echo ""
info "📡 데이터 흐름:"
info "  Network (${CAPTURE_INTERFACE}) → Parser (AI PC) → (로컬 Redis) + (원격 Elasticsearch)"
echo ""
info "📝 로그 확인 (AI PC):"
info "  docker-compose -f $COMPOSE_FILE logs -f parser"
echo ""
info "🛑 시스템 종료 (AI PC):"
info "  docker-compose -f $COMPOSE_FILE down"
echo ""

# ============================================
# 13. 실시간 모니터링 선택
# ============================================
read -p "실시간 파서 로그를 확인하시겠습니까? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    info "=========================================="
    info "실시간 로그 모니터링 (Ctrl+C로 종료)"
    info "=========================================="
    sleep 2
    docker-compose -f "$COMPOSE_FILE" logs -f parser
fi

echo ""
success "스크립트 종료"
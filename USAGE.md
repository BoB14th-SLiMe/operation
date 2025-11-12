# OT Security Monitoring System - 전체 사용 가이드

## 📋 목차
1. [시스템 개요](#시스템-개요)
2. [테스트 환경 구성](#테스트-환경-구성)
3. [운영 환경 구성](#운영-환경-구성)
4. [모니터링 및 관리](#모니터링-및-관리)
5. [트러블슈팅](#트러블슈팅)

---

## 시스템 개요

이 시스템은 OT(Operational Technology) 환경의 네트워크 트래픽을 실시간으로 분석하여 위협을 탐지합니다.

### 주요 구성요소
- **Parser**: C++ 기반 고성능 패킷 파서
- **Redis**: 실시간 데이터 스트리밍 및 캐싱
- **Elasticsearch**: 데이터 저장 및 대시보드 연동

### 지원 프로토콜
- Modbus TCP
- S7comm (Siemens)
- XGT FEnet (LS Electric)
- DNP3, MMS, ARP, DNS 등

---

## 테스트 환경 구성

실제 네트워크 트래픽이 없는 환경에서 테스트하기 위한 구성입니다.

### 1단계: PCAP 파일 재생 시작

```bash
cd /home/ryuoo0/security

# PCAP 재생 시작
sudo nohup ./replay_loop.sh > /dev/null 2>&1 &

# 프로세스 확인
ps aux | grep replay_loop
```

**재생되는 트래픽:**
- `Parser/pcap/normal.pcap` → 정상 OT 트래픽
- `Parser/pcap/attack_01.pcap` → 공격 트래픽

**재생 순서:**
```
normal.pcap (재생) → attack_01.pcap (재생) → normal.pcap (재생) → ...
```

### 2단계: Parser 시작

```bash
# 환경 변수 확인 (.env 파일)
cat .env | grep NETWORK_INTERFACE
# NETWORK_INTERFACE=veth1 (replay_loop.sh와 동일해야 함)

# Docker Compose로 시작
./start.sh
# 또는
docker-compose up -d --build
```

### 3단계: 동작 확인

```bash
# Parser 로그 확인
docker-compose logs -f parser

# 예상 출력:
# [Redis] ✓ Sent 1000 records to streams
# [Elasticsearch] ✓ Queued 1000 documents to bulk
# [Elasticsearch] ✓ Sent 1000 documents
```

### 4단계: 재생 중지 (필요 시)

```bash
# PCAP 재생 중지
sudo pkill -f replay_loop.sh

# Parser 중지
docker-compose stop
```

---

## 운영 환경 구성

실제 네트워크 트래픽을 캡처하여 분석하는 구성입니다.

### 1단계: 네트워크 인터페이스 확인

```bash
# 사용 가능한 인터페이스 확인
ip link show

# 예시 출력:
# 1: lo: <LOOPBACK,UP,LOWER_UP>
# 2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP>
# 3: veth1@veth0: <BROADCAST,MULTICAST,UP,LOWER_UP>
```

### 2단계: 환경 설정

`.env` 파일 수정:

```bash
nano .env
```

**주요 설정 항목:**
```bash
# 실제 트래픽 캡처를 위한 인터페이스
NETWORK_INTERFACE=eth0        # 또는 any (모든 인터페이스)

# 파서 모드
PARSER_MODE=realtime          # 실시간 모드 (파일 출력 없음)
# PARSER_MODE=with-files      # 파일 출력 포함

# Elasticsearch (원격 서버)
ELASTICSEARCH_HOST=100.126.141.58
ELASTICSEARCH_PORT=9200

# 성능 튜닝 (필요 시)
PARSER_THREADS=0              # 0=자동 (CPU 코어 수에 따라 자동 결정)
PARSER_MEMORY_LIMIT=2g        # 메모리 제한
```

### 3단계: 시스템 시작

```bash
# 빌드 및 시작
docker-compose up -d --build

# 로그 모니터링
docker-compose logs -f parser
```

### 4단계: 프로덕션 모니터링

```bash
# 실시간 통계 확인
docker-compose logs parser | grep -E "(Redis|Elasticsearch).*✓"

# Redis Stream 확인
docker-compose exec redis redis-cli
> KEYS stream:protocol:*
> XLEN stream:protocol:modbus
> XREAD COUNT 10 STREAMS stream:protocol:modbus 0

# 컨테이너 상태 확인
docker-compose ps
docker stats
```

---

## 모니터링 및 관리

### 실시간 로그 모니터링

```bash
# Parser 로그만
docker-compose logs -f parser

# 모든 서비스 로그
docker-compose logs -f

# 성공 메시지만 필터링
docker-compose logs parser | grep "✓"

# 에러 메시지만 필터링
docker-compose logs parser | grep -E "(ERROR|WARN)"
```

### 성능 모니터링

```bash
# 리소스 사용량 실시간 확인
docker stats

# Parser 컨테이너만
docker stats ot-parser

# Redis 메모리 사용량
docker-compose exec redis redis-cli INFO memory
```

### 데이터 확인

#### Redis Stream 데이터
```bash
docker-compose exec redis redis-cli

# 프로토콜별 Stream 목록
KEYS stream:protocol:*

# Modbus 데이터 확인
XLEN stream:protocol:modbus
XREAD COUNT 5 STREAMS stream:protocol:modbus 0

# XGT FEnet 데이터 확인
XREAD COUNT 5 STREAMS stream:protocol:xgt_fen 0
```

#### 출력 파일 (with-files 모드)
```bash
# CSV 파일 확인
head -20 output/output_all.csv

# JSONL 파일 확인 (jq 필요)
head -5 output/output_all.jsonl | jq

# 프로토콜별 통계
grep -o '"protocol":"[^"]*"' output/output_all.jsonl | sort | uniq -c
```

### 서비스 관리

```bash
# 재시작
docker-compose restart parser

# 중지
docker-compose stop

# 시작
docker-compose start

# 완전 제거 (데이터 유지)
docker-compose down

# 완전 제거 (데이터 삭제)
docker-compose down -v

# 재빌드
docker-compose up -d --build
```

---

## 트러블슈팅

### Parser가 패킷을 캡처하지 못하는 경우

**원인:** 네트워크 인터페이스 설정 오류

```bash
# 1. 실제 인터페이스 확인
ip link show

# 2. .env 파일 확인
grep NETWORK_INTERFACE .env

# 3. 설정 변경 후 재시작
nano .env
docker-compose restart parser
```

### Redis 연결 실패

```bash
# Redis 상태 확인
docker-compose ps redis

# Redis 로그 확인
docker-compose logs redis

# Redis 재시작
docker-compose restart redis

# 연결 테스트
docker-compose exec redis redis-cli ping
# 정상: PONG
```

### Elasticsearch 연결 실패

```bash
# Elasticsearch 연결 테스트
curl http://100.126.141.58:9200

# Parser 로그에서 Elasticsearch 에러 확인
docker-compose logs parser | grep -i elasticsearch

# .env 파일에서 호스트 확인
grep ELASTICSEARCH .env
```

### 메모리 부족

```bash
# 현재 메모리 사용량 확인
docker stats

# .env 파일에서 메모리 제한 증가
PARSER_MEMORY_LIMIT=4g
REDIS_MEMORY_LIMIT=1g

# 재시작
docker-compose restart
```

### 디스크 공간 부족

```bash
# Docker 이미지/컨테이너 정리
docker system prune -a

# 로그 파일 크기 제한 (docker-compose.yml)
logging:
  options:
    max-size: "50m"
    max-file: "3"
```

### PCAP 재생이 안 되는 경우

```bash
# tcpreplay 설치 확인
which tcpreplay
sudo apt-get install tcpreplay

# 재생 스크립트 확인
cat replay_loop.sh

# 수동 재생 테스트
sudo tcpreplay -i veth1 Parser/pcap/normal.pcap

# 권한 확인
ls -l Parser/pcap/*.pcap
chmod 644 Parser/pcap/*.pcap
```

---

## 고급 설정

### BPF 필터 사용

특정 트래픽만 캡처하려면 `.env`에서 BPF 필터 설정:

```bash
# Modbus만 캡처
BPF_FILTER="tcp port 502"

# 여러 포트 캡처
BPF_FILTER="tcp port 502 or tcp port 102 or tcp port 2004"

# 특정 IP 제외
BPF_FILTER="not host 192.168.1.100"
```

### 파일 출력 모드

실시간 모드 대신 파일로 저장하려면:

```bash
# .env 파일 수정
PARSER_MODE=with-files
OUTPUT_DIR=/data/output
ROLLING_INTERVAL=60  # 60분마다 파일 롤링

# 재시작
docker-compose restart parser

# 출력 확인
ls -lh output/
```

### 성능 최적화

```bash
# Worker 스레드 수 조정
PARSER_THREADS=8

# Elasticsearch Bulk 설정
ES_BULK_SIZE=200
ES_BULK_FLUSH_INTERVAL_MS=200

# Redis 설정
REDIS_POOL_SIZE=16
REDIS_ASYNC_WRITERS=4
REDIS_ASYNC_QUEUE_SIZE=20000
```

---

## 참고 문서

- **빠른 시작**: [QUICKSTART.md](QUICKSTART.md)
- **Docker Compose 상세**: [docker-compose.README.md](docker-compose.README.md)
- **Parser 설명**: [Parser/README.md](Parser/README.md)
- **프로젝트 개요**: [README.md](README.md)

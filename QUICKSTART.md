# OT Security Monitoring System - Quick Start Guide

## 🚀 빠른 시작 (4단계)

### 0️⃣ 테스트 트래픽 재생 (선택사항)
실제 네트워크 트래픽이 없는 경우, PCAP 파일을 반복 재생:

```bash
cd /home/ryuoo0/security

# 백그라운드에서 PCAP 재생 시작
sudo nohup ./replay_loop.sh > /dev/null 2>&1 &

# 재생 프로세스 확인
ps aux | grep replay_loop

# 재생 중지
sudo pkill -f replay_loop.sh
```

**재생되는 파일:**
- `Parser/pcap/normal.pcap` - 정상 트래픽
- `Parser/pcap/attack_01.pcap` - 공격 트래픽

> 💡 **참고**: replay_loop.sh는 normal.pcap → attack_01.pcap을 순차적으로 무한 반복 재생합니다.
> 기본 인터페이스는 `veth1`이며, 스크립트 내에서 수정 가능합니다.

### 1️⃣ 설정 확인
```bash
cd /home/ryuoo0/security

# 네트워크 인터페이스 확인
ip link show

# .env 파일 수정 (필요시)
nano .env
```

**중요 설정:**
- `NETWORK_INTERFACE`: PCAP 재생 시 replay_loop.sh의 인터페이스와 동일하게 설정 (기본: veth1)
- `PARSER_MODE`: realtime (실시간) 또는 with-files (파일 출력)

### 2️⃣ 실행
```bash
# 자동 시작 스크립트 사용 (권장)
./start.sh

# 또는 수동 실행
docker-compose up -d --build
```

### 3️⃣ 모니터링
```bash
# 로그 확인
docker-compose logs -f parser

# 상태 확인
docker-compose ps

# Redis/Elasticsearch 전송 확인
docker-compose logs parser | grep -E "(Redis|Elasticsearch).*✓"
```

## 📊 출력 확인

### 실시간 로그
```bash
# Parser 로그
docker-compose logs -f parser

# 예상 출력:
# [Redis] ✓ Sent 1000 records to streams
# [Elasticsearch] ✓ Queued 1000 documents to bulk
# [Elasticsearch] ✓ Sent 1000 documents
```

### Redis 데이터 확인
```bash
# Redis CLI 접속
docker-compose exec redis redis-cli

# Stream 확인
KEYS stream:protocol:*
XREAD COUNT 10 STREAMS stream:protocol:modbus 0
```

## 🛠️ 주요 명령어

```bash
# 시작
docker-compose up -d

# 재시작
docker-compose restart parser

# 중지
docker-compose stop

# 로그 확인
docker-compose logs -f parser

# 완전 제거
docker-compose down -v
```

## ⚙️ 설정 변경

`.env` 파일에서 주요 설정 변경:

```bash
# 네트워크 인터페이스 (중요!)
NETWORK_INTERFACE=any

# 파서 모드
PARSER_MODE=realtime        # 또는 with-files

# Elasticsearch
ELASTICSEARCH_HOST=100.126.141.58
ELASTICSEARCH_PORT=9200

# 성능 튜닝
PARSER_MEMORY_LIMIT=2g
PARSER_CPU_LIMIT=2.0
PARSER_THREADS=0            # 0=자동
```

설정 변경 후 재시작:
```bash
docker-compose restart parser
```

## 🔍 트러블슈팅

### Parser가 시작 안 됨
```bash
# 로그 확인
docker-compose logs parser

# 권한 문제일 경우
sudo docker-compose up -d --build
```

### Redis 연결 실패
```bash
# Redis 상태 확인
docker-compose ps redis

# Redis 재시작
docker-compose restart redis
```

### Elasticsearch 연결 실패
```bash
# 연결 테스트
curl http://100.126.141.58:9200

# Parser 로그 확인
docker-compose logs parser | grep -i elasticsearch
```

## 📚 더 자세한 정보

- 전체 문서: `docker-compose.README.md`
- Parser 설명: `Parser/README.md`
- 프로젝트 개요: `README.md`

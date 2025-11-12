# OT Security Monitoring System - Docker Compose

## 빠른 시작

### 0. 테스트 트래픽 재생 (선택사항)

실제 네트워크 트래픽이 없는 경우, 테스트용 PCAP 파일을 반복 재생할 수 있습니다:

```bash
# 백그라운드에서 PCAP 재생 시작
sudo nohup ./replay_loop.sh > /dev/null 2>&1 &

# 재생 프로세스 확인
ps aux | grep replay_loop

# 재생 중지
sudo pkill -f replay_loop.sh
```

`replay_loop.sh`는 다음 파일들을 순차적으로 무한 반복 재생합니다:
- `Parser/pcap/normal.pcap` - 정상 트래픽
- `Parser/pcap/attack_01.pcap` - 공격 트래픽

**인터페이스 설정:**
- 기본 인터페이스: `veth1`
- 변경이 필요한 경우 `replay_loop.sh` 파일의 `INTERFACE` 변수를 수정하세요

### 1. 환경 설정
`.env` 파일을 수정하여 네트워크 인터페이스와 Elasticsearch 설정을 확인하세요:

```bash
# 네트워크 인터페이스 확인
ip link show

# .env 파일 수정
nano .env
```

주요 설정:
- `NETWORK_INTERFACE`: 캡처할 네트워크 인터페이스 (예: any, eth0, veth1)
- `ELASTICSEARCH_HOST`: Elasticsearch 서버 IP
- `PARSER_MODE`: realtime (실시간 스트리밍) 또는 with-files (파일 출력 포함)

### 2. 빌드 및 실행

```bash
# 빌드 및 백그라운드 실행
docker-compose up -d --build

# 로그 확인
docker-compose logs -f parser

# Redis 로그 확인
docker-compose logs -f redis
```

### 3. 상태 확인

```bash
# 컨테이너 상태
docker-compose ps

# Parser 로그 실시간 확인
docker-compose logs -f parser | grep -E "(Redis|Elasticsearch|✓)"

# Redis 연결 확인
docker-compose exec redis redis-cli ping
```

### 4. 중지 및 재시작

```bash
# 중지
docker-compose stop

# 재시작
docker-compose restart

# 완전 제거 (볼륨 포함)
docker-compose down -v
```

## 서비스 구조

- **redis**: Redis 7 (포트 6379)
  - 실시간 데이터 스트리밍
  - 자산 정보 캐싱

- **parser**: Packet Parser
  - host 네트워크 모드 (패킷 캡처)
  - Elasticsearch로 데이터 전송
  - Redis Stream으로 실시간 데이터 전송

## 로그 확인

### Elasticsearch 전송 로그
```bash
docker-compose logs parser | grep Elasticsearch
```
출력 예시:
```
[Elasticsearch] ✓ Queued 1000 documents to bulk
[Elasticsearch] ✓ Sent 1000 documents
```

### Redis 전송 로그
```bash
docker-compose logs parser | grep Redis
```
출력 예시:
```
[Redis] ✓ Sent 1000 records to streams
[Redis] ✓ Sent 2000 records to streams
```

## 트러블슈팅

### Parser가 시작되지 않는 경우
```bash
# 권한 확인 (privileged 모드 필요)
docker-compose logs parser

# 네트워크 인터페이스 확인
ip link show
```

### Redis 연결 실패
```bash
# Redis 상태 확인
docker-compose ps redis

# Redis 로그 확인
docker-compose logs redis
```

### Elasticsearch 연결 실패
```bash
# Elasticsearch 연결 테스트
curl http://<ELASTICSEARCH_HOST>:9200

# Parser 로그 확인
docker-compose logs parser | grep -i elasticsearch
```

## 데이터 확인

### Redis Stream 확인
```bash
# Redis CLI 접속
docker-compose exec redis redis-cli

# Stream 목록 확인
KEYS stream:protocol:*

# Modbus 데이터 확인
XREAD COUNT 10 STREAMS stream:protocol:modbus 0
```

### 출력 파일 확인 (with-files 모드)
```bash
# 출력 디렉토리 확인
ls -lh output/

# CSV 파일 확인
head output/output_all.csv

# JSONL 파일 확인
head output/output_all.jsonl | jq
```

## 성능 튜닝

### Parser 리소스 제한 조정
`.env` 파일에서:
```bash
PARSER_MEMORY_LIMIT=4g      # 메모리 제한
PARSER_CPU_LIMIT=4.0        # CPU 제한
PARSER_THREADS=8            # Worker 스레드 수
```

### Redis 메모리 제한 조정
```bash
REDIS_MEMORY_LIMIT=1G       # Redis 메모리 제한
```

### Elasticsearch Bulk 설정
```bash
ES_BULK_SIZE=200            # Bulk 사이즈
ES_BULK_FLUSH_INTERVAL_MS=200  # Flush 간격
```

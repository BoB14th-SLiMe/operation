# Operation - Docker 운영 디렉토리

## 📋 개요

OT 보안 모니터링 시스템의 Docker 컨테이너 운영 및 배포 관련 파일들을 관리하는 디렉토리입니다.

---

## 📂 디렉토리 구조

```
operation/
├── docker-compose.yml              # Docker Compose 설정
├── docker-compose-with-parser.sh   # 자동 시작 스크립트
├── test-elasticsearch-integration.sh # ES 연동 테스트
├── .env.example                    # 환경 변수 템플릿
├── .env                            # 환경 변수 (사용자가 생성)
└── README.md                       # 이 문서
```

---

## 🚀 빠른 시작

### 1. 환경 변수 설정

```bash
# .env.example을 복사하여 .env 생성
cp .env.example .env

# Elasticsearch 호스트 수정
nano .env
```

**.env 파일**:
```env
ELASTICSEARCH_HOST=192.168.1.100  # Dashboard PC IP
ELASTICSEARCH_PORT=9200
LOG_LEVEL=INFO
```

### 2. 시스템 시작

**옵션 1: 자동 스크립트 (권장)**
```bash
# operation 디렉토리에서
chmod +x docker-compose-with-parser.sh
./docker-compose-with-parser.sh
```

**옵션 2: 수동 실행**
```bash
# operation 디렉토리에서
docker-compose up -d
```

### 3. 상태 확인

```bash
# 서비스 상태
docker-compose ps

# 로그 확인
docker-compose logs -f

# Parser 로그만
docker-compose logs -f cpp-parser

# Sender 로그만
docker-compose logs -f jsonl-sender
```

---

## 📊 제공되는 서비스

| 서비스 | 컨테이너명 | 포트 | 상태 |
|--------|-----------|------|------|
| **C++ Parser** | ot-security-cpp-parser | - | ✅ 활성화 |
| **JSONL Sender** | ot-security-jsonl-sender | - | ✅ 활성화 |
| Redis | ot-security-redis | 6379 | ✅ 활성화 |
| Kafka | ot-security-kafka | 9092 | ✅ 활성화 |
| Zookeeper | ot-security-zookeeper | 2181 | ✅ 활성화 |
| Kafka UI | ot-security-kafka-ui | 8090 | ✅ 활성화 |
| Redis Commander | ot-security-redis-commander | 8081 | ✅ 활성화 |
| Filebeat | ot-security-filebeat | - | ⬜ 비활성화 (대안) |

---

## 🔧 주요 명령어

### 시작/중지

```bash
# 시작
docker-compose up -d

# 중지
docker-compose stop

# 완전 삭제 (데이터 보존)
docker-compose down

# 완전 삭제 (데이터 포함)
docker-compose down -v
```

### 서비스 관리

```bash
# 특정 서비스만 시작
docker-compose up -d cpp-parser

# 특정 서비스 재시작
docker-compose restart cpp-parser

# 특정 서비스 중지
docker-compose stop cpp-parser

# 이미지 재빌드
docker-compose build cpp-parser
docker-compose up -d cpp-parser
```

### 로그 확인

```bash
# 전체 로그
docker-compose logs

# 실시간 로그
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs cpp-parser
docker-compose logs jsonl-sender

# 최근 N줄
docker-compose logs --tail=100 cpp-parser
```

### 상태 확인

```bash
# 서비스 상태
docker-compose ps

# 리소스 사용량
docker stats

# 네트워크 확인
docker network ls
docker network inspect ot-security-network
```

---

## 🧪 테스트

### Elasticsearch 연동 테스트

```bash
# operation 디렉토리에서
chmod +x test-elasticsearch-integration.sh
./test-elasticsearch-integration.sh
```

**수행 작업**:
- ✅ Elasticsearch 연결 테스트
- ✅ Parser/Sender 상태 확인
- ✅ 테스트 JSONL 파일 생성
- ✅ 데이터 전송 확인
- ✅ Elasticsearch 쿼리 실행
- ✅ 통계 출력

---

## ⚙️ 설정 파일

### docker-compose.yml

**주요 설정**:
```yaml
services:
  cpp-parser:
    build:
      context: ../RealtimeParser  # Parser 디렉토리
    volumes:
      - parser-output:/data/parser-output
    environment:
      REDIS_HOST: redis
      KAFKA_BOOTSTRAP_SERVERS: kafka:29092
```

### .env 파일

**환경 변수**:
```env
# Elasticsearch
ELASTICSEARCH_HOST=192.168.1.100
ELASTICSEARCH_PORT=9200

# Parser
LOG_LEVEL=INFO

# Sender
BATCH_SIZE=500
FLUSH_INTERVAL=5
```

---

## 🔍 모니터링

### Web UI

```bash
# Kafka UI
open http://localhost:8090

# Redis Commander
open http://localhost:8081
```

### CLI 모니터링

```bash
# Redis
docker exec -it ot-security-redis redis-cli
127.0.0.1:6379> XLEN packet_stream
127.0.0.1:6379> XREAD COUNT 10 STREAMS packet_stream 0

# Kafka
docker exec -it ot-security-kafka kafka-topics --bootstrap-server localhost:9092 --list
docker exec -it ot-security-kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic threat-events
```

### 로그 위치

| 로그 | 위치 | 확인 방법 |
|------|------|----------|
| Parser | `/app/logs/parser.log` | `docker exec -it ot-security-cpp-parser tail -f /app/logs/parser.log` |
| Sender | `/var/log/jsonl-sender/sender.log` | `docker exec -it ot-security-jsonl-sender tail -f /var/log/jsonl-sender/sender.log` |
| JSONL 출력 | `/data/parser-output/*.jsonl` | `docker exec -it ot-security-cpp-parser ls -lh /data/parser-output/` |

---

## 🐛 트러블슈팅

### Parser가 시작되지 않음

**증상**:
```
ERROR: failed to compute cache key
```

**해결**:
```bash
# 프로젝트 루트에서
cd ..
ls -lh RealtimeParser/build/parser

# 바이너리가 없으면 빌드
cd RealtimeParser/build
cmake .. && make
cd ../../operation

# 이미지 재빌드
docker-compose build --no-cache cpp-parser
docker-compose up -d cpp-parser
```

### Redis/Kafka 연결 실패

**증상**:
```
[ERROR] Failed to connect to Redis
```

**해결**:
```bash
# 서비스 재시작
docker-compose restart redis kafka
docker-compose restart cpp-parser

# 헬스체크 확인
docker-compose ps
```

### Elasticsearch 전송 실패

**증상**:
```
[ERROR] Elasticsearch 연결 오류
```

**해결**:
```bash
# .env 파일 확인
cat .env

# Elasticsearch 연결 테스트
curl http://192.168.1.100:9200

# Sender 재시작
docker-compose restart jsonl-sender
docker-compose logs -f jsonl-sender
```

### 포트 충돌

**증상**:
```
ERROR: port is already allocated
```

**해결**:
```bash
# 사용 중인 포트 확인
sudo netstat -tulpn | grep :6379
sudo netstat -tulpn | grep :9092

# docker-compose.yml에서 포트 변경
nano docker-compose.yml
# ports: "16379:6379"  # 6379 → 16379로 변경
```

---

## 🔒 보안 고려사항

### 1. 네트워크 격리
```yaml
# docker-compose.yml
networks:
  ot-security-network:
    driver: bridge
    internal: false  # 외부 접근 차단 시 true
```

### 2. 읽기 전용 볼륨
```yaml
volumes:
  - ../RealtimeParser/config.json:/app/config.json:ro
  - parser-output:/data/parser-output:ro
```

### 3. 리소스 제한
```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 2G
```

---

## 📈 성능 최적화

### 1. Parser 최적화

**.env 수정**:
```env
LOG_LEVEL=WARN  # INFO → WARN (로그 감소)
```

**config.json 수정**:
```json
{
  "parser": {
    "batch_size": 500,
    "flush_interval_ms": 500
  }
}
```

### 2. Sender 최적화

**.env 수정**:
```env
BATCH_SIZE=2000      # 500 → 2000
FLUSH_INTERVAL=2     # 5 → 2
```

### 3. 리소스 증가

**docker-compose.yml 수정**:
```yaml
cpp-parser:
  deploy:
    resources:
      limits:
        cpus: '4.0'
        memory: 4G
```

---

## 📚 추가 문서

- [프로젝트 구조](../PROJECT-STRUCTURE.md)
- [Parser 가이드](../RealtimeParser/README.md)
- [Elasticsearch 연동](../ELASTICSEARCH-INTEGRATION.md)
- [빠른 시작](../QUICK-START.md)

---

## 🎯 운영 체크리스트

### 시작 전
- [ ] Parser 바이너리 빌드 완료 (`RealtimeParser/build/parser`)
- [ ] `.env` 파일 설정 완료
- [ ] Dashboard PC의 Elasticsearch 실행 중
- [ ] Docker/Docker Compose 설치 확인

### 시작 후
- [ ] 모든 서비스 `Up` 상태 확인 (`docker-compose ps`)
- [ ] Redis/Kafka 헬스체크 통과
- [ ] Parser 로그 정상 (`docker-compose logs cpp-parser`)
- [ ] JSONL 파일 생성 확인 (`/data/parser-output/`)
- [ ] Elasticsearch 데이터 확인 (`curl`)

### 정기 점검
- [ ] 로그 파일 크기 확인
- [ ] 디스크 사용량 확인 (`docker system df`)
- [ ] 볼륨 정리 (`docker volume prune`)
- [ ] 오래된 이미지 정리 (`docker image prune`)

---

## 🆘 지원

문제 발생 시:
1. **로그 확인**: `docker-compose logs -f`
2. **테스트 실행**: `./test-elasticsearch-integration.sh`
3. **재시작**: `docker-compose restart`
4. **클린 재시작**: `docker-compose down && docker-compose up -d`

# 🚀 실행 가이드 - 2단계 워크플로우

OT 보안 모니터링 시스템은 **2개의 독립적인 단계**로 구성됩니다.

---

## 📋 전체 워크플로우

```
┌─────────────────────────────────────────────────────────────┐
│                     전체 시스템 워크플로우                       │
└─────────────────────────────────────────────────────────────┘

1️⃣ SLM 학습 단계 (Parser)
   └─→ CSV 데이터 생성 → 모델 학습
   
2️⃣ 운영 단계 (RealtimeParser)
   └─→ 실시간 탐지 → Elasticsearch → Dashboard
```

---

## 1️⃣ SLM 학습 단계 (Parser)

### 목적
- SLM(Statistical Learning Model) 학습을 위한 CSV 데이터 생성
- 통계적 특징 추출
- 정상/공격 트래픽 레이블링

### 사전 준비

#### 1. Parser 빌드
```bash
cd Parser/build
cmake ..
make
ls -lh parser  # 바이너리 확인
```

#### 2. 설정 확인
```bash
cd ..
cat config.json
```

### 실행 방법

#### 옵션 A: 자동 스크립트 (권장)
```bash
cd Parser
chmod +x run-training.sh
./run-training.sh
```

**대화형 프롬프트**:
```
실행 모드를 선택하세요:
  1) 실시간 캡처 (네트워크 인터페이스)
  2) PCAP 파일 분석

선택 (1 또는 2): 
```

#### 옵션 B: 수동 실행

**실시간 캡처**:
```bash
cd Parser/build
sudo ./parser \
    --config ../config.json \
    --interface eth0 \
    --duration 3600 \
    --output ../data/csv-output
```

**PCAP 파일 분석**:
```bash
cd Parser/build
./parser \
    --config ../config.json \
    --input /path/to/capture.pcap \
    --label normal \
    --output ../data/csv-output
```

### 출력 결과

**CSV 파일 위치**: `Parser/data/csv-output/`

**파일 예시**:
```
training_data_20250103_100000.csv
training_data_20250103_110000.csv
training_data_20250103_120000.csv
```

**CSV 형식**:
```csv
timestamp,src_ip,dst_ip,protocol,src_port,dst_port,bytes,packets,duration,flags,label
2025-01-03T10:00:00Z,192.168.1.10,192.168.1.20,TCP,12345,80,1024,10,0.5,SYN|ACK,normal
2025-01-03T10:00:01Z,10.0.0.100,192.168.1.22,TCP,65000,22,8192,50,5.0,SYN|PSH,dos_attack
```

### 확인

```bash
# 생성된 파일 확인
ls -lh Parser/data/csv-output/

# 데이터 샘플 확인
head -10 Parser/data/csv-output/training_data_*.csv

# 행 수 확인
wc -l Parser/data/csv-output/*.csv
```

### 다음 단계

**Python으로 모델 학습**:
```python
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier

# CSV 로드
df = pd.read_csv('Parser/data/csv-output/training_data_*.csv')

# 특징/레이블 분리
X = df.drop('label', axis=1)
y = df['label']

# 학습
model = RandomForestClassifier()
model.fit(X_train, y_train)
```

---

## 2️⃣ 운영 단계 (RealtimeParser)

### 목적
- 실시간 위협 탐지
- Redis/Kafka 스트리밍
- Elasticsearch 저장
- Dashboard 연동

### 사전 준비

#### 1. RealtimeParser 빌드
```bash
cd RealtimeParser/build
cmake ..
make
ls -lh parser  # 바이너리 확인
```

#### 2. 환경 설정
```bash
cd ../../operation
cp .env.example .env
nano .env
```

**.env 파일**:
```env
ELASTICSEARCH_HOST=192.168.1.100  # Dashboard PC IP
ELASTICSEARCH_PORT=9200
LOG_LEVEL=INFO
```

#### 3. Dashboard PC 준비
```bash
# Dashboard PC에서 Elasticsearch 실행
sudo systemctl start elasticsearch

# 확인
curl http://localhost:9200
```

### 실행 방법

#### 옵션 A: 자동 스크립트 (권장)
```bash
cd operation
chmod +x run-production.sh
./run-production.sh
```

**자동 수행**:
- ✅ 사전 확인 (Docker, 바이너리, .env)
- ✅ Elasticsearch 연결 테스트
- ✅ Docker Compose 실행
- ✅ 헬스체크
- ✅ 실시간 로그 모니터링

#### 옵션 B: 기존 스크립트
```bash
cd operation
./docker-compose-with-parser.sh
```

#### 옵션 C: 수동 실행
```bash
cd operation
docker-compose up -d
```

### 서비스 구성

실행되는 서비스:
- ✅ **Redis** - 실시간 스트림
- ✅ **Kafka** - 이벤트 큐
- ✅ **Zookeeper** - Kafka 의존성
- ✅ **RealtimeParser** - C++ 파서
- ✅ **JSONL Sender** - Elasticsearch 전송
- ✅ **Kafka UI** - 모니터링
- ✅ **Redis Commander** - 모니터링

### 데이터 흐름

```
Network Packets
      ↓
RealtimeParser (C++)
      ├──→ Redis Stream (packet_stream)
      ├──→ Kafka Topics (threat-events, dos-alerts)
      └──→ JSONL Files (/data/parser-output/*.jsonl)
            ↓
      JSONL Sender (Python)
            ↓
      Elasticsearch (Dashboard PC)
            ↓
      Dashboard (Kibana/Grafana)
```

### 모니터링

#### Web UI
- **Kafka UI**: http://localhost:8090
- **Redis Commander**: http://localhost:8081

#### 로그 확인
```bash
cd operation

# 전체 로그
docker-compose logs -f

# RealtimeParser 로그
docker-compose logs -f cpp-parser

# Sender 로그
docker-compose logs -f jsonl-sender

# 최근 100줄
docker-compose logs --tail=100 cpp-parser
```

#### 서비스 상태
```bash
cd operation

# 상태 확인
docker-compose ps

# 헬스체크
docker exec ot-security-redis redis-cli ping
docker exec ot-security-kafka kafka-topics --bootstrap-server localhost:9092 --list
```

### 확인

#### JSONL 파일 생성 확인
```bash
# 컨테이너 내부
docker exec ot-security-cpp-parser ls -lh /data/parser-output/

# 호스트 (볼륨 마운트 시)
ls -lh /var/lib/docker/volumes/operation_parser-output/_data/
```

#### Elasticsearch 데이터 확인
```bash
# 인덱스 목록
curl http://192.168.1.100:9200/_cat/indices?v | grep ot-security

# 데이터 개수
curl http://192.168.1.100:9200/ot-security-packets-*/_count

# 데이터 조회
curl http://192.168.1.100:9200/ot-security-packets-*/_search?pretty
```

### 테스트

```bash
cd operation
chmod +x test-elasticsearch-integration.sh
./test-elasticsearch-integration.sh
```

**수행 작업**:
- ✅ Elasticsearch 연결 테스트
- ✅ Parser/Sender 상태 확인
- ✅ 테스트 데이터 생성
- ✅ Elasticsearch 전송 확인
- ✅ 통계 출력

### 중지

```bash
cd operation

# 중지 (데이터 보존)
docker-compose stop

# 재시작
docker-compose start

# 완전 삭제 (데이터 보존)
docker-compose down

# 완전 삭제 (데이터 포함)
docker-compose down -v
```

---

## 📊 단계별 비교

| 항목 | 1️⃣ SLM 학습 단계 | 2️⃣ 운영 단계 |
|------|----------------|-------------|
| **Parser** | `Parser/build/parser` | `RealtimeParser/build/parser` |
| **목적** | 모델 학습 데이터 생성 | 실시간 위협 탐지 |
| **출력** | CSV 파일 | JSONL, Redis, Kafka |
| **실행 환경** | 로컬 또는 Docker | Docker Compose |
| **스크립트** | `Parser/run-training.sh` | `operation/run-production.sh` |
| **설정 파일** | `Parser/config.json` | `RealtimeParser/config.json` |
| **데이터 위치** | `Parser/data/csv-output/` | `/data/parser-output/` |
| **실행 시간** | 일회성 또는 주기적 | 24/7 상시 운영 |
| **네트워크** | 선택적 (PCAP 가능) | 필수 (실시간 캡처) |
| **Elasticsearch** | 불필요 | 필수 |

---

## 🔄 전체 워크플로우 예시

### 시나리오: 처음부터 끝까지

#### Phase 1: SLM 학습 데이터 수집
```bash
# 1. Parser 빌드
cd Parser/build
cmake .. && make

# 2. 정상 트래픽 수집 (1시간)
cd ..
sudo ./build/parser \
    --config config.json \
    --interface eth0 \
    --duration 3600 \
    --label normal \
    --output data/csv-output

# 3. 공격 트래픽 수집 (PCAP)
./build/parser \
    --config config.json \
    --input attack_samples.pcap \
    --label dos_attack \
    --output data/csv-output

# 4. 데이터 확인
ls -lh data/csv-output/
wc -l data/csv-output/*.csv
```

#### Phase 2: 모델 학습
```python
# train_model.py
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
import joblib

# 데이터 로드
df = pd.read_csv('Parser/data/csv-output/*.csv')

# 학습
X = df.drop('label', axis=1)
y = df['label']
model = RandomForestClassifier()
model.fit(X, y)

# 모델 저장
joblib.dump(model, 'model.pkl')
```

#### Phase 3: 운영 배포
```bash
# 1. RealtimeParser 빌드
cd RealtimeParser/build
cmake .. && make

# 2. 환경 설정
cd ../../operation
cp .env.example .env
nano .env  # ELASTICSEARCH_HOST 설정

# 3. 운영 시스템 시작
./run-production.sh

# 4. 모니터링
# Kafka UI: http://localhost:8090
# Redis Commander: http://localhost:8081
```

---

## 🐛 트러블슈팅

### SLM 학습 단계 문제

**Parser 바이너리 없음**:
```bash
cd Parser/build
cmake .. && make
```

**CSV 파일 생성 안됨**:
```bash
# 출력 디렉토리 권한 확인
mkdir -p Parser/data/csv-output
chmod 755 Parser/data/csv-output

# 설정 확인
cat Parser/config.json
```

**네트워크 인터페이스 권한 오류**:
```bash
# sudo로 실행
sudo ./Parser/run-training.sh
```

### 운영 단계 문제

**RealtimeParser 시작 실패**:
```bash
# 바이너리 확인
ls -lh RealtimeParser/build/parser

# 재빌드
cd RealtimeParser/build
cmake .. && make

# Docker 재시작
cd ../../operation
docker-compose restart cpp-parser
```

**Elasticsearch 연결 실패**:
```bash
# .env 확인
cat operation/.env

# Elasticsearch 테스트
curl http://192.168.1.100:9200

# Sender 재시작
cd operation
docker-compose restart jsonl-sender
```

---

## ✅ 체크리스트

### SLM 학습 단계
- [ ] Parser 빌드 완료
- [ ] config.json 설정 확인
- [ ] 네트워크 인터페이스 또는 PCAP 파일 준비
- [ ] 출력 디렉토리 생성 및 권한 확인
- [ ] run-training.sh 실행
- [ ] CSV 파일 생성 확인
- [ ] 데이터 품질 검증

### 운영 단계
- [ ] RealtimeParser 빌드 완료
- [ ] operation/.env 설정
- [ ] Dashboard PC Elasticsearch 실행
- [ ] Docker/Docker Compose 설치
- [ ] run-production.sh 실행
- [ ] 모든 서비스 Up 상태
- [ ] Elasticsearch 데이터 확인
- [ ] 모니터링 UI 접속

---

## 📚 추가 문서

- **[Parser 상세 가이드](./Parser/README.md)** - SLM 학습용
- **[RealtimeParser 가이드](./RealtimeParser/README.md)** - 실시간 탐지
- **[Docker 운영 가이드](./operation/README.md)** - 운영 단계
- **[빠른 시작](./docs/QUICK-START.md)** - 5분 시작
- **[Elasticsearch 연동](./ELASTICSEARCH-INTEGRATION.md)** - ES 설정

---

## 🎯 핵심 명령어 요약

### SLM 학습 단계
```bash
cd Parser
./run-training.sh                    # 자동 실행
ls -lh data/csv-output/              # 결과 확인
```

### 운영 단계
```bash
cd operation
./run-production.sh                  # 자동 실행
docker-compose ps                    # 상태 확인
./test-elasticsearch-integration.sh  # 테스트
```

끝! 🚀

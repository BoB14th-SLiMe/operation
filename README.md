# 🛡️ OT 보안 모니터링 시스템

## 📋 개요

산업제어시스템(OT) 환경의 실시간 위협 탐지 및 모니터링을 위한 통합 보안 시스템입니다.

### 주요 기능
- ✅ **실시간 패킷 분석** - C++ 기반 고성능 Parser
- ✅ **SLM 학습 데이터 생성** - CSV 형식 특징 추출
- ✅ **메모리 기반 스트리밍** - Redis Stream + Kafka
- ✅ **Elasticsearch 연동** - 대시보드 데이터 저장
- ✅ **Docker 기반 배포** - 컨테이너 오케스트레이션

---

## 🚀 빠른 시작

시스템은 **2개의 독립적인 단계**로 실행됩니다:

### 1️⃣ SLM 학습 단계 (Parser)
```bash
# Parser 빌드
cd Parser
sudo rm -rf output
rm -rf build

cmake -B build
cmake --build build

# 학습 데이터 생성
cd ..
chmod +x run-training.sh
./run-training.sh
```
→ **CSV 데이터 생성** → 모델 학습

### 2️⃣ 운영 단계 (RealtimeParser)
```bash
# RealtimeParser 빌드
cd RealtimeParser
sudo rm -rf output
rm -rf build

cmake -B build
cmake --build build

# 환경 설정
cd ../operation
cp .env.example .env
nano .env  # ELASTICSEARCH_HOST 수정

# 운영 시스템 시작
chmod +x run-production.sh
./run-production.sh
```
→ **실시간 탐지** → Elasticsearch → Dashboard

**📖 상세 가이드**: [EXECUTION-GUIDE.md](./EXECUTION-GUIDE.md)

---

## 🏗️ 시스템 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    OT Security System                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐        ┌──────────────────┐          │
│  │ RealtimeParser   │───────▶│   JSONL Files    │          │
│  │  (실시간 탐지)    │        │   (공유 볼륨)     │          │
│  └────────┬─────────┘        └────────┬─────────┘          │
│           │                           │                     │
│           ├──→ Redis Stream           ├──→ Python Sender   │
│           ├──→ Kafka Topics           │    또는 Filebeat   │
│           │                           ↓                     │
│  ┌────────────────┐          ┌────────────────┐            │
│  │     Parser     │          │ Elasticsearch  │            │
│  │ (SLM 학습용)    │─────────▶│ (Dashboard PC) │            │
│  │  CSV 출력       │          └────────────────┘            │
│  └────────────────┘                                         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📂 프로젝트 구조

```
OT-Security-Monitoring/
│
├── README.md                   # 이 문서
│
├── operation/                  # 🐳 Docker 운영
│   ├── docker-compose.yml
│   ├── docker-compose-with-parser.sh
│   ├── test-elasticsearch-integration.sh
│   └── .env.example
│
├── RealtimeParser/             # 🔧 실시간 Parser
│   ├── build/parser            # 실행 바이너리
│   ├── Dockerfile
│   ├── config.json
│   └── README.md
│
├── Parser/                     # 📊 SLM 학습용 Parser
│   ├── build/parser            # 실행 바이너리
│   ├── Dockerfile
│   ├── config.json (CSV 출력)
│   └── README.md
│
├── python-jsonl-sender/        # 🐍 Python Sender
│   ├── sender.py
│   ├── Dockerfile
│   └── README.md
│
├── filebeat/                   # 📡 Filebeat (대안)
│   └── filebeat.yml
│
└── docs/                       # 📚 문서
    ├── QUICK-START.md
    └── README.md
```

**📖 상세 구조**: [DIRECTORY-STRUCTURE.md](./DIRECTORY-STRUCTURE.md)

---

## 🎯 핵심 컴포넌트

### 1. RealtimeParser (실시간 탐지)
- **위치**: `RealtimeParser/`
- **역할**: 실시간 패킷 캡처 및 전처리
- **출력**: Redis Stream, Kafka Topics, JSONL Files
- **빌드**: `cd RealtimeParser/build && cmake .. && make`

### 2. Parser (SLM 학습용)
- **위치**: `Parser/`
- **역할**: SLM 학습 데이터 생성
- **출력**: CSV Files (통계 특징 추출)
- **빌드**: `cd Parser/build && cmake .. && make`

### 3. Python JSONL Sender
- **위치**: `python-jsonl-sender/`
- **역할**: JSONL → Elasticsearch 전송
- **특징**: Watchdog 기반 실시간 감시

### 4. Docker Orchestration
- **위치**: `operation/`
- **서비스**: Redis, Kafka, Parser, Sender
- **모니터링**: Kafka UI (8090), Redis Commander (8081)

---

## 📊 데이터 흐름

### 실시간 탐지 (RealtimeParser)
```
Network Packets
      ↓
RealtimeParser
      ├──→ Redis Stream (실시간)
      ├──→ Kafka Topics (이벤트)
      └──→ JSONL Files
            ↓
      Python Sender
            ↓
      Elasticsearch
```

### SLM 학습 (Parser)
```
Network Packets / PCAP Files
      ↓
Parser (학습용)
      ↓
CSV Files (특징 추출)
      ↓
SLM Training
```

---

## 🔧 기술 스택

| 컴포넌트 | 기술 |
|---------|------|
| **Realtime Parser** | C++, libpcap, hiredis, librdkafka |
| **Training Parser** | C++, libpcap, CSV 출력 |
| **Streaming** | Redis Stream, Apache Kafka |
| **Data Transfer** | Python, Watchdog, Elasticsearch Client |
| **Storage** | Elasticsearch (Dashboard PC) |
| **Orchestration** | Docker, Docker Compose |

---

## 📚 문서

### 시작하기
- **[빠른 시작 (5분)](./docs/QUICK-START.md)** - 최소 설정으로 빠르게 시작
- **[Docker 운영 가이드](./operation/README.md)** - operation 디렉토리 사용법

### 개발
- **[RealtimeParser 가이드](./RealtimeParser/README.md)** - 실시간 Parser
- **[Parser 가이드](./Parser/README.md)** - SLM 학습용 Parser
- **[C++ 빌드 가이드](./RealtimeParser/build-guide.md)** - CMake 빌드

### 연동
- **[Elasticsearch 연동](./ELASTICSEARCH-INTEGRATION.md)** - 완벽 가이드
- **[Docker 상세](./README-DOCKER.md)** - Docker Compose 설정

### 참고
- **[디렉토리 구조](./DIRECTORY-STRUCTURE.md)** - 전체 프로젝트 구조
- **[아키텍처](./realtime-detection-architecture.md)** - 시스템 설계

---

## 🛠️ 개발 환경 요구사항

### C++ Parser 빌드
- CMake 3.15+
- GCC 9.0+ 또는 Clang 10.0+
- libpcap-dev, hiredis-dev, librdkafka-dev

### Docker 실행
- Docker 20.10+
- Docker Compose 1.29+

### Elasticsearch (Dashboard PC)
- Elasticsearch 8.x
- 최소 2GB RAM

---

## 🚦 시스템 상태 확인

```bash
cd operation

# 서비스 상태
docker-compose ps

# 로그 확인
docker-compose logs -f cpp-parser jsonl-sender

# Elasticsearch 데이터
curl http://192.168.1.100:9200/ot-security-packets-*/_search?pretty
```

### 모니터링 UI
- **Kafka UI**: http://localhost:8090
- **Redis Commander**: http://localhost:8081

---

## 🧪 테스트

```bash
cd operation
chmod +x test-elasticsearch-integration.sh
./test-elasticsearch-integration.sh
```

---

## 🐛 트러블슈팅

### Parser 시작 실패
```bash
# RealtimeParser 바이너리 확인
ls -lh RealtimeParser/build/parser

# Parser 바이너리 확인
ls -lh Parser/build/parser

# 없으면 빌드
cd RealtimeParser/build && cmake .. && make
cd ../../Parser/build && cmake .. && make
```

### Elasticsearch 연�� 실패
```bash
# .env 확인
cat operation/.env

# Elasticsearch 테스트
curl http://192.168.1.100:9200
```

---

## 📈 성능 최적화

### RealtimeParser
```json
// RealtimeParser/config.json
{
  "parser": {
    "batch_size": 500,
    "flush_interval_ms": 500
  }
}
```

### Parser (학습용)
```json
// Parser/config.json
{
  "parser": {
    "batch_size": 100
  },
  "output": {
    "csv": {
      "rotation_size_mb": 100
    }
  }
}
```

---

## 🔒 보안 고려사항

- 네트워크 격리
- 읽기 전용 볼륨
- Elasticsearch 인증
- 리소스 제한

---

## ⭐ 시작하기

```bash
# 1. 저장소 클론
git clone <repository-url>
cd OT-Security-Monitoring

# 2. Parser 빌드
cd RealtimeParser/build && cmake .. && make
cd ../../Parser/build && cmake .. && make

# 3. 환경 설정
cd ../../operation
cp .env.example .env
nano .env

# 4. 시스템 시작
./docker-compose-with-parser.sh

# 5. 테스트
./test-elasticsearch-integration.sh
```

**🎉 완료! 시스템이 실행되고 있습니다!**

더 자세한 내용은 [docs/QUICK-START.md](./docs/QUICK-START.md)를 참고하세요.

# 🎯 여기서 시작하세요!

## OT 보안 모니터링 시스템 - 빠른 가이드

---

## 📋 시스템 구성

이 시스템은 **2단계**로 구성됩니다:

```
1️⃣ SLM 학습 단계            2️⃣ 운영 단계
   (Parser)                    (RealtimeParser)
       ↓                            ↓
   CSV 생성                    실시간 탐지
       ↓                            ↓
   모델 학습                    Elasticsearch
                                    ↓
                               Dashboard
```

---

## 🚀 어떤 단계를 실행하시나요?

### 1️⃣ SLM 학습 데이터를 수집하고 싶다면

**목적**: SLM 모델 학습을 위한 CSV 데이터 생성

**실행**:
```bash
cd Parser
chmod +x run-training.sh
./run-training.sh
```

**결과**: `Parser/data/csv-output/*.csv` 파일 생성

**다음 단계**: Python으로 모델 학습

**자세히**: [EXECUTION-GUIDE.md - 1️⃣ SLM 학습 단계](./EXECUTION-GUIDE.md#1️⃣-slm-학습-단계-parser)

---

### 2️⃣ 실시간 위협 탐지 시스템을 운영하고 싶다면

**목적**: 실시간 네트워크 모니터링 및 위협 탐지

**실행**:
```bash
cd operation
chmod +x run-production.sh
./run-production.sh
```

**결과**: 
- Redis/Kafka 스트리밍
- Elasticsearch 데이터 저장
- 실시간 대시보드

**다음 단계**: Kibana/Grafana 대시보드 연동

**자세히**: [EXECUTION-GUIDE.md - 2️⃣ 운영 단계](./EXECUTION-GUIDE.md#2️⃣-운영-단계-realtimeparser)

---

## 📚 문서 가이드

### 처음 사용하시나요?
1. **[EXECUTION-GUIDE.md](./EXECUTION-GUIDE.md)** ← **여기부터 읽으세요!**
2. [README.md](./README.md) - 프로젝트 개요
3. [docs/QUICK-START.md](./docs/QUICK-START.md) - 5분 빠른 시작

### 빌드가 필요하신가요?
- [RealtimeParser/build-guide.md](./RealtimeParser/build-guide.md) - C++ 빌드 상세

### 설정이 필요하신가요?
- [Parser/README.md](./Parser/README.md) - SLM 학습용 Parser
- [RealtimeParser/README.md](./RealtimeParser/README.md) - 실시간 Parser
- [operation/README.md](./operation/README.md) - Docker 운영

### 연동이 필요하신가요?
- [ELASTICSEARCH-INTEGRATION.md](./ELASTICSEARCH-INTEGRATION.md) - Elasticsearch
- [README-DOCKER.md](./README-DOCKER.md) - Docker 상세

### 구조를 알고 싶으신가요?
- [FINAL-STRUCTURE.md](./FINAL-STRUCTURE.md) - 최종 구조
- [DIRECTORY-STRUCTURE.md](./DIRECTORY-STRUCTURE.md) - 상세 구조

---

## ⚡ 핵심 명령어

### SLM 학습 단계
```bash
# 빌드
cd Parser/build && sudo rm -rf output && rm -rf build && cmake -B build && cmake --build build

# 실행
cd .. && ./run-training.sh

# 확인
ls -lh data/csv-output/
```

### 운영 단계
```bash
# 빌드
cd RealtimeParser &&  sudo rm -rf output && rm -rf build && cmake -B build && cmake --build build

# 환경 설정
cd ../operation && cp .env.example .env && nano .env

# 실행
./run-production.sh

# 확인
docker-compose ps
```

---

## 🎯 다음 단계

### SLM 학습 단계를 완료했다면
→ CSV 데이터로 모델 학습 (Python/scikit-learn)

### 운영 단계를 시작했다면
→ 모니터링 UI 접속:
- Kafka UI: http://localhost:8090
- Redis Commander: http://localhost:8081

---

## 🆘 도움이 필요하신가요?

### 빌드 오류
```bash
# Parser
cd Parser/build && cmake .. && make

# RealtimeParser
cd RealtimeParser/build && cmake .. && make
```

### 실행 오류
```bash
# SLM 학습
cd Parser && ./run-training.sh

# 운영
cd operation && ./run-production.sh
```

### 더 자세한 도움말
- **[EXECUTION-GUIDE.md](./EXECUTION-GUIDE.md)** - 완벽한 실행 가이드
- **[README.md](./README.md)** - 전체 시스템 개요

---

## 🎉 준비 완료!

**SLM 학습을 시작하려면**:
```bash
cd Parser && ./run-training.sh
```

**운영 시스템을 시작하려면**:
```bash
cd operation && ./run-production.sh
```

**궁금한 점이 있다면**:
→ [EXECUTION-GUIDE.md](./EXECUTION-GUIDE.md)를 읽어보세요!

---

**Good Luck! 🚀**

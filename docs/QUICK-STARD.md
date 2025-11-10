# 🚀 빠른 시작 가이드 (5분)

## 📋 사전 요구사항

- ✅ Docker & Docker Compose 설치
- ✅ Dashboard PC의 Elasticsearch 실행 중
- ✅ C++ 빌드 환경 (CMake, GCC/Clang)

---

## 1️⃣ Parser 빌드

```bash
# RealtimeParser 빌드 (실시간)
cd RealtimeParser/build
cmake ..
make
ls -lh parser  # 바이너리 확인

# Parser 빌드 (SLM 학습용 CSV)
cd ../../Parser/build
cmake ..
make
ls -lh parser  # 바이너리 확인
```

---

## 2️⃣ 환경 설정

```bash
cd ../../operation
cp .env.example .env
nano .env
```

**.env 파일 수정**:
```env
ELASTICSEARCH_HOST=192.168.1.100  # Dashboard PC IP
ELASTICSEARCH_PORT=9200
LOG_LEVEL=INFO
```

---

## 3️⃣ 시스템 시작

```bash
chmod +x docker-compose-with-parser.sh
./docker-compose-with-parser.sh
```

또는 수동 실행:
```bash
docker-compose up -d
```

---

## 4️⃣ 상태 확인

### 서비스 상태
```bash
docker-compose ps
```

### 로그 확인
```bash
# Parser 로그
docker-compose logs -f cpp-parser

# Sender 로그
docker-compose logs -f jsonl-sender

# 전체 로그
docker-compose logs -f
```

---

## 5️⃣ Elasticsearch 연동 테스트

```bash
chmod +x test-elasticsearch-integration.sh
./test-elasticsearch-integration.sh
```

---

## 📊 모니터링 도구

- **Kafka UI**: http://localhost:8090
- **Redis Commander**: http://localhost:8081

---

## 🛑 중지

```bash
cd operation
docker-compose stop        # 중지
docker-compose down        # 삭제 (데이터 보존)
docker-compose down -v     # 삭제 (데이터 포함)
```

---

## 📚 추가 문서

- [Elasticsearch 연동](./ELASTICSEARCH-INTEGRATION.md)
- [Docker 상세 가이드](./README-DOCKER.md)
- [디렉토리 구조](./DIRECTORY-STRUCTURE.md)

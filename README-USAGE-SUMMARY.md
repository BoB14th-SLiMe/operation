# 🚀 OT Security Monitoring System - 완전 가이드

## 📚 문서 구조

| 문서 | 설명 | 대상 |
|------|------|------|
| [QUICKSTART.md](QUICKSTART.md) | 3분 빠른 시작 | 첫 실행 |
| [USAGE.md](USAGE.md) | 전체 사용 가이드 | 운영 관리자 |
| [docker-compose.README.md](docker-compose.README.md) | Docker 상세 설명 | 개발자 |
| README.md (이 파일) | 프로젝트 개요 | 전체 |

---

## ⚡ 30초 시작하기

```bash
cd /home/ryuoo0/security

# 1. 테스트 트래픽 재생 (선택)
sudo nohup ./replay_loop.sh > /dev/null 2>&1 &

# 2. Parser 시작
./start.sh

# 3. 로그 확인
docker-compose logs -f parser
```

---

## 📖 상세 가이드

### 테스트 환경
실제 트래픽이 없을 때:
```bash
# PCAP 파일 무한 재생
sudo nohup ./replay_loop.sh > /dev/null 2>&1 &

# Parser 시작 (veth1 인터페이스)
docker-compose up -d --build

# 재생 중지
sudo pkill -f replay_loop.sh
```

재생 파일:
- `Parser/pcap/normal.pcap` → 정상 트래픽
- `Parser/pcap/attack_01.pcap` → 공격 트래픽

### 운영 환경
실제 네트워크 트래픽 캡처:
```bash
# 1. 인터페이스 확인
ip link show

# 2. .env 설정
nano .env
# NETWORK_INTERFACE=eth0 (또는 any)

# 3. 시작
docker-compose up -d --build
```

### 모니터링
```bash
# 실시간 로그
docker-compose logs -f parser

# 성공 메시지만
docker-compose logs parser | grep "✓"

# Redis 데이터 확인
docker-compose exec redis redis-cli
> KEYS stream:protocol:*
> XREAD COUNT 10 STREAMS stream:protocol:modbus 0

# 성능 모니터링
docker stats
```

---

## 🛠️ 주요 명령어

```bash
# 시작
docker-compose up -d
./start.sh

# 재시작
docker-compose restart parser

# 중지
docker-compose stop

# 로그
docker-compose logs -f parser

# 완전 제거
docker-compose down -v
```

---

## ⚙️ 환경 설정 (.env)

```bash
# 네트워크 (중요!)
NETWORK_INTERFACE=veth1       # PCAP 재생 시
# NETWORK_INTERFACE=any       # 실제 트래픽 캡처 시

# 모드
PARSER_MODE=realtime          # 실시간 스트리밍
# PARSER_MODE=with-files      # 파일 출력 포함

# Elasticsearch
ELASTICSEARCH_HOST=100.126.141.58
ELASTICSEARCH_PORT=9200

# 성능
PARSER_MEMORY_LIMIT=2g
PARSER_CPU_LIMIT=2.0
PARSER_THREADS=0              # 0=자동
```

---

## 🔍 트러블슈팅

### 패킷이 캡처되지 않음
```bash
# 인터페이스 확인
ip link show
grep NETWORK_INTERFACE .env

# 설정 후 재시작
docker-compose restart parser
```

### Redis 연결 실패
```bash
docker-compose ps redis
docker-compose restart redis
docker-compose exec redis redis-cli ping
```

### Elasticsearch 연결 실패
```bash
curl http://100.126.141.58:9200
docker-compose logs parser | grep -i elasticsearch
```

---

## 📊 예상 출력

정상 동작 시 로그:
```
[Redis] ✓ Sent 1000 records to streams
[Redis] ✓ Sent 2000 records to streams
[Elasticsearch] ✓ Queued 1000 documents to bulk
[Elasticsearch] ✓ Sent 1000 documents
[Elasticsearch] ✓ Queued 2000 documents to bulk
[Elasticsearch] ✓ Sent 2015 documents
```

---

## 📁 프로젝트 구조

```
/home/ryuoo0/security/
├── docker-compose.yml      # Docker Compose 설정
├── .env                    # 환경 변수
├── start.sh               # 빠른 시작 스크립트
├── replay_loop.sh         # PCAP 재생 스크립트
├── output/                # 출력 디렉토리
└── Parser/
    ├── Dockerfile
    ├── src/               # C++ 소스
    ├── assets/            # 자산 정보
    └── pcap/              # 테스트 PCAP
```

---

## 🎯 지원 프로토콜

- ✅ Modbus TCP
- ✅ S7comm (Siemens)
- ✅ XGT FEnet (LS Electric)
- ✅ DNP3
- ✅ MMS
- ✅ ARP, DNS

---

## 📞 더 자세한 정보

- 전체 사용법: [USAGE.md](USAGE.md)
- 빠른 시작: [QUICKSTART.md](QUICKSTART.md)
- Docker 상세: [docker-compose.README.md](docker-compose.README.md)

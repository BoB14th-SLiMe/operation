# 📚 Documentation

OT 보안 모니터링 시스템의 문서 디렉토리입니다.

---

## 📖 문서 목록

### 시작 가이드
- **[QUICK-START.md](./QUICK-START.md)** - 5분 빠른 시작
- **[README-DOCKER.md](../README-DOCKER.md)** - Docker 상세 가이드

### 연동 가이드
- **[ELASTICSEARCH-INTEGRATION.md](../ELASTICSEARCH-INTEGRATION.md)** - Elasticsearch 연동

### 구조 및 참고
- **[DIRECTORY-STRUCTURE.md](../DIRECTORY-STRUCTURE.md)** - 최종 디렉토리 구조
- **[MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md)** - /build → /RealtimeParser 변경 가이드

### 아키텍처
- **[realtime-detection-architecture.md](../realtime-detection-architecture.md)** - 실시간 탐지 아키텍처
- **[dfd-review.md](../dfd-review.md)** - DFD 검토
- **[backend-tech-stack-comparison.md](../backend-tech-stack-comparison.md)** - 기술 스택 비교
- **[backend-requirements.md](../backend-requirements.md)** - 백엔드 요구사항

---

## 🗂️ 문서 분류

### 개발자용
- RealtimeParser/README.md - 실시간 Parser
- RealtimeParser/build-guide.md - C++ 빌드
- Parser/README.md - SLM 학습용 Parser
- python-jsonl-sender/README.md - Sender 커스터마이징

### 운영자용
- operation/README.md - Docker 운영
- QUICK-START.md - 빠른 시작
- ELASTICSEARCH-INTEGRATION.md - ES 연동

### 아키텍트용
- realtime-detection-architecture.md - 시스템 설계
- DIRECTORY-STRUCTURE.md - 프로젝트 구조
- backend-tech-stack-comparison.md - 기술 비교

---

## 🔍 빠른 찾기

**Q: 어떻게 시작하나요?**
→ [QUICK-START.md](./QUICK-START.md)

**Q: Elasticsearch 연동은?**
→ [ELASTICSEARCH-INTEGRATION.md](../ELASTICSEARCH-INTEGRATION.md)

**Q: C++ Parser 빌드는?**
→ [RealtimeParser/build-guide.md](../RealtimeParser/build-guide.md)

**Q: 디렉토리 구조는?**
→ [DIRECTORY-STRUCTURE.md](../DIRECTORY-STRUCTURE.md)

**Q: Docker 운영은?**
→ [operation/README.md](../operation/README.md)

---

## 📝 문서 작성 규칙

1. **Markdown 형식** - 모든 문서는 .md 형식
2. **명확한 제목** - H1(#)은 문서당 하나
3. **코드 블록** - 실행 가능한 명령어 제공
4. **이모지 사용** - 가독성 향상
5. **상대 경로** - 다른 문서 참조 시 상대 경로 사용

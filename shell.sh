#!/bin/bash

# ICS Parser 컴파일 에러 자동 수정 스크립트
# 실행: chmod +x fix_compile_errors.sh && ./fix_compile_errors.sh

set -e  # 에러 발생 시 중단

PROJECT_DIR="/home/slime/OT-Security-Monitoring/Parser"
cd "$PROJECT_DIR"

echo "==================================="
echo "컴파일 에러 자동 수정 시작"
echo "==================================="

# 백업 생성
echo "[1/5] 백업 생성 중..."
cp src/protocols/ModbusParser.h src/protocols/ModbusParser.h.bak
cp src/protocols/ModbusParser.cpp src/protocols/ModbusParser.cpp.bak
cp src/PacketParser.cpp src/PacketParser.cpp.bak
echo "✓ 백업 완료"

# 수정 1: ModbusParser.h에 #endif 추가 및 chrono 헤더 추가
echo "[2/5] ModbusParser.h 수정 중..."
cat > src/protocols/ModbusParser.h << 'EOF'
#ifndef MODBUS_PARSER_H
#define MODBUS_PARSER_H

#include "BaseProtocolParser.h"
#include "../AssetManager.h"
#include <map>
#include <chrono>

struct ModbusRequestInfo {
    uint8_t function_code = 0;
    uint16_t start_address = 0;
    std::chrono::steady_clock::time_point timestamp;
};

class ModbusParser : public BaseProtocolParser {
public:
    explicit ModbusParser(AssetManager& assetManager);
    ~ModbusParser() override;
    
    std::string getName() const override;
    bool isProtocol(const PacketInfo& info) const override;
    void parse(const PacketInfo& info) override;

private:
    AssetManager& m_assetManager;
    std::map<std::string, std::map<uint32_t, ModbusRequestInfo>> m_pending_requests;
    
    // 타임아웃 정리
    std::chrono::steady_clock::time_point m_last_cleanup = std::chrono::steady_clock::now();
    
    void cleanupOldRequests() {
        auto now = std::chrono::steady_clock::now();
        if (std::chrono::duration_cast<std::chrono::seconds>(now - m_last_cleanup).count() < 60) {
            return;
        }
        
        for (auto& flow_pair : m_pending_requests) {
            for (auto it = flow_pair.second.begin(); it != flow_pair.second.end();) {
                if (std::chrono::duration_cast<std::chrono::minutes>(now - it->second.timestamp).count() > 5) {
                    it = flow_pair.second.erase(it);
                } else {
                    ++it;
                }
            }
        }
        m_last_cleanup = now;
    }
};

#endif // MODBUS_PARSER_H
EOF
echo "✓ ModbusParser.h 수정 완료"

# 수정 2: ModbusParser.cpp에서 timestamp 초기화 추가
echo "[3/5] ModbusParser.cpp 수정 중..."
# 생성자 부분만 수정
sed -i 's/ModbusParser::ModbusParser(AssetManager& assetManager)/ModbusParser::ModbusParser(AssetManager\& assetManager)\n    : m_assetManager(assetManager), \n      m_last_cleanup(std::chrono::steady_clock::now()) {}/' src/protocols/ModbusParser.cpp.bak

# parse() 함수 시작 부분에 cleanupOldRequests() 추가
sed -i '/void ModbusParser::parse(const PacketInfo& info) {/a\    cleanupOldRequests();' src/protocols/ModbusParser.cpp.bak

# 요청 저장 시 timestamp 추가
sed -i '/ModbusRequestInfo new_req;/a\        new_req.timestamp = std::chrono::steady_clock::now();' src/protocols/ModbusParser.cpp.bak

cp src/protocols/ModbusParser.cpp.bak src/protocols/ModbusParser.cpp
echo "✓ ModbusParser.cpp 수정 완료"

# 수정 3: PacketParser.cpp에서 중복된 sendToBackends 함수 제거
echo "[4/5] PacketParser.cpp 중복 함수 제거 중..."
# 291번째 줄부터 중복된 함수 찾아서 삭제
awk '
/^void PacketParser::sendToBackends/ {
    if (++count > 1) {
        in_duplicate = 1
        brace_count = 0
    }
}
in_duplicate {
    if ($0 ~ /{/) brace_count++
    if ($0 ~ /}/) {
        brace_count--
        if (brace_count == 0) {
            in_duplicate = 0
            next
        }
    }
    next
}
!in_duplicate { print }
' src/PacketParser.cpp.bak > src/PacketParser.cpp
echo "✓ PacketParser.cpp 수정 완료"

# 수정 4: S7CommParser.h와 XgtFenParser.h도 chrono 헤더 확인
echo "[5/5] 다른 파서들도 확인 중..."
for file in src/protocols/S7CommParser.h src/protocols/XgtFenParser.h; do
    if [ -f "$file" ]; then
        if ! grep -q "#include <chrono>" "$file"; then
            # AssetManager.h 다음에 chrono 추가
            sed -i '/#include "..\/AssetManager.h"/a #include <chrono>' "$file"
            echo "✓ $file에 chrono 헤더 추가됨"
        fi
    fi
done

echo ""
echo "==================================="
echo "수정 완료! 다시 빌드 시도 중..."
echo "==================================="

# 빌드 디렉토리 정리 및 재빌드
cd build
make clean
cmake ..
make -j$(nproc)

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 컴파일 성공!"
    echo ""
    echo "실행 파일 확인:"
    ls -lh parser
    echo ""
    echo "테스트 실행 예시:"
    echo "  sudo ./parser -i eth0 --realtime"
else
    echo ""
    echo "❌ 컴파일 실패. 로그를 확인하세요."
    echo ""
    echo "백업 파일 복원:"
    echo "  cp src/protocols/ModbusParser.h.bak src/protocols/ModbusParser.h"
    echo "  cp src/protocols/ModbusParser.cpp.bak src/protocols/ModbusParser.cpp"
    echo "  cp src/PacketParser.cpp.bak src/PacketParser.cpp"
fi
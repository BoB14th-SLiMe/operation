#include "ModbusParser.h"
#include "../UnifiedWriter.h"
#include <iostream>
#include <sstream>
#include <iomanip>
#include <cstring>
#include <vector>
#include <string>

#ifdef _WIN32
#include <winsock2.h>
#else
#include <netinet/in.h>
#include <arpa/inet.h>
#endif

ModbusParser::ModbusParser(AssetManager& assetManager)
    : m_assetManager(assetManager), 
      m_last_cleanup(std::chrono::steady_clock::now()) {}

ModbusParser::~ModbusParser() {}

static uint16_t safe_ntohs(const u_char* ptr) {
    uint16_t val_n;
    memcpy(&val_n, ptr, 2);
    return ntohs(val_n);
}

std::string ModbusParser::getName() const {
    return "modbus";
}

bool ModbusParser::isProtocol(const PacketInfo& info) const {
    // Check if it's TCP and uses Modbus port
    if (info.protocol != 6 || (info.dst_port != 502 && info.src_port != 502)) {
        return false;
    }

    // CRITICAL: Check TCP payload size first
    // ACK packets or empty packets should be rejected immediately
    // Minimum valid Modbus TCP frame: 7 bytes MBAP header + 1 byte function code = 8 bytes
    if (info.payload_size < 8) {
        return false;  // Not enough data for a valid Modbus frame
    }

    // Verify MBAP header: Protocol ID should be 0x0000 (Modbus)
    // Check bytes [2] and [3] for protocol identifier
    if (info.payload[2] != 0x00 || info.payload[3] != 0x00) {
        return false;
    }

    // Check MBAP Length field (bytes 4-5)
    // Length = number of following bytes after the first 6 bytes (Unit ID + PDU)
    uint16_t mbap_length = safe_ntohs(info.payload + 4);

    // Length must be at least 2 (1 byte Unit ID + at least 1 byte PDU/Function Code)
    if (mbap_length < 2) {
        return false;  // Invalid Modbus frame
    }

    // CRITICAL: Verify payload size matches MBAP frame size EXACTLY
    // MBAP header (6 bytes) + MBAP length field value = total frame size
    // This rejects ACK packets with garbage data from previous transmissions
    int expected_frame_size = 6 + mbap_length;
    if (info.payload_size != expected_frame_size) {
        // Payload size mismatch - this is likely an ACK packet with residual data
        // or a fragmented/corrupted packet
        return false;
    }

    return true;
}

void ModbusParser::parse(const PacketInfo& info) {
    // 주기적으로 오래된 요청 정리 (선택사항)
    cleanupOldRequests();
    
    uint16_t trans_id = safe_ntohs(info.payload);
    const u_char* pdu = info.payload + 7;
    int pdu_len = info.payload_size - 7;
    
    if (pdu_len < 1) return;

    bool is_request = (info.dst_port == 502);
    bool is_response = (info.src_port == 502);
    
    std::string direction = is_request ? "request" : "response";
    uint8_t current_fc = pdu[0] & 0x7F;
    
    // Flow 키 생성
    std::string flow_key;
    std::string client_ip, server_ip;
    uint16_t client_port, server_port;
    
    if (info.src_port == 502) {
        server_ip = info.src_ip;
        server_port = info.src_port;
        client_ip = info.dst_ip;
        client_port = info.dst_port;
    } else {
        server_ip = info.dst_ip;
        server_port = info.dst_port;
        client_ip = info.src_ip;
        client_port = info.src_port;
    }
    
    flow_key = client_ip + ":" + std::to_string(client_port) + "->" + 
               server_ip + ":" + std::to_string(server_port);

    uint32_t req_key = (static_cast<uint32_t>(trans_id) << 8) | current_fc;
    ModbusRequestInfo* req_info_ptr = nullptr;
    
    if (is_response) {
        if (m_pending_requests[flow_key].count(req_key)) {
            req_info_ptr = &m_pending_requests[flow_key][req_key];
        }
    } else {
        ModbusRequestInfo new_req;
        new_req.function_code = current_fc;
        new_req.timestamp = std::chrono::steady_clock::now();  // ← 타임스탬프 기록
        
        if (pdu_len >= 3) {
            if ((new_req.function_code >= 1 && new_req.function_code <= 6) ||
                (new_req.function_code == 15 || new_req.function_code == 16)) {
                new_req.start_address = safe_ntohs(pdu + 1);
            }
        }
        
        m_pending_requests[flow_key][req_key] = new_req;
    }
    
    // UnifiedRecord 생성
    UnifiedRecord record = createUnifiedRecord(info, direction);

    // Set Modbus datagram length (PDU length, not total TCP payload)
    // This matches what Wireshark shows as "Len" in Modbus protocol
    record.len = std::to_string(pdu_len);

    // Modbus 필드 채우기
    record.modbus_tid = std::to_string(trans_id);
    record.modbus_fc = std::to_string(current_fc);
    
    // Function code별 파싱
    if (pdu[0] & 0x80) {
        // 에러 응답
        if (pdu_len >= 2) {
            record.modbus_err = std::to_string(pdu[1]);
        }
    } else {
        switch (current_fc) {
            case 1: case 2: case 3: case 4: {
                if (is_response) {
                    if (pdu_len >= 2) {
                        uint8_t byte_count = pdu[1];
                        record.modbus_bc = std::to_string(byte_count);
                        
                        if (byte_count > 0 && pdu_len >= (2 + byte_count)) {
                            const u_char* reg_data = pdu + 2;
                            int num_registers = byte_count / 2;
                            uint16_t start_addr = req_info_ptr ? req_info_ptr->start_address : 0;
                            
                            // 각 레지스터를 개별 레코드로 생성
                            for (int i = 0; i < num_registers; ++i) {
                                UnifiedRecord reg_record = record;
                                uint16_t reg_value = safe_ntohs(reg_data + (i * 2));
                                uint16_t reg_addr = start_addr + i;
                                
                                reg_record.modbus_regs_addr = std::to_string(reg_addr);
                                reg_record.modbus_regs_val = std::to_string(reg_value);
                                
                                std::string translated_addr = m_assetManager.translateModbusAddress(
                                    record.modbus_fc, reg_addr);
                                reg_record.modbus_translated_addr = translated_addr;
                                reg_record.modbus_description = m_assetManager.getDescription(translated_addr);

                                addUnifiedRecord(reg_record);
                            }
                            return; // 이미 모든 레코드 추가됨
                        }
                    }
                } else {
                    if (pdu_len >= 5) {
                        uint16_t start_addr = safe_ntohs(pdu + 1);
                        uint16_t quantity = safe_ntohs(pdu + 3);
                        record.modbus_addr = std::to_string(start_addr);
                        record.modbus_qty = std::to_string(quantity);
                    }
                }
                break;
            }
            case 5: case 6: {
                if (pdu_len >= 5) {
                    record.modbus_addr = std::to_string(safe_ntohs(pdu + 1));
                    record.modbus_val = std::to_string(safe_ntohs(pdu + 3));
                }
                break;
            }
            case 15: case 16: {
                if (is_response) {
                    if (pdu_len >= 5) {
                        record.modbus_addr = std::to_string(safe_ntohs(pdu + 1));
                        record.modbus_qty = std::to_string(safe_ntohs(pdu + 3));
                    }
                } else {
                    if (pdu_len >= 6) {
                        record.modbus_addr = std::to_string(safe_ntohs(pdu + 1));
                        record.modbus_qty = std::to_string(safe_ntohs(pdu + 3));
                        record.modbus_bc = std::to_string(pdu[5]);
                    }
                }
                break;
            }
        }
    }
    
    // Translated address 및 description
    if (!record.modbus_addr.empty()) {
        std::string translated_addr = m_assetManager.translateModbusAddress(
            record.modbus_fc, std::stoul(record.modbus_addr));
        record.modbus_translated_addr = translated_addr;
        record.modbus_description = m_assetManager.getDescription(translated_addr);
    }

    addUnifiedRecord(record);
}
#include <iostream>
#include <cstring>
#include <netinet/in.h>

uint16_t safe_ntohs(const unsigned char* ptr) {
    uint16_t val_n;
    memcpy(&val_n, ptr, 2);
    return ntohs(val_n);
}

bool isModbus(unsigned char* payload, int payload_size) {
    std::cout << "  Payload size: " << payload_size << " bytes" << std::endl;
    
    if (payload_size < 8) {
        std::cout << "  -> Rejected: Too small (< 8 bytes)" << std::endl;
        return false;
    }
    
    if (payload[2] != 0x00 || payload[3] != 0x00) {
        std::cout << "  -> Rejected: Protocol ID not 0x0000" << std::endl;
        return false;
    }
    
    uint16_t mbap_length = safe_ntohs(payload + 4);
    std::cout << "  MBAP Length field: " << mbap_length << std::endl;
    
    if (mbap_length < 2) {
        std::cout << "  -> Rejected: MBAP length < 2" << std::endl;
        return false;
    }
    
    int expected_frame_size = 6 + mbap_length;
    std::cout << "  Expected frame size: " << expected_frame_size << std::endl;
    
    if (payload_size != expected_frame_size) {
        std::cout << "  -> Rejected: Size mismatch (ACK with garbage data)" << std::endl;
        return false;
    }
    
    std::cout << "  -> Accepted: Valid Modbus frame" << std::endl;
    return true;
}

int main() {
    // Real ACK packet from tcpdump (11:52:00.742511)
    // TCP payload portion starting after TCP header
    unsigned char ack_packet[] = {
        0x00, 0x00,  // Transaction ID
        0x00, 0x00,  // Protocol ID = 0
        0x00, 0x07,  // Length = 7 (garbage from previous transmission)
        0x00,        // Unit ID (garbage)
        0x04,        // Function Code (garbage)
        0x04, 0x00   // More garbage data
    };
    
    // Real Modbus request packet from tcpdump (11:52:00.741741)
    // length 12 = Real TCP payload
    unsigned char real_modbus[] = {
        0x00, 0x00,  // Transaction ID
        0x00, 0x00,  // Protocol ID = 0
        0x00, 0x06,  // Length = 6
        0x00,        // Unit ID
        0x03,        // Function Code = Read Holding Registers
        0x00, 0x3F,  // Start address = 63
        0x00, 0x02   // Quantity = 2
    };
    
    std::cout << "Test 1: ACK packet (TCP payload=10, but contains garbage)" << std::endl;
    isModbus(ack_packet, 10);  // Simulating the actual TCP payload size
    
    std::cout << "\nTest 2: Real Modbus request (TCP payload=12)" << std::endl;
    isModbus(real_modbus, 12);
    
    return 0;
}

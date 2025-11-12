#include <iostream>
#include <cstring>
#include <netinet/in.h>

int main() {
    // Simulating a packet with MBAP Length = 0 (ACK packet)
    unsigned char packet1[] = {
        0x00, 0x00,  // Transaction ID
        0x00, 0x00,  // Protocol ID = 0 (Modbus)
        0x00, 0x00,  // Length = 0 (no Unit ID + PDU)
        0x00,        // Unit ID
        0x04,        // Function Code (might be garbage)
        0x00, 0x00   // Extra bytes
    };
    
    // Simulating a real Modbus packet with data
    unsigned char packet2[] = {
        0x00, 0x00,  // Transaction ID
        0x00, 0x00,  // Protocol ID = 0
        0x00, 0x06,  // Length = 6 (1 Unit ID + 5 PDU bytes)
        0x00,        // Unit ID
        0x03,        // Function Code
        0x00, 0x3F,  // Start address = 63
        0x00, 0x02   // Quantity = 2
    };
    
    auto check_mbap = [](unsigned char* payload, int size) {
        if (size < 7) return false;
        if (payload[2] != 0x00 || payload[3] != 0x00) return false;
        
        uint16_t mbap_length;
        memcpy(&mbap_length, payload + 4, 2);
        mbap_length = ntohs(mbap_length);
        
        std::cout << "MBAP Length field: " << mbap_length << std::endl;
        
        if (mbap_length < 2) {
            std::cout << "  -> Rejected: No Modbus data (ACK packet)" << std::endl;
            return false;
        }
        
        if (size < 6 + mbap_length) {
            std::cout << "  -> Rejected: Incomplete frame" << std::endl;
            return false;
        }
        
        std::cout << "  -> Accepted: Valid Modbus packet" << std::endl;
        return true;
    };
    
    std::cout << "Packet 1 (ACK with Len=0): " << std::endl;
    check_mbap(packet1, sizeof(packet1));
    
    std::cout << "\nPacket 2 (Real Modbus with Len=6): " << std::endl;
    check_mbap(packet2, sizeof(packet2));
    
    return 0;
}

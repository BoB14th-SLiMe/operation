#include <iostream>
#include <netinet/in.h>

int main() {
    // Simulating ACK packet scenario
    // Frame: 64 bytes total
    // Ethernet: 14 bytes
    // IP Header: 20 bytes (Total Length field = 40)
    // TCP Header: 20 bytes
    // TCP Payload: 0 bytes (ACK-only)
    
    // But captured buffer might have 10 bytes of garbage
    
    int caplen = 64;                    // Total captured length
    int ethernet_size = 14;
    int l3_payload_size_from_caplen = caplen - ethernet_size;  // = 50
    
    // IP Header fields
    uint16_t ip_total_len_network = htons(40);  // IP Total Len = 40 (IP+TCP headers only)
    int ip_header_len = 20;
    int tcp_header_len = 20;
    
    // Method 1: Using caplen (WRONG - includes garbage)
    int l4_size_method1 = l3_payload_size_from_caplen - ip_header_len;
    int l7_size_method1 = l4_size_method1 - tcp_header_len;
    
    // Method 2: Using IP Total Length (CORRECT)
    uint16_t ip_total_len = ntohs(ip_total_len_network);
    int l4_size_method2 = ip_total_len - ip_header_len;
    int l7_size_method2 = l4_size_method2 - tcp_header_len;
    
    std::cout << "ACK Packet Analysis:" << std::endl;
    std::cout << "Captured length: " << caplen << " bytes" << std::endl;
    std::cout << "IP Total Length: " << ip_total_len << " bytes" << std::endl;
    std::cout << std::endl;
    
    std::cout << "Method 1 (using caplen - WRONG):" << std::endl;
    std::cout << "  L4 payload size: " << l4_size_method1 << " bytes" << std::endl;
    std::cout << "  L7 payload size: " << l7_size_method1 << " bytes (includes garbage!)" << std::endl;
    std::cout << std::endl;
    
    std::cout << "Method 2 (using IP Total Length - CORRECT):" << std::endl;
    std::cout << "  L4 payload size: " << l4_size_method2 << " bytes" << std::endl;
    std::cout << "  L7 payload size: " << l7_size_method2 << " bytes (correct = 0)" << std::endl;
    
    return 0;
}

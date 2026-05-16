#define _CRT_SECURE_NO_WARNINGS
#include "ad_blocker.h"
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iostream>
#include <vector>
#include <cstring>
#include <chrono>
#include <sstream>

#pragma comment(lib, "ws2_32.lib")

AdBlocker::AdBlocker() : isRunning(false), upstreamDNS("8.8.8.8"), dnsPort(53), totalQueries(0), blockedQueries(0) {}

AdBlocker::~AdBlocker() {
    stop();
}

bool AdBlocker::start(int port) {
    if (isRunning) return true;
    
    dnsPort = port;
    isRunning = true;
    
    serverThread = std::thread([this]() {
        WSADATA wsaData;
        if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) return;
        
        SOCKET udpSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (udpSocket == INVALID_SOCKET) return;
        
        sockaddr_in serverAddr;
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_addr.s_addr = INADDR_ANY;
        serverAddr.sin_port = htons((u_short)dnsPort);
        
        if (bind(udpSocket, (sockaddr*)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR) {
            closesocket(udpSocket);
            WSACleanup();
            return;
        }
        
        char buffer[512];
        sockaddr_in clientAddr;
        int clientAddrLen = sizeof(clientAddr);
        
        while (isRunning) {
            fd_set readSet;
            FD_ZERO(&readSet);
            FD_SET(udpSocket, &readSet);
            
            struct timeval timeout;
            timeout.tv_sec = 1;
            timeout.tv_usec = 0;
            
            if (select(0, &readSet, nullptr, nullptr, &timeout) > 0) {
                int bytesReceived = recvfrom(udpSocket, buffer, sizeof(buffer), 0,
                                            (sockaddr*)&clientAddr, &clientAddrLen);
                
                if (bytesReceived > 0) {
                    totalQueries++;
                    
                    // Parse domain from DNS query
                    std::string domain;
                    int pos = 12;
                    while (pos < bytesReceived) {
                        unsigned char len = (unsigned char)buffer[pos++];
                        if (len == 0) break;
                        if (!domain.empty()) domain += ".";
                        domain.append(buffer + pos, len);
                        pos += len;
                    }
                    
                    bool blocked = isBlocked(domain);
                    
                    // Log the query
                    {
                        std::lock_guard<std::mutex> lock(logsMutex);
                        QueryLog log;
                        log.domain = domain;
                        log.blocked = blocked;
                        log.timestamp = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
                        queryLogs.push_back(log);
                        if (queryLogs.size() > 100) queryLogs.erase(queryLogs.begin());
                    }
                    
                    if (blocked) {
                        blockedQueries++;
                        
                        // Build response (0.0.0.0)
                        char response[512];
                        memcpy(response, buffer, bytesReceived);
                        response[2] |= 0x80;  // QR bit
                        response[3] |= 0x80;  // AA bit
                        response[7] = 1;      // Answer count
                        
                        int ansPos = bytesReceived;
                        response[ansPos++] = (unsigned char)0xC0;
                        response[ansPos++] = (unsigned char)0x0C;
                        response[ansPos++] = 0;
                        response[ansPos++] = 1;
                        response[ansPos++] = 0;
                        response[ansPos++] = 1;
                        response[ansPos++] = 0;
                        response[ansPos++] = 0;
                        response[ansPos++] = 0;
                        response[ansPos++] = (unsigned char)0x3C;
                        response[ansPos++] = 0;
                        response[ansPos++] = 4;
                        response[ansPos++] = (unsigned char)0x00;
                        response[ansPos++] = (unsigned char)0x00;
                        response[ansPos++] = (unsigned char)0x00;
                        response[ansPos++] = (unsigned char)0x00;
                        
                        sendto(udpSocket, response, ansPos, 0, (sockaddr*)&clientAddr, clientAddrLen);
                    } else {
                        // Forward to upstream
                        SOCKET forwardSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
                        sockaddr_in upstreamAddr;
                        upstreamAddr.sin_family = AF_INET;
                        upstreamAddr.sin_port = htons(53);
                        inet_pton(AF_INET, upstreamDNS.c_str(), &upstreamAddr.sin_addr);
                        
                        sendto(forwardSocket, buffer, bytesReceived, 0, (sockaddr*)&upstreamAddr, sizeof(upstreamAddr));
                        
                        char response[512];
                        int responseLen = recvfrom(forwardSocket, response, sizeof(response), 0, nullptr, nullptr);
                        if (responseLen > 0) {
                            sendto(udpSocket, response, responseLen, 0, (sockaddr*)&clientAddr, clientAddrLen);
                        }
                        closesocket(forwardSocket);
                    }
                }
            }
        }
        
        closesocket(udpSocket);
        WSACleanup();
    });
    
    return true;
}

void AdBlocker::stop() {
    isRunning = false;
    if (serverThread.joinable()) serverThread.join();
}

void AdBlocker::addDomain(const std::string& domain) {
    std::lock_guard<std::mutex> lock(domainsMutex);
    blockedDomains.insert(domain);
}

void AdBlocker::removeDomain(const std::string& domain) {
    std::lock_guard<std::mutex> lock(domainsMutex);
    blockedDomains.erase(domain);
}

void AdBlocker::clearDomains() {
    std::lock_guard<std::mutex> lock(domainsMutex);
    blockedDomains.clear();
}

void AdBlocker::addWhitelist(const std::string& domain) {
    std::lock_guard<std::mutex> lock(domainsMutex);
    whitelistedDomains.insert(domain);
}

void AdBlocker::removeWhitelist(const std::string& domain) {
    std::lock_guard<std::mutex> lock(domainsMutex);
    whitelistedDomains.erase(domain);
}

void AdBlocker::clearWhitelist() {
    std::lock_guard<std::mutex> lock(domainsMutex);
    whitelistedDomains.clear();
}

bool AdBlocker::isBlocked(const std::string& domain) {
    if (domain.empty()) return false;
    std::lock_guard<std::mutex> lock(domainsMutex);
    
    if (whitelistedDomains.count(domain)) return false;
    if (blockedDomains.count(domain)) return true;
    
    size_t pos = 0;
    std::string current = domain;
    while ((pos = current.find('.')) != std::string::npos) {
        current = current.substr(pos + 1);
        if (whitelistedDomains.count(current)) return false;
        if (blockedDomains.count(current)) return true;
    }
    
    return false;
}

std::string AdBlocker::getLogsJson() {
    std::lock_guard<std::mutex> lock(logsMutex);
    std::stringstream ss;
    ss << "[";
    for (size_t i = 0; i < queryLogs.size(); ++i) {
        ss << "{\"domain\":\"" << queryLogs[i].domain << "\",";
        ss << "\"blocked\":" << (queryLogs[i].blocked ? "true" : "false") << ",";
        ss << "\"time\":" << (long long)queryLogs[i].timestamp << "}";
        if (i < queryLogs.size() - 1) ss << ",";
    }
    ss << "]";
    return ss.str();
}

// C API implementations
extern "C" {
    AdBlocker* adblocker_create() {
        return new AdBlocker();
    }
    
    void adblocker_destroy(AdBlocker* blocker) {
        delete blocker;
    }
    
    bool adblocker_start(AdBlocker* blocker, int port) {
        return blocker ? blocker->start(port) : false;
    }
    
    void adblocker_stop(AdBlocker* blocker) {
        if (blocker) blocker->stop();
    }
    
    bool adblocker_is_running(AdBlocker* blocker) {
        return blocker ? blocker->isServerRunning() : false;
    }
    
    void adblocker_add_domain(AdBlocker* blocker, const char* domain) {
        if (blocker && domain) blocker->addDomain(domain);
    }
    
    void adblocker_remove_domain(AdBlocker* blocker, const char* domain) {
        if (blocker && domain) blocker->removeDomain(domain);
    }
    
    void adblocker_clear_domains(AdBlocker* blocker) {
        if (blocker) blocker->clearDomains();
    }
    
    void adblocker_add_whitelist(AdBlocker* blocker, const char* domain) {
        if (blocker && domain) blocker->addWhitelist(domain);
    }
    
    void adblocker_remove_whitelist(AdBlocker* blocker, const char* domain) {
        if (blocker && domain) blocker->removeWhitelist(domain);
    }
    
    void adblocker_clear_whitelist(AdBlocker* blocker) {
        if (blocker) blocker->clearWhitelist();
    }
    
    void adblocker_set_upstream(AdBlocker* blocker, const char* dns) {
        if (blocker && dns) blocker->setUpstreamDNS(dns);
    }
    
    int adblocker_get_total_queries(AdBlocker* blocker) {
        return blocker ? blocker->getTotalQueries() : 0;
    }
    
    int adblocker_get_blocked_queries(AdBlocker* blocker) {
        return blocker ? blocker->getBlockedQueries() : 0;
    }
    
    const char* adblocker_get_logs(AdBlocker* blocker) {
        if (!blocker) return nullptr;
        std::string logs = blocker->getLogsJson();
        char* cstr = (char*)malloc(logs.length() + 1);
        if (cstr) {
            memcpy(cstr, logs.c_str(), logs.length() + 1);
        }
        return cstr;
    }
    
    void adblocker_free_string(char* str) {
        if (str) free(str);
    }
}

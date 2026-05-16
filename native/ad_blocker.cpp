#include "ad_blocker.h"
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iostream>
#include <sstream>
#include <regex>
#include <vector>
#include <cstring>

#pragma comment(lib, "ws2_32.lib")

static size_t WriteCallback(void* contents, size_t size, size_t nmemb, std::string* response) {
    size_t totalSize = size * nmemb;
    response->append((char*)contents, totalSize);
    return totalSize;
}

AdBlocker::AdBlocker(const std::string& dbPath) : isRunning(false), upstreamDNS("8.8.8.8"), dnsPort(53) {
    db = new DomainDatabase(dbPath);
    db->initialize();
    curl_global_init(CURL_GLOBAL_DEFAULT);
}

AdBlocker::~AdBlocker() {
    stop();
    delete db;
    curl_global_cleanup();
}

void AdBlocker::parseAndStoreDomains(const std::string& content, const std::string& source) {
    std::istringstream iss(content);
    std::string line;
    std::vector<std::string> domains;
    std::regex hostPattern(R"(^(?:0\.0\.0\.0|127\.0\.0\.1)\s+([a-zA-Z0-9\.\-_]+))");
    std::regex adblockPattern(R"(^\|\|([a-zA-Z0-9\.\-_]+)\^)");
    std::smatch match;
    
    while (std::getline(iss, line)) {
        if (line.empty() || line[0] == '#' || line[0] == '!') continue;
        
        std::string domain;
        
        if (std::regex_search(line, match, hostPattern) && match.size() > 1) {
            domain = match[1];
        } else if (std::regex_search(line, match, adblockPattern) && match.size() > 1) {
            domain = match[1];
        } else if (line.find('.') != std::string::npos && line.find(' ') == std::string::npos) {
            // Trim whitespace
            line.erase(0, line.find_first_not_of(" \t"));
            line.erase(line.find_last_not_of(" \t") + 1);
            domain = line;
        }
        
        if (!domain.empty() && domain.find('#') == std::string::npos) {
            domains.push_back(domain);
            
            // Batch insert every 1000 domains
            if (domains.size() >= 1000) {
                db->addDomainsBatch(domains, source);
                domains.clear();
            }
        }
    }
    
    // Insert remaining domains
    if (!domains.empty()) {
        db->addDomainsBatch(domains, source);
    }
}

void AdBlocker::fetchAndUpdateBlocklists() {
    auto sources = db->getAllSources();
    CURL* curl = curl_easy_init();
    
    if (!curl) return;
    
    for (const auto& source : sources) {
        std::string response;
        curl_easy_setopt(curl, CURLOPT_URL, source.url.c_str());
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
        curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
        curl_easy_setopt(curl, CURLOPT_USERAGENT, "AdMenii/2.0");
        
        CURLcode res = curl_easy_perform(curl);
        if (res == CURLE_OK && !response.empty()) {
            // Clear old domains from this source
            db->deleteDomainsBySource(source.name);
            // Add new domains
            parseAndStoreDomains(response, source.name);
            // Update last update time
            db->updateBlocklistSource(source.url, "");
        }
    }
    
    curl_easy_cleanup(curl);
    
    // Add YouTube specific domains
    std::vector<std::string> youtubeAds = {
        "googlevideo.com", "youtubei.googleapis.com", "yt3.ggpht.com",
        "ggpht.com", "ytimg.com", "youtube-nocookie.com", "youtu.be",
        "ad.doubleclick.net", "ad.googlesyndication.com", "pagead2.googlesyndication.com",
        "doubleclick.net", "googleadservices.com", "googletagmanager.com"
    };
    
    for (const auto& domain : youtubeAds) {
        db->addDomain(domain, "youtube", "ads");
    }
    
    db->deduplicateDomains();
}

void AdBlocker::backgroundUpdater() {
    while (isRunning) {
        // Sleep for 48 hours or until stopped
        for (int i = 0; i < 48 * 60 && isRunning; ++i) {
            std::this_thread::sleep_for(std::chrono::minutes(1));
        }
        if (isRunning) {
            fetchAndUpdateBlocklists();
        }
    }
}

bool AdBlocker::start(int port) {
    if (isRunning) return true;
    
    dnsPort = port;
    isRunning = true;
    
    // Start DNS server thread
    serverThread = std::thread([this]() {
        WSADATA wsaData;
        if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) return;
        
        SOCKET udpSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (udpSocket == INVALID_SOCKET) return;
        
        sockaddr_in serverAddr;
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_addr.s_addr = INADDR_ANY;
        serverAddr.sin_port = htons(dnsPort);
        
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
                    
                    bool whitelisted = !domain.empty() && db->isWhitelisted(domain);
                    bool blocked = !whitelisted && !domain.empty() && db->domainExists(domain);
                    
                    if (blocked) {
                        db->updateDomainHitCount(domain);
                    }
                    
                    // Build response (simplified)
                    char response[512];
                    memcpy(response, buffer, bytesReceived);
                    
                    if (blocked) {
                        // Return 0.0.0.0
                        response[2] |= 0x80;  // QR bit
                        response[3] |= 0x80;  // AA bit
                        response[7] = 1;      // Answer count
                        
                        int ansPos = bytesReceived;
                        response[ansPos++] = (char)0xC0;
                        response[ansPos++] = (char)0x0C;
                        response[ansPos++] = 0;
                        response[ansPos++] = 1;
                        response[ansPos++] = 0;
                        response[ansPos++] = 1;
                        response[ansPos++] = 0;
                        response[ansPos++] = 0;
                        response[ansPos++] = 0;
                        response[ansPos++] = (char)0x3C; // 60s TTL
                        response[ansPos++] = 0;
                        response[ansPos++] = 4;
                        response[ansPos++] = 0;
                        response[ansPos++] = 0;
                        response[ansPos++] = 0;
                        response[ansPos++] = 0;
                        
                        sendto(udpSocket, response, ansPos, 0, (sockaddr*)&clientAddr, clientAddrLen);
                    } else {
                        // Forward to upstream
                        SOCKET forwardSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
                        sockaddr_in upstreamAddr;
                        upstreamAddr.sin_family = AF_INET;
                        upstreamAddr.sin_port = htons(53);
                        inet_pton(AF_INET, upstreamDNS.c_str(), &upstreamAddr.sin_addr);
                        
                        sendto(forwardSocket, buffer, bytesReceived, 0, (sockaddr*)&upstreamAddr, sizeof(upstreamAddr));
                        
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
    
    // Start updater thread
    updaterThread = std::thread(&AdBlocker::backgroundUpdater, this);
    
    return true;
}

void AdBlocker::stop() {
    isRunning = false;
    if (serverThread.joinable()) serverThread.join();
    if (updaterThread.joinable()) updaterThread.join();
}

bool AdBlocker::addDomain(const std::string& domain, const std::string& category) {
    return db->addDomain(domain, "manual", category);
}

bool AdBlocker::removeDomain(const std::string& domain) {
    return db->removeDomain(domain);
}

bool AdBlocker::isDomainBlocked(const std::string& domain) {
    return db->domainExists(domain);
}

void AdBlocker::updateAllBlocklists() {
    fetchAndUpdateBlocklists();
}

void AdBlocker::updateBlocklistFromURL(const std::string& url, const std::string& source) {
    CURL* curl = curl_easy_init();
    if (!curl) return;
    
    std::string response;
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
    
    CURLcode res = curl_easy_perform(curl);
    if (res == CURLE_OK) {
        db->deleteDomainsBySource(source);
        parseAndStoreDomains(response, source);
    }
    
    curl_easy_cleanup(curl);
}

// C API implementations
extern "C" {
    AdBlocker* adblocker_create(const char* dbPath) {
        return new AdBlocker(dbPath ? dbPath : "admenii.db");
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
    
    bool adblocker_add_domain(AdBlocker* blocker, const char* domain, const char* category) {
        return blocker ? blocker->addDomain(domain, category ? category : "ads") : false;
    }
    
    bool adblocker_remove_domain(AdBlocker* blocker, const char* domain) {
        return blocker ? blocker->removeDomain(domain) : false;
    }
    
    bool adblocker_is_blocked(AdBlocker* blocker, const char* domain) {
        return blocker ? blocker->isDomainBlocked(domain) : false;
    }
    
    void adblocker_update_blocklists(AdBlocker* blocker) {
        if (blocker) blocker->updateAllBlocklists();
    }
    
    void adblocker_update_from_url(AdBlocker* blocker, const char* url, const char* source) {
        if (blocker) blocker->updateBlocklistFromURL(url, source);
    }
    
    void adblocker_set_upstream(AdBlocker* blocker, const char* dns) {
        if (blocker && dns) blocker->setUpstreamDNS(dns);
    }
    
    char* adblocker_get_upstream(AdBlocker* blocker) {
        if (!blocker) return _strdup("8.8.8.8");
        return _strdup(blocker->getUpstreamDNS().c_str());
    }
    
    char* adblocker_get_stats_json(AdBlocker* blocker) {
        if (!blocker) return _strdup("{}");
        return database_get_stats_json(blocker->getDatabase());
    }
    
    char* adblocker_get_domains_json(AdBlocker* blocker, int limit) {
        if (!blocker) return _strdup("[]");
        return database_get_all_domains_json(blocker->getDatabase(), limit, 0);
    }
    
    char* adblocker_get_sources_json(AdBlocker* blocker) {
        if (!blocker) return _strdup("[]");
        return database_get_sources_json(blocker->getDatabase());
    }
}

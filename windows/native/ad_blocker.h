#ifndef AD_BLOCKER_H
#define AD_BLOCKER_H

#include <string>
#include <thread>
#include <atomic>
#include <unordered_set>
#include <mutex>
#include <vector>

class AdBlocker {
private:
    std::unordered_set<std::string> blockedDomains;
    std::unordered_set<std::string> whitelistedDomains;
    std::mutex domainsMutex;
    
    struct QueryLog {
        std::string domain;
        bool blocked;
        long long timestamp;
    };
    std::vector<QueryLog> queryLogs;
    std::mutex logsMutex;
    
    std::atomic<bool> isRunning;
    std::thread serverThread;
    std::string upstreamDNS;
    int dnsPort;
    
    // Stats (managed in C++ for real-time tracking)
    std::atomic<int> totalQueries;
    std::atomic<int> blockedQueries;
    
public:
    AdBlocker();
    ~AdBlocker();
    
    bool start(int port = 53);
    void stop();
    bool isServerRunning() const { return isRunning; }
    
    void addDomain(const std::string& domain);
    void removeDomain(const std::string& domain);
    void clearDomains();
    
    void addWhitelist(const std::string& domain);
    void removeWhitelist(const std::string& domain);
    void clearWhitelist();
    
    bool isBlocked(const std::string& domain);
    
    void setUpstreamDNS(const std::string& dns) { upstreamDNS = dns; }
    std::string getUpstreamDNS() const { return upstreamDNS; }
    
    int getTotalQueries() const { return totalQueries; }
    int getBlockedQueries() const { return blockedQueries; }
    void resetStats() { totalQueries = 0; blockedQueries = 0; }
    
    std::string getLogsJson();
};

// C API for Flutter FFI
extern "C" {
    __declspec(dllexport) AdBlocker* adblocker_create();
    __declspec(dllexport) void adblocker_destroy(AdBlocker* blocker);
    
    __declspec(dllexport) bool adblocker_start(AdBlocker* blocker, int port);
    __declspec(dllexport) void adblocker_stop(AdBlocker* blocker);
    __declspec(dllexport) bool adblocker_is_running(AdBlocker* blocker);
    
    __declspec(dllexport) void adblocker_add_domain(AdBlocker* blocker, const char* domain);
    __declspec(dllexport) void adblocker_remove_domain(AdBlocker* blocker, const char* domain);
    __declspec(dllexport) void adblocker_clear_domains(AdBlocker* blocker);
    
    __declspec(dllexport) void adblocker_add_whitelist(AdBlocker* blocker, const char* domain);
    __declspec(dllexport) void adblocker_remove_whitelist(AdBlocker* blocker, const char* domain);
    __declspec(dllexport) void adblocker_clear_whitelist(AdBlocker* blocker);
    
    __declspec(dllexport) void adblocker_set_upstream(AdBlocker* blocker, const char* dns);
    __declspec(dllexport) int adblocker_get_total_queries(AdBlocker* blocker);
    __declspec(dllexport) int adblocker_get_blocked_queries(AdBlocker* blocker);
    
    __declspec(dllexport) const char* adblocker_get_logs(AdBlocker* blocker);
    __declspec(dllexport) void adblocker_free_string(char* str);
}

#endif

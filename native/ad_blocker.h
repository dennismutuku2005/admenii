#ifndef AD_BLOCKER_H
#define AD_BLOCKER_H

#include "database.h"
#include <string>
#include <thread>
#include <atomic>
#include <curl/curl.h>

class AdBlocker {
private:
    DomainDatabase* db;
    std::atomic<bool> isRunning;
    std::thread serverThread;
    std::thread updaterThread;
    std::string upstreamDNS;
    int dnsPort;
    
    void fetchAndUpdateBlocklists();
    void backgroundUpdater();
    void parseAndStoreDomains(const std::string& content, const std::string& source);
    
public:
    AdBlocker(const std::string& dbPath = "admenii.db");
    ~AdBlocker();
    
    bool start(int port = 53);
    void stop();
    bool isServerRunning() const { return isRunning; }
    
    bool addDomain(const std::string& domain, const std::string& category = "ads");
    bool removeDomain(const std::string& domain);
    bool isDomainBlocked(const std::string& domain);
    
    void updateAllBlocklists();
    void updateBlocklistFromURL(const std::string& url, const std::string& source);
    
    void setUpstreamDNS(const std::string& dns) { upstreamDNS = dns; }
    std::string getUpstreamDNS() const { return upstreamDNS; }
    
    DomainDatabase* getDatabase() { return db; }
};

// C API
extern "C" {
    __declspec(dllexport) AdBlocker* adblocker_create(const char* dbPath);
    __declspec(dllexport) void adblocker_destroy(AdBlocker* blocker);
    
    __declspec(dllexport) bool adblocker_start(AdBlocker* blocker, int port);
    __declspec(dllexport) void adblocker_stop(AdBlocker* blocker);
    __declspec(dllexport) bool adblocker_is_running(AdBlocker* blocker);
    
    __declspec(dllexport) bool adblocker_add_domain(AdBlocker* blocker, const char* domain, const char* category);
    __declspec(dllexport) bool adblocker_remove_domain(AdBlocker* blocker, const char* domain);
    __declspec(dllexport) bool adblocker_is_blocked(AdBlocker* blocker, const char* domain);
    
    __declspec(dllexport) void adblocker_update_blocklists(AdBlocker* blocker);
    __declspec(dllexport) void adblocker_update_from_url(AdBlocker* blocker, const char* url, const char* source);
    
    __declspec(dllexport) void adblocker_set_upstream(AdBlocker* blocker, const char* dns);
    __declspec(dllexport) char* adblocker_get_upstream(AdBlocker* blocker);
    
    __declspec(dllexport) char* adblocker_get_stats_json(AdBlocker* blocker);
    __declspec(dllexport) char* adblocker_get_domains_json(AdBlocker* blocker, int limit);
    __declspec(dllexport) char* adblocker_get_sources_json(AdBlocker* blocker);
}

#endif

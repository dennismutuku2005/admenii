#ifndef DATABASE_H
#define DATABASE_H

#include <sqlite3.h>
#include <string>
#include <vector>
#include <map>
#include <mutex>

struct DomainRecord {
    int id;
    std::string domain;
    std::string source;
    std::string addedDate;
    int hitCount;
    bool isActive;
    std::string category;
};

struct BlocklistSource {
    int id;
    std::string url;
    std::string name;
    std::string lastUpdate;
    bool isActive;
    int updateInterval; // in hours
};

class DomainDatabase {
private:
    sqlite3* db;
    std::mutex dbMutex;
    std::string dbPath;
    
    bool executeSQL(const std::string& sql);
    bool prepareAndExecute(sqlite3_stmt* stmt);
    
public:
    DomainDatabase(const std::string& path = "admenii.db");
    ~DomainDatabase();
    
    bool initialize();
    bool migrate();
    
    // Domain management
    bool addDomain(const std::string& domain, const std::string& source = "manual", const std::string& category = "ads");
    bool removeDomain(const std::string& domain);
    bool domainExists(const std::string& domain);
    std::vector<DomainRecord> getAllDomains(int limit = -1, int offset = 0);
    
    // Whitelist management
    bool addWhitelistedDomain(const std::string& domain);
    bool removeWhitelistedDomain(const std::string& domain);
    bool isWhitelisted(const std::string& domain);
    std::vector<std::string> getWhitelistedDomains();
    
    // Blocklist sources management
    bool addBlocklistSource(const std::string& url, const std::string& name, int updateInterval = 48);
    bool updateBlocklistSource(const std::string& url, const std::string& lastUpdate);
    std::vector<BlocklistSource> getAllSources();
    bool removeBlocklistSource(const std::string& url);
    bool isSourceExists(const std::string& url);
    
    // Batch operations
    bool addDomainsBatch(const std::vector<std::string>& domains, const std::string& source);
    bool deleteDomainsBySource(const std::string& source);
    
    // Statistics
    std::map<std::string, int> getCategoryStats();
    std::map<std::string, int> getSourceStats();
    int getTotalQueries();
    int getTotalBlockedQueries();
    
    // Backup and restore
    bool backup(const std::string& backupPath);
    bool restore(const std::string& backupPath);
    bool vacuum();
    
    // Cleanup
    bool removeOldEntries(int daysOld = 30);
    bool deduplicateDomains();
};

// C API for Flutter FFI
extern "C" {
    __declspec(dllexport) DomainDatabase* database_create(const char* path);
    __declspec(dllexport) void database_destroy(DomainDatabase* db);
    
    __declspec(dllexport) bool database_initialize(DomainDatabase* db);
    __declspec(dllexport) bool database_add_domain(DomainDatabase* db, const char* domain, const char* source, const char* category);
    __declspec(dllexport) bool database_remove_domain(DomainDatabase* db, const char* domain);
    __declspec(dllexport) bool database_domain_exists(DomainDatabase* db, const char* domain);
    
    __declspec(dllexport) char* database_get_all_domains_json(DomainDatabase* db, int limit, int offset);
    __declspec(dllexport) char* database_search_domains_json(DomainDatabase* db, const char* pattern);
    __declspec(dllexport) bool database_update_hit_count(DomainDatabase* db, const char* domain);
    __declspec(dllexport) char* database_get_top_blocked_json(DomainDatabase* db, int limit);
    __declspec(dllexport) int database_get_domain_count(DomainDatabase* db);
    
    __declspec(dllexport) bool database_add_source(DomainDatabase* db, const char* url, const char* name, int updateInterval);
    __declspec(dllexport) char* database_get_sources_json(DomainDatabase* db);
    
    __declspec(dllexport) bool database_add_whitelisted(DomainDatabase* db, const char* domain);
    __declspec(dllexport) bool database_remove_whitelisted(DomainDatabase* db, const char* domain);
    __declspec(dllexport) char* database_get_whitelisted_json(DomainDatabase* db);
    
    __declspec(dllexport) bool database_add_batch(DomainDatabase* db, const char** domains, int count, const char* source);
    __declspec(dllexport) bool database_clear_source(DomainDatabase* db, const char* source);
    
    __declspec(dllexport) char* database_get_stats_json(DomainDatabase* db);
    __declspec(dllexport) bool database_backup(DomainDatabase* db, const char* backupPath);
    __declspec(dllexport) bool database_vacuum(DomainDatabase* db);
    
    __declspec(dllexport) void free_string(char* str);
}

#endif

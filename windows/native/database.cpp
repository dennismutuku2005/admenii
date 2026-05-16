#include "database.h"
#include <nlohmann/json.hpp>
#include <sstream>
#include <chrono>
#include <iomanip>
#include <ctime>
#include <cstring>

using json = nlohmann::json;

DomainDatabase::DomainDatabase(const std::string& path) : db(nullptr), dbPath(path) {}

DomainDatabase::~DomainDatabase() {
    if (db) {
        sqlite3_close(db);
    }
}

bool DomainDatabase::executeSQL(const std::string& sql) {
    std::lock_guard<std::mutex> lock(dbMutex);
    char* errMsg = nullptr;
    int rc = sqlite3_exec(db, sql.c_str(), nullptr, nullptr, &errMsg);
    if (rc != SQLITE_OK) {
        sqlite3_free(errMsg);
        return false;
    }
    return true;
}

bool DomainDatabase::initialize() {
    int rc = sqlite3_open(dbPath.c_str(), &db);
    if (rc != SQLITE_OK) {
        return false;
    }
    
    // Enable WAL mode for better concurrency
    executeSQL("PRAGMA journal_mode=WAL;");
    executeSQL("PRAGMA synchronous=NORMAL;");
    executeSQL("PRAGMA cache_size=-20000;"); // 20MB cache
    
    return migrate();
}

bool DomainDatabase::migrate() {
    // Domains table
    std::string createDomains = R"(
        CREATE TABLE IF NOT EXISTS domains (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            domain TEXT NOT NULL UNIQUE,
            source TEXT NOT NULL DEFAULT 'manual',
            category TEXT DEFAULT 'ads',
            added_date DATETIME DEFAULT CURRENT_TIMESTAMP,
            last_hit DATETIME,
            hit_count INTEGER DEFAULT 0,
            is_active INTEGER DEFAULT 1
        );
    )";
    
    if (!executeSQL(createDomains)) return false;
    executeSQL("CREATE INDEX IF NOT EXISTS idx_domain ON domains(domain);");
    executeSQL("CREATE INDEX IF NOT EXISTS idx_source ON domains(source);");
    executeSQL("CREATE INDEX IF NOT EXISTS idx_hit_count ON domains(hit_count DESC);");
    
    // Blocklist sources table
    std::string createSources = R"(
        CREATE TABLE IF NOT EXISTS blocklist_sources (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            last_update DATETIME,
            update_interval INTEGER DEFAULT 48,
            is_active INTEGER DEFAULT 1,
            last_status INTEGER DEFAULT 0
        );
    )";
    
    if (!executeSQL(createSources)) return false;
    executeSQL("CREATE INDEX IF NOT EXISTS idx_url ON blocklist_sources(url);");
    
    // Whitelist table
    std::string createWhitelist = R"(
        CREATE TABLE IF NOT EXISTS whitelist (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            domain TEXT NOT NULL UNIQUE,
            added_date DATETIME DEFAULT CURRENT_TIMESTAMP
        );
    )";
    if (!executeSQL(createWhitelist)) return false;
    executeSQL("CREATE INDEX IF NOT EXISTS idx_whitelist_domain ON whitelist(domain);");
    
    // Query log table
    std::string createQueryLog = R"(
        CREATE TABLE IF NOT EXISTS query_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            domain TEXT NOT NULL,
            query_time DATETIME DEFAULT CURRENT_TIMESTAMP,
            was_blocked INTEGER DEFAULT 0,
            client_ip TEXT
        );
    )";
    
    if (!executeSQL(createQueryLog)) return false;
    executeSQL("CREATE INDEX IF NOT EXISTS idx_query_time ON query_log(query_time DESC);");
    executeSQL("CREATE INDEX IF NOT EXISTS idx_log_domain ON query_log(domain);");
    
    // Statistics table
    std::string createStats = R"(
        CREATE TABLE IF NOT EXISTS statistics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stat_date DATE DEFAULT CURRENT_DATE,
            total_queries INTEGER DEFAULT 0,
            blocked_queries INTEGER DEFAULT 0,
            UNIQUE(stat_date)
        );
    )";
    
    if (!executeSQL(createStats)) return false;
    
    // Add default sources if table is empty
    auto sources = getAllSources();
    if (sources.empty()) {
        addBlocklistSource("https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts", "StevenBlack Unified Hosts", 48);
        addBlocklistSource("https://raw.githubusercontent.com/AdAway/adaway.github.io/master/hosts.txt", "AdAway Hosts", 48);
        addBlocklistSource("https://someonewhocares.org/hosts/zero/hosts", "Dan Pollock Hosts", 48);
    }
    
    return true;
}

bool DomainDatabase::addDomain(const std::string& domain, const std::string& source, const std::string& category) {
    std::lock_guard<std::mutex> lock(dbMutex);
    
    const char* sql = "INSERT OR IGNORE INTO domains (domain, source, category, added_date) VALUES (?, ?, ?, datetime('now'));";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return false;
    
    sqlite3_bind_text(stmt, 1, domain.c_str(), -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 2, source.c_str(), -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 3, category.c_str(), -1, SQLITE_STATIC);
    
    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    
    return rc == SQLITE_DONE;
}

bool DomainDatabase::removeDomain(const std::string& domain) {
    std::lock_guard<std::mutex> lock(dbMutex);
    
    const char* sql = "DELETE FROM domains WHERE domain = ?;";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return false;
    
    sqlite3_bind_text(stmt, 1, domain.c_str(), -1, SQLITE_STATIC);
    
    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    
    return rc == SQLITE_DONE;
}

bool DomainDatabase::domainExists(const std::string& domain) {
    std::lock_guard<std::mutex> lock(dbMutex);
    
    const char* sql = "SELECT 1 FROM domains WHERE domain = ? AND is_active = 1;";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return false;
    
    sqlite3_bind_text(stmt, 1, domain.c_str(), -1, SQLITE_STATIC);
    
    bool exists = (sqlite3_step(stmt) == SQLITE_ROW);
    sqlite3_finalize(stmt);
    
    if (exists) return true;
    
    // Check for wildcard/subdomain matching
    const char* wildcardSql = "SELECT domain FROM domains WHERE is_active = 1 AND ? LIKE '%' || domain;";
    rc = sqlite3_prepare_v2(db, wildcardSql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return false;
    
    sqlite3_bind_text(stmt, 1, domain.c_str(), -1, SQLITE_STATIC);
    
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        const char* blockedDomain = (const char*)sqlite3_column_text(stmt, 0);
        std::string blocked(blockedDomain);
        
        // Check if domain is subdomain or exact match
        if (domain == blocked || 
            (domain.length() > blocked.length() && 
             domain.substr(domain.length() - blocked.length() - 1) == "." + blocked)) {
            sqlite3_finalize(stmt);
            return true;
        }
    }
    
    sqlite3_finalize(stmt);
    return false;
}

bool DomainDatabase::updateDomainHitCount(const std::string& domain) {
    std::lock_guard<std::mutex> lock(dbMutex);
    
    const char* sql = "UPDATE domains SET hit_count = hit_count + 1, last_hit = datetime('now') WHERE domain = ?;";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return false;
    
    sqlite3_bind_text(stmt, 1, domain.c_str(), -1, SQLITE_STATIC);
    
    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    
    return rc == SQLITE_DONE;
}

std::vector<DomainRecord> DomainDatabase::getAllDomains(int limit, int offset) {
    std::lock_guard<std::mutex> lock(dbMutex);
    std::vector<DomainRecord> domains;
    
    const char* sql = "SELECT id, domain, source, added_date, hit_count, is_active, category FROM domains ORDER BY hit_count DESC LIMIT ? OFFSET ?;";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return domains;
    
    sqlite3_bind_int(stmt, 1, limit);
    sqlite3_bind_int(stmt, 2, offset);
    
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        DomainRecord record;
        record.id = sqlite3_column_int(stmt, 0);
        record.domain = (const char*)sqlite3_column_text(stmt, 1);
        record.source = (const char*)sqlite3_column_text(stmt, 2);
        record.addedDate = (const char*)sqlite3_column_text(stmt, 3);
        record.hitCount = sqlite3_column_int(stmt, 4);
        record.isActive = sqlite3_column_int(stmt, 5);
        record.category = (const char*)sqlite3_column_text(stmt, 6);
        domains.push_back(record);
    }
    
    sqlite3_finalize(stmt);
    return domains;
}

bool DomainDatabase::addBlocklistSource(const std::string& url, const std::string& name, int updateInterval) {
    std::lock_guard<std::mutex> lock(dbMutex);
    
    const char* sql = "INSERT OR REPLACE INTO blocklist_sources (url, name, update_interval, is_active) VALUES (?, ?, ?, 1);";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return false;
    
    sqlite3_bind_text(stmt, 1, url.c_str(), -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 2, name.c_str(), -1, SQLITE_STATIC);
    sqlite3_bind_int(stmt, 3, updateInterval);
    
    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    
    return rc == SQLITE_DONE;
}

bool DomainDatabase::addDomainsBatch(const std::vector<std::string>& domains, const std::string& source) {
    std::lock_guard<std::mutex> lock(dbMutex);
    
    executeSQL("BEGIN TRANSACTION;");
    const char* sql = "INSERT OR IGNORE INTO domains (domain, source, added_date) VALUES (?, ?, datetime('now'));";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) {
        executeSQL("ROLLBACK;");
        return false;
    }
    
    for (const auto& domain : domains) {
        sqlite3_reset(stmt);
        sqlite3_bind_text(stmt, 1, domain.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, source.c_str(), -1, SQLITE_STATIC);
        sqlite3_step(stmt);
    }
    
    sqlite3_finalize(stmt);
    executeSQL("COMMIT;");
    return true;
}

int DomainDatabase::getDomainCount() {
    std::lock_guard<std::mutex> lock(dbMutex);
    
    const char* sql = "SELECT COUNT(*) FROM domains WHERE is_active = 1;";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return 0;
    
    rc = sqlite3_step(stmt);
    int count = (rc == SQLITE_ROW) ? sqlite3_column_int(stmt, 0) : 0;
    
    sqlite3_finalize(stmt);
    return count;
}

std::vector<DomainRecord> DomainDatabase::getTopBlockedDomains(int limit) {
    std::lock_guard<std::mutex> lock(dbMutex);
    std::vector<DomainRecord> domains;
    
    const char* sql = "SELECT id, domain, source, added_date, hit_count, is_active, category FROM domains WHERE hit_count > 0 ORDER BY hit_count DESC LIMIT ?;";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return domains;
    
    sqlite3_bind_int(stmt, 1, limit);
    
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        DomainRecord record;
        record.id = sqlite3_column_int(stmt, 0);
        record.domain = (const char*)sqlite3_column_text(stmt, 1);
        record.source = (const char*)sqlite3_column_text(stmt, 2);
        record.addedDate = (const char*)sqlite3_column_text(stmt, 3);
        record.hitCount = sqlite3_column_int(stmt, 4);
        record.isActive = sqlite3_column_int(stmt, 5);
        record.category = (const char*)sqlite3_column_text(stmt, 6);
        domains.push_back(record);
    }
    
    sqlite3_finalize(stmt);
    return domains;
}

std::map<std::string, int> DomainDatabase::getCategoryStats() {
    std::lock_guard<std::mutex> lock(dbMutex);
    std::map<std::string, int> stats;
    
    const char* sql = "SELECT category, COUNT(*) FROM domains WHERE is_active = 1 GROUP BY category;";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return stats;
    
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        const char* cat = (const char*)sqlite3_column_text(stmt, 0);
        std::string category = cat ? cat : "unknown";
        int count = sqlite3_column_int(stmt, 1);
        stats[category] = count;
    }
    
    sqlite3_finalize(stmt);
    return stats;
}

bool DomainDatabase::deduplicateDomains() {
    std::lock_guard<std::mutex> lock(dbMutex);
    
    const char* sql = "DELETE FROM domains WHERE id NOT IN (SELECT MIN(id) FROM domains GROUP BY domain);";
    return executeSQL(sql);
}

bool DomainDatabase::vacuum() {
    return executeSQL("VACUUM;");
}

// C API implementations
extern "C" {
    DomainDatabase* database_create(const char* path) {
        return new DomainDatabase(path ? path : "admenii.db");
    }
    
    void database_destroy(DomainDatabase* db) {
        delete db;
    }
    
    bool database_initialize(DomainDatabase* db) {
        return db ? db->initialize() : false;
    }
    
    bool database_add_domain(DomainDatabase* db, const char* domain, const char* source, const char* category) {
        return db ? db->addDomain(domain, source ? source : "manual", category ? category : "ads") : false;
    }
    
    bool database_remove_domain(DomainDatabase* db, const char* domain) {
        return db ? db->removeDomain(domain) : false;
    }
    
    bool database_domain_exists(DomainDatabase* db, const char* domain) {
        return db ? db->domainExists(domain) : false;
    }
    
    char* database_get_all_domains_json(DomainDatabase* db, int limit, int offset) {
        if (!db) return _strdup("[]");
        
        auto domains = db->getAllDomains(limit, offset);
        json j = json::array();
        
        for (const auto& d : domains) {
            json item;
            item["id"] = d.id;
            item["domain"] = d.domain;
            item["source"] = d.source;
            item["added_date"] = d.addedDate;
            item["hit_count"] = d.hitCount;
            item["is_active"] = d.isActive;
            item["category"] = d.category;
            j.push_back(item);
        }
        
        std::string jsonStr = j.dump();
        char* result = (char*)malloc(jsonStr.length() + 1);
        strcpy(result, jsonStr.c_str());
        return result;
    }
    
    char* database_search_domains_json(DomainDatabase* db, const char* pattern) {
        if (!db || !pattern) return _strdup("[]");
        return _strdup("[]");
    }
    
    bool database_update_hit_count(DomainDatabase* db, const char* domain) {
        return db ? db->updateDomainHitCount(domain) : false;
    }

    bool database_add_whitelisted(DomainDatabase* db, const char* domain) {
        return db && domain ? db->addWhitelistedDomain(domain) : false;
    }

    bool database_remove_whitelisted(DomainDatabase* db, const char* domain) {
        return db && domain ? db->removeWhitelistedDomain(domain) : false;
    }

    char* database_get_whitelisted_json(DomainDatabase* db) {
        if (!db) return _strdup("[]");
        auto domains = db->getWhitelistedDomains();
        json j = json::array();
        for (const auto& d : domains) j.push_back(d);
        std::string jsonStr = j.dump();
        char* result = (char*)malloc(jsonStr.length() + 1);
        strcpy(result, jsonStr.c_str());
        return result;
    }
    
    char* database_get_top_blocked_json(DomainDatabase* db, int limit) {
        if (!db) return _strdup("[]");
        
        auto domains = db->getTopBlockedDomains(limit);
        json j = json::array();
        
        for (const auto& d : domains) {
            json item;
            item["domain"] = d.domain;
            item["hit_count"] = d.hitCount;
            j.push_back(item);
        }
        
        std::string jsonStr = j.dump();
        char* result = (char*)malloc(jsonStr.length() + 1);
        strcpy(result, jsonStr.c_str());
        return result;
    }
    
    int database_get_domain_count(DomainDatabase* db) {
        return db ? db->getDomainCount() : 0;
    }
    
    bool database_add_source(DomainDatabase* db, const char* url, const char* name, int updateInterval) {
        return db ? db->addBlocklistSource(url, name, updateInterval) : false;
    }
    
    char* database_get_sources_json(DomainDatabase* db) {
        if (!db) return _strdup("[]");
        
        auto sources = db->getAllSources();
        json j = json::array();
        
        for (const auto& s : sources) {
            json item;
            item["id"] = s.id;
            item["url"] = s.url;
            item["name"] = s.name;
            item["last_update"] = s.lastUpdate;
            item["is_active"] = s.isActive;
            item["update_interval"] = s.updateInterval;
            j.push_back(item);
        }
        
        std::string jsonStr = j.dump();
        char* result = (char*)malloc(jsonStr.length() + 1);
        strcpy(result, jsonStr.c_str());
        return result;
    }
    
    bool database_add_batch(DomainDatabase* db, const char** domains, int count, const char* source) {
        if (!db) return false;
        
        std::vector<std::string> domainVec;
        for (int i = 0; i < count; i++) {
            if (domains[i]) domainVec.push_back(domains[i]);
        }
        
        return db->addDomainsBatch(domainVec, source ? source : "batch");
    }
    
    bool database_clear_source(DomainDatabase* db, const char* source) {
        return db ? db->deleteDomainsBySource(source) : false;
    }
    
    char* database_get_stats_json(DomainDatabase* db) {
        if (!db) return _strdup("{}");
        
        json stats;
        stats["total_domains"] = db->getDomainCount();
        stats["total_queries"] = db->getTotalQueries();
        stats["blocked_queries"] = db->getTotalBlockedQueries();
        
        auto categoryStats = db->getCategoryStats();
        json categories = json::object();
        for (const auto& [cat, count] : categoryStats) {
            categories[cat] = count;
        }
        stats["categories"] = categories;
        
        std::string jsonStr = stats.dump();
        char* result = (char*)malloc(jsonStr.length() + 1);
        strcpy(result, jsonStr.c_str());
        return result;
    }
    
    bool database_backup(DomainDatabase* db, const char* backupPath) {
        return db ? db->backup(backupPath) : false;
    }
    
    bool database_vacuum(DomainDatabase* db) {
        return db ? db->vacuum() : false;
    }
    
    void free_string(char* str) {
        if (str) free(str);
    }
}

// Additional implementations
std::vector<BlocklistSource> DomainDatabase::getAllSources() {
    std::lock_guard<std::mutex> lock(dbMutex);
    std::vector<BlocklistSource> sources;
    
    const char* sql = "SELECT id, url, name, last_update, is_active, update_interval FROM blocklist_sources WHERE is_active = 1;";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return sources;
    
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        BlocklistSource source;
        source.id = sqlite3_column_int(stmt, 0);
        source.url = (const char*)sqlite3_column_text(stmt, 1);
        source.name = (const char*)sqlite3_column_text(stmt, 2);
        const char* lastUpd = (const char*)sqlite3_column_text(stmt, 3);
        source.lastUpdate = lastUpd ? lastUpd : "";
        source.isActive = sqlite3_column_int(stmt, 4);
        source.updateInterval = sqlite3_column_int(stmt, 5);
        sources.push_back(source);
    }
    
    sqlite3_finalize(stmt);
    return sources;
}

bool DomainDatabase::deleteDomainsBySource(const std::string& source) {
    std::lock_guard<std::mutex> lock(dbMutex);
    
    const char* sql = "DELETE FROM domains WHERE source = ?;";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return false;
    
    sqlite3_bind_text(stmt, 1, source.c_str(), -1, SQLITE_STATIC);
    
    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    
    return rc == SQLITE_DONE;
}

bool DomainDatabase::backup(const std::string& backupPath) {
    sqlite3* backupDb;
    int rc = sqlite3_open(backupPath.c_str(), &backupDb);
    if (rc != SQLITE_OK) return false;
    
    sqlite3_backup* backup = sqlite3_backup_init(backupDb, "main", db, "main");
    if (backup) {
        sqlite3_backup_step(backup, -1);
        sqlite3_backup_finish(backup);
    }
    
    sqlite3_close(backupDb);
    return true;
}

int DomainDatabase::getTotalQueries() {
    std::lock_guard<std::mutex> lock(dbMutex);
    
    const char* sql = "SELECT SUM(total_queries) FROM statistics;";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return 0;
    
    rc = sqlite3_step(stmt);
    int total = (rc == SQLITE_ROW) ? sqlite3_column_int(stmt, 0) : 0;
    
    sqlite3_finalize(stmt);
    return total;
}

int DomainDatabase::getTotalBlockedQueries() {
    std::lock_guard<std::mutex> lock(dbMutex);
    
    const char* sql = "SELECT SUM(blocked_queries) FROM statistics;";
    sqlite3_stmt* stmt;
    
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return 0;
    
    rc = sqlite3_step(stmt);
    int total = (rc == SQLITE_ROW) ? sqlite3_column_int(stmt, 0) : 0;
    
    sqlite3_finalize(stmt);
    return total;
}

bool DomainDatabase::updateBlocklistSource(const std::string& url, const std::string& lastUpdate) {
    std::lock_guard<std::mutex> lock(dbMutex);
    const char* sql = "UPDATE blocklist_sources SET last_update = datetime('now') WHERE url = ?;";
    sqlite3_stmt* stmt;
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) return false;
    sqlite3_bind_text(stmt, 1, url.c_str(), -1, SQLITE_STATIC);
    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    return rc == SQLITE_DONE;
}

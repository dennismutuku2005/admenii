-- AdMenii Database Schema

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

CREATE TABLE IF NOT EXISTS blocklist_sources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    url TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    last_update DATETIME,
    update_interval INTEGER DEFAULT 48,
    is_active INTEGER DEFAULT 1,
    last_status INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS query_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain TEXT NOT NULL,
    query_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    was_blocked INTEGER DEFAULT 0,
    client_ip TEXT
);

CREATE TABLE IF NOT EXISTS statistics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    stat_date DATE DEFAULT CURRENT_DATE,
    total_queries INTEGER DEFAULT 0,
    blocked_queries INTEGER DEFAULT 0,
    UNIQUE(stat_date)
);

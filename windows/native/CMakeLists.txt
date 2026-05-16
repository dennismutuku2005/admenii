cmake_minimum_required(VERSION 3.15)
project(adblocker)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find packages
find_package(CURL REQUIRED)
# SQLite3 is often not found easily on Windows via find_package if not in path
# We'll assume the user provides the paths or it's in the standard location
find_package(SQLite3 REQUIRED)
find_package(Threads REQUIRED)

# Include directories
include_directories(${CURL_INCLUDE_DIRS})
include_directories(${SQLite3_INCLUDE_DIRS})

# Source files
set(SOURCES
    ad_blocker.cpp
    database.cpp
)

set(HEADERS
    ad_blocker.h
    database.h
)

# Windows specific
if(WIN32)
    add_definitions(-DWIN32_LEAN_AND_MEAN)
endif()

# Shared library for Flutter FFI
add_library(adblocker SHARED ${SOURCES} ${HEADERS})
target_link_libraries(adblocker ${CURL_LIBRARIES} ${SQLite3_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT} ws2_32)

# Standalone Service/Backend executable
add_executable(admenii_backend main.cpp ${SOURCES} ${HEADERS})
target_link_libraries(admenii_backend ${CURL_LIBRARIES} ${SQLite3_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT} ws2_32)

# Install rules
install(TARGETS adblocker admenii_backend
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)

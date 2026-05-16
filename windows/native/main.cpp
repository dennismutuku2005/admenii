#include "ad_blocker.h"
#include <windows.h>
#include <iostream>

SERVICE_STATUS        g_ServiceStatus = {0};
SERVICE_STATUS_HANDLE g_StatusHandle = NULL;
HANDLE                g_ServiceStopEvent = INVALID_HANDLE_VALUE;
AdBlocker*            g_Blocker = nullptr;

VOID WINAPI ServiceMain(DWORD argc, LPTSTR* argv);
VOID WINAPI ServiceCtrlHandler(DWORD);

int main(int argc, char* argv[]) {
    if (argc > 1 && std::string(argv[1]) == "--service") {
        SERVICE_TABLE_ENTRY ServiceTable[] = {
            {(LPTSTR)TEXT("AdMeniiDNS"), (LPSERVICE_MAIN_FUNCTION)ServiceMain},
            {NULL, NULL}
        };

        if (StartServiceCtrlDispatcher(ServiceTable) == FALSE) {
            return GetLastError();
        }
    } else {
        std::cout << "AdMenii DNS Backend Service" << std::endl;
        std::cout << "Usage: admenii_backend.exe --service" << std::endl;
        std::cout << "Note: This service is usually managed by the AdMenii UI app." << std::endl;
        
        AdBlocker blocker;
        blocker.start(53);
        std::cout << "DNS Server started on port 53. Press Enter to exit..." << std::endl;
        std::cin.get();
        blocker.stop();
    }
    return 0;
}

VOID WINAPI ServiceMain(DWORD argc, LPTSTR* argv) {
    g_StatusHandle = RegisterServiceCtrlHandler(TEXT("AdMeniiDNS"), ServiceCtrlHandler);

    if (g_StatusHandle == NULL) return;

    g_ServiceStatus.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
    g_ServiceStatus.dwCurrentState = SERVICE_START_PENDING;
    SetServiceStatus(g_StatusHandle, &g_ServiceStatus);

    g_ServiceStopEvent = CreateEvent(NULL, TRUE, FALSE, NULL);
    
    g_Blocker = new AdBlocker();
    // In a real standalone service, we'd load domains from a file here.
    // For now, it waits for the UI to populate it or stays as a skeleton.
    g_Blocker->start(53);

    g_ServiceStatus.dwCurrentState = SERVICE_RUNNING;
    SetServiceStatus(g_StatusHandle, &g_ServiceStatus);

    WaitForSingleObject(g_ServiceStopEvent, INFINITE);

    g_ServiceStatus.dwCurrentState = SERVICE_STOPPED;
    SetServiceStatus(g_StatusHandle, &g_ServiceStatus);
}

VOID WINAPI ServiceCtrlHandler(DWORD CtrlCode) {
    switch (CtrlCode) {
        case SERVICE_CONTROL_STOP:
            if (g_Blocker) g_Blocker->stop();
            SetEvent(g_ServiceStopEvent);
            break;
        default:
            break;
    }
}

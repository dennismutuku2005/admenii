#include "ad_blocker.h"
#include <windows.h>
#include <iostream>
#include <string>

SERVICE_STATUS        g_ServiceStatus = {0};
SERVICE_STATUS_HANDLE g_StatusHandle = NULL;
HANDLE                g_ServiceStopEvent = INVALID_HANDLE_VALUE;
AdBlocker*            g_Blocker = nullptr;

VOID WINAPI ServiceMain(DWORD argc, LPTSTR* argv);
VOID WINAPI ServiceCtrlHandler(DWORD);

int main(int argc, char* argv[]) {
    if (argc > 1 && std::string(argv[1]) == "--service") {
        SERVICE_TABLE_ENTRY ServiceTable[] = {
            {(LPSTR)"AdMeniiDNS", (LPSERVICE_MAIN_FUNCTION)ServiceMain},
            {NULL, NULL}
        };

        if (StartServiceCtrlDispatcher(ServiceTable) == FALSE) {
            return GetLastError();
        }
    } else {
        // Run as console app for testing
        AdBlocker blocker("admenii.db");
        blocker.start(53);
        std::cout << "AdMenii DNS Server started on port 53. Press Enter to stop..." << std::endl;
        std::cin.get();
        blocker.stop();
    }
    return 0;
}

VOID WINAPI ServiceMain(DWORD argc, LPTSTR* argv) {
    g_StatusHandle = RegisterServiceCtrlHandler("AdMeniiDNS", ServiceCtrlHandler);

    if (g_StatusHandle == NULL) return;

    g_ServiceStatus.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
    g_ServiceStatus.dwServiceSpecificExitCode = 0;

    g_ServiceStatus.dwCurrentState = SERVICE_START_PENDING;
    SetServiceStatus(g_StatusHandle, &g_ServiceStatus);

    g_ServiceStopEvent = CreateEvent(NULL, TRUE, FALSE, NULL);
    if (g_ServiceStopEvent == NULL) {
        g_ServiceStatus.dwCurrentState = SERVICE_STOPPED;
        SetServiceStatus(g_StatusHandle, &g_ServiceStatus);
        return;
    }

    // Start the blocker
    g_Blocker = new AdBlocker("C:\\ProgramData\\AdMenii\\admenii.db");
    if (!g_Blocker->start(53)) {
        g_ServiceStatus.dwCurrentState = SERVICE_STOPPED;
        SetServiceStatus(g_StatusHandle, &g_ServiceStatus);
        return;
    }

    g_ServiceStatus.dwCurrentState = SERVICE_RUNNING;
    SetServiceStatus(g_StatusHandle, &g_ServiceStatus);

    WaitForSingleObject(g_ServiceStopEvent, INFINITE);

    g_ServiceStatus.dwCurrentState = SERVICE_STOPPED;
    SetServiceStatus(g_StatusHandle, &g_ServiceStatus);
}

VOID WINAPI ServiceCtrlHandler(DWORD CtrlCode) {
    switch (CtrlCode) {
        case SERVICE_CONTROL_STOP:
            if (g_ServiceStatus.dwCurrentState == SERVICE_RUNNING) {
                if (g_Blocker) g_Blocker->stop();
                SetEvent(g_ServiceStopEvent);
            }
            break;
        default:
            break;
    }
}

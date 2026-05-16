# AdMenii

<p align="center">
  <img src="assets/images/logo.png" width="400" alt="AdMenii Logo">
</p>

Advanced DNS-based ad blocker for Windows. Powered by C++ and SQLite with a clean Flutter UI.

## Features
- Background DNS filtering service
- Persistent SQLite storage
- Custom whitelist and blocklist management
- Real-time activity statistics
- Professional brand color palette

## Installation

Run the following command in an Administrator PowerShell window to install the AdMenii service:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/dennismutuku2005/admenii/main/installer/install-admenii.ps1'))
```

## Build Instructions
1. Navigate to the `native` directory and build the C++ components using CMake.
2. Ensure `adblocker.dll` and `admenii_backend.exe` are placed in the application directory.
3. Run `flutter build windows` to generate the UI executable.

## Repository
https://github.com/dennismutuku2005/admenii.git
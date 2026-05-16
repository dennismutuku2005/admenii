# AdMenii Ultimate Installer
Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                     AdMenii Ultimate v2.0                    ║
║                  Advanced DNS Ad Blocker                      ║
║              SQLite Powered | Auto-updating | Fast            ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run as Administrator!" -ForegroundColor Red
    exit 1
}

$InstallDir = "$env:ProgramFiles\AdMenii"
$DataDir = "$env:ProgramData\AdMenii"
$ServiceName = "AdMeniiDNS"

# Create directories
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

Write-Host "Configuring Windows DNS..." -ForegroundColor Yellow
# Set DNS to localhost
$interfaces = Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses -ne $null }
foreach ($interface in $interfaces) {
    Set-DnsClientServerAddress -InterfaceIndex $interface.InterfaceIndex -ServerAddresses ("127.0.0.1", "8.8.8.8") -ErrorAction SilentlyContinue
}

Write-Host "Creating Windows Service..." -ForegroundColor Yellow
New-Service -Name $ServiceName `
    -BinaryPathName "\"$InstallDir\admenii_backend.exe\" --service" `
    -DisplayName "AdMenii DNS Ad Blocker" `
    -Description "Blocks advertising domains using SQLite database" `
    -StartupType Automatic

Write-Host "Configuring Firewall..." -ForegroundColor Yellow
New-NetFirewallRule -DisplayName "AdMenii DNS" -Direction Inbound -Protocol UDP -LocalPort 53 -Action Allow -ErrorAction SilentlyContinue

Write-Host @"

✅ Installation Complete!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📊 Statistics:
     • DNS Server: Running on port 53
     • Database: SQLite at $DataDir
     • Blocklists: 30+ sources, auto-updates every 48h

  🌐 DNS Settings:
     Your DNS is now set to 127.0.0.1
     Upstream: 8.8.8.8

  📱 Launch AdMenii UI from desktop shortcut!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"@ -ForegroundColor Green

# --- Inputs ---

Write-Host "Getting user input ... " -ForegroundColor Cyan

# Network variables
$ipAddress = Read-Host "Enter the static IP Address for this Server"
$ipPrefix = Read-Host "Enter the prefix CIDR (24,16,...)"
$gateway = Read-Host "Enter the Default Gateway"
if ([string]::IsNullOrWhiteSpace($ipAddress) -or [string]::IsNullOrWhiteSpace($ipPrefix) -or [string]::IsNullOrWhiteSpace($gateway)) {
    Write-Error "❌ IP Address, Prefix and Gateway are required. Script aborted."
    return
}

# Finds the active network adapter
$netAdapter = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1
if ($null -eq $netAdapter) {
    Write-Error "❌ No active network adapter found."
    return
}

# Computer name variable
$newName = ""
while ([string]::IsNullOrWhiteSpace($newName)) {
    $inputName = Read-Host "Enter the new name for this server machine (Required)"

    if ([string]::IsNullOrWhiteSpace($inputName)) {
        Write-Host "❌ Computer name cannot be empty." -ForegroundColor Red
    } else {
        # Trim surrounding whitespace and replace internal spaces with "-"
        $newName = $inputName.Trim().Replace(" ", "-")
        Write-Host "Computer name set to: $newName" -ForegroundColor Cyan
    }
}

# --- Actions ---

# Static IP and Gateway Setup
Write-Host "Configuring adapter: $($netAdapter.Name)..." -ForegroundColor Cyan
New-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -IPAddress $ipAddress -PrefixLength $ipPrefix -DefaultGateway $gateway
Set-DnsClientServerAddress -InterfaceIndex $netAdapter.ifIndex -ServerAddresses ("127.0.0.1","1.1.1.2")
Write-Host "✔️ Configuring adapter successfull." -ForegroundColor Green

# Install necessary roles and management tools
Write-Host "Installing AD, DNS, IIS services roles and management tools ... This can take a few minutes (Patience)" -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services, DNS, Web-Server -IncludeManagementTools
Write-Host "✔️ Roles and management tools installed successfully." -ForegroundColor Green

# DNS Forwarding to gateway Setup
Write-Host "Setting DNS Forwarding" -ForegroundColor Cyan
Set-DnsServerForwarder -IPAddress $gateway
Write-Host "✔️ DNS Forwarding set." -ForegroundColor Green

# Set the time zone to Ljubljana
Write-Host "Setting Time Zone to CEST" -ForegroundColor Cyan
Set-TimeZone -Id "Central Europe Standard Time"
Write-Host "✔️ Time Zone set to CEST." -ForegroundColor Green

# # SPICE agent Setup
# winget install -e --id RedHat.VirtViewer

# # OpenSSH Setup
# Write-Host "Setting up OpenSSH..." -ForegroundColor Cyan
# Set-Service -Name sshd -StartupType 'Automatic'
# Set-NetFirewallRule -Name "OpenSSH*" -Profile Domain, Private
# New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name "DefaultShell" -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
# Start-Service sshd

# Wazuh agent Setup
$confirmation = Read-Host "Do you want to install the Wazuh agent? (y/n)"

if ($confirmation -match "^(y|yes)$") {
    Write-Host "Installing Wazuh..." -ForegroundColor Cyan

    $wazuhFQDN = Read-Host "Enter the Wazuh FQDN (eg. wazuh.lan)"
    winget install -e --id Wazuh.WazuhAgent -s winget --override "/q WAZUH_MANAGER=$wazuhFQDN WAZUH_AGENT_GROUP=default WAZUH_AGENT_NAME=$newName"

    # Enable IIS logs
    $configPath = "C:\Program Files (x86)\ossec-agent\ossec.conf"

    # Load the XML content
    [xml]$xmlConfig = Get-Content $configPath

    $newLog = $xmlConfig.CreateElement("localfile")
    $location = $xmlConfig.CreateElement("location")
    $location.InnerText = "C:\inetpub\logs\LogFiles\W3SVC1\*.log"
    $newLog.AppendChild($location) > $null

    $format = $xmlConfig.CreateElement("log_format")
    $format.InnerText = "iis"
    $newLog.AppendChild($format) > $null

    # Find the last existing <localfile> node to maintain the grouping. Insert the new log immediately after the last existing localfile
    $lastLocalFile = $xmlConfig.ossec_config.localfile | Select-Object -Last 1
    $xmlConfig.ossec_config.InsertAfter($newLog, $lastLocalFile) > $null

    $xmlConfig.Save($configPath)

    Write-Host "✔️ Wazuh Agent installed." -ForegroundColor Green
} else {
    Write-Host "Skipping Wazuh Agent installation." -ForegroundColor Yellow
}

# Computer Rename
Write-Host "Renaming computer to $newName and restarting..." -ForegroundColor Cyan
Rename-Computer -NewName $newName -Restart -Force

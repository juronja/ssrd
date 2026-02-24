# --- Inputs ---

Write-Host "Getting user input ... " -ForegroundColor Cyan

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

# AD Domain Input
$domainName = ""
while ([string]::IsNullOrWhiteSpace($domainName)) {
    $inputDomain = Read-Host "Enter the AD domain to join (e.g., ad.lan)"
    if ([string]::IsNullOrWhiteSpace($inputDomain)) {
        Write-Host "❌ Domain cannot be empty." -ForegroundColor Red
    } else {
        $domainName = $inputDomain.Trim()
        Write-Host "AD domain set to: $domainName" -ForegroundColor Cyan
    }
}

# --- Actions ---

# Join AD, Computer Rename
Write-Host "Renaming computer to $newName and joining $domainName..." -ForegroundColor Cyan
Add-Computer -DomainName $domainName -NewName $newName -Credential (Get-Credential) -Force
Write-Host "✔️ Domain join and rename done." -ForegroundColor Green

# Wazuh agent Setup
$confirmation = Read-Host "Do you want to install the Wazuh agent? (y/n)"

if ($confirmation -match "^(y|yes)$") {
    Write-Host "Installing Wazuh..." -ForegroundColor Cyan

    $wazuhFQDN = Read-Host "Enter the Wazuh FQDN (eg. wazuh.lan)"
    winget install -e --id Wazuh.WazuhAgent -s winget --override "/q WAZUH_MANAGER=$wazuhFQDN WAZUH_AGENT_GROUP=default WAZUH_AGENT_NAME=$newName"

    Write-Host "✔️ Wazuh Agent installed." -ForegroundColor Green
} else {
    Write-Host "Skipping Wazuh Agent installation." -ForegroundColor Yellow
}

Write-Host "✔️ Script finished, restarting..." -ForegroundColor Green
Start-Sleep -Seconds 3

Restart-Computer -Force

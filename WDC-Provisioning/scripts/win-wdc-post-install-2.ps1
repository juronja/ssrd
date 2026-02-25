# Promote the server as Domain Controller (New Forest)

# Compare password function
# Safely compares two SecureString objects without decrypting them.
function Compare-SecureString {
  param(
    [Security.SecureString]$secureString1,
    [Security.SecureString]$secureString2
  )
  $bstr1 = $bstr2 = [IntPtr]::Zero
  try {
    $bstr1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString1)
    $bstr2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString2)
    $length1 = [Runtime.InteropServices.Marshal]::ReadInt32($bstr1,-4)
    $length2 = [Runtime.InteropServices.Marshal]::ReadInt32($bstr2,-4)
    if ( $length1 -eq 0 -or $length1 -ne $length2 ) {
      return $false
    }
    for ( $i = 0; $i -lt $length1; ++$i ) {
      $b1 = [Runtime.InteropServices.Marshal]::ReadByte($bstr1,$i)
      $b2 = [Runtime.InteropServices.Marshal]::ReadByte($bstr2,$i)
      if ( $b1 -ne $b2 ) {
        return $false
      }
    }
    return $true
  }
  finally {
    if ( $bstr1 -ne [IntPtr]::Zero ) {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)
    }
    if ( $bstr2 -ne [IntPtr]::Zero ) {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)
    }
  }
}

# Domain Information Gathering
$domainName = Read-Host "Enter the Root Domain Name (e.g., ad.lan)"
if ([string]::IsNullOrWhiteSpace($domainName)) {
    Write-Host "❌ Domain Name cannot be empty." -ForegroundColor Red
    return
}

# Suggest NetBIOS (everything before the first dot, uppercased)
$suggestedNetBios = $domainName.Split('.')[0].ToUpper()
$domainNetbiosName = Read-Host "Enter the NetBIOS Name (Press Enter for '$suggestedNetBios')"
if ([string]::IsNullOrWhiteSpace($domainNetbiosName)) {
    $domainNetbiosName = $suggestedNetBios
}

# Get Password
$dsrmPassword = $null
$passMatch = $false

do {
    $pass = Read-Host "Enter DSRM Password" -AsSecureString
    $passConfirm = Read-Host "Confirm DSRM Password" -AsSecureString

    if ( Compare-SecureString $pass $passConfirm ) {
      $dsrmPassword = $pass
      $passMatch = $true
      Write-Host "✔️ Passwords match!" -ForegroundColor Green
    } else {
        Write-Host "❌ Passwords are empty or do not match. Please try again." -ForegroundColor Red
    }
} until ($passMatch)

Write-Host "Promoting server to Domain Controller..." -ForegroundColor Cyan
Write-Host "System will REBOOT automatically upon completion." -ForegroundColor Cyan

Install-ADDSForest `
    -DomainName $domainName `
    -DomainNetbiosName $domainNetbiosName `
    -InstallDns:$true `
    -SafeModeAdministratorPassword $dsrmPassword `
    -NoRebootOnCompletion:$false `
    -Force:$true

Write-Host "Promoting server successfull. System is rebooting ..." -ForegroundColor Green

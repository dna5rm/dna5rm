<#
.SYNOPSIS
Retrieves or sets an encrypted secret stored in a PowerShell Data File (.psd1).

.DESCRIPTION
The Get-EncryptedSecret function manages encrypted secrets stored in a .psd1 file.
It can retrieve existing secrets or prompt for new ones if they don't exist or can't be decrypted.
The function uses a consistent encryption key based on the current user and computer name.

.PARAMETER FilePath
The path to the .psd1 file where secrets are stored. If not specified, it defaults to "(Split-Path -Parent $PROFILE) + '/secrets.psd1'".

.PARAMETER SecretName
The name of the secret to retrieve or set.

.EXAMPLE
Get-EncryptedSecret -SecretName "MyAPIKey"
Retrieves the secret named "MyAPIKey" or prompts to set it if it doesn't exist.

.EXAMPLE
Get-EncryptedSecret -FilePath "C:\MySecrets.psd1" -SecretName "DatabasePassword"
Retrieves or sets the "DatabasePassword" secret in the specified file.

.NOTES
- Secrets are encrypted using AES-256-CBC with a key derived from the username and computer name.
- The function returns the secret as a plaintext string, so use caution when displaying or storing the result.
- If a secret can't be decrypted (e.g., if it was created on a different computer), you'll be prompted to enter a new value.

.SECURITY NOTE
While the secrets are stored in an encrypted form, they are returned as plaintext.
Be cautious about how and where you use the returned values to avoid exposing sensitive information.
#>

function Get-HostKey {
    $keyString = "$env:USERNAME@$env:COMPUTERNAME"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $keyBytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($keyString))
    return $keyBytes
}

function Get-EncryptedSecret {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$FilePath,

        [Parameter(Position=1, Mandatory=$true)]
        [string]$SecretName
    )

    # Generate the key
    $key = Get-HostKey

    # Set default FilePath if not provided
    if (-not $FilePath) {
        $FilePath = Join-Path (Split-Path -Parent $PROFILE) 'secrets.psd1'
    }

    # Initialize or load existing secrets
    if (Test-Path $FilePath) {
        $secrets = Import-PowerShellDataFile -Path $FilePath
    } else {
        $secrets = @{}
    }

    # Check if the secret exists and try to decrypt it
    if ($secrets.ContainsKey($SecretName)) {
        $encryptedString = $secrets[$SecretName]
        try {
            $decryptedSecureString = ConvertTo-SecureString $encryptedString -Key $key
            return [System.Net.NetworkCredential]::new('', $decryptedSecureString).Password
        }
        catch {
            Write-Warning "Failed to decrypt the existing secret."
        }
    }

    # If we reach here, either the secret doesn't exist or decryption failed
    $newSecretValue = Read-Host -Prompt "Enter the secret value for $SecretName" -AsSecureString
    $encryptedString = ConvertFrom-SecureString $newSecretValue -Key $key

    # Update the secrets hashtable and save to file
    $secrets[$SecretName] = $encryptedString
    $psd1Content = "@{`n"
    foreach ($k in $secrets.Keys) {
        $value = $secrets[$k]
        $psd1Content += "    '$k' = '$value'`n"
    }
    $psd1Content += "}"

    try {
        $psd1Content | Out-File -FilePath $FilePath -Encoding utf8 -Force
        Write-Host "Secret '$SecretName' has been saved successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to save the secrets file: $_"
    }

    # Convert SecureString to plaintext before returning
    return [System.Net.NetworkCredential]::new('', $newSecretValue).Password
}

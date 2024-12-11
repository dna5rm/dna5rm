<#
.SYNOPSIS
Encrypts or decrypts files using OpenSSL.

.DESCRIPTION
The Invoke-Crypt function encrypts or decrypts files using OpenSSL's AES-256-CBC encryption.
It requires OpenSSL to be installed and available in the system path or as an alias.
If the Invoke-Run function is available, it will be used to execute OpenSSL commands.

.PARAMETER PassPhrase
The passphrase to use for encryption/decryption. If not provided, it defaults to a base64 encoded string of "username@hostname".

.PARAMETER Files
One or more files to encrypt or decrypt. Files ending with .enc will be decrypted, others will be encrypted.

.EXAMPLE
Invoke-Crypt -Files "secret.txt"
Encrypts the file "secret.txt" to "secret.txt.enc"

.EXAMPLE
Invoke-Crypt -PassPhrase "mySecret" -Files "secret.txt.enc"
Decrypts the file "secret.txt.enc" to "secret.txt" using the passphrase "mySecret"

.NOTES
This function is inspired by a similar Bash function. It requires OpenSSL to be installed.
Unlike the Bash version, it does not use 'shred' for secure deletion as it's not typically available on Windows.
#>

function Invoke-Crypt {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$PassPhrase,

        [Parameter(Position = 1, Mandatory = $true, ValueFromRemainingArguments = $true)]
        [string[]]$Files
    )

    # Set default passphrase if not provided
    if (-not $PassPhrase) {
        $PassPhrase = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$env:USERNAME@$env:COMPUTERNAME"))
    }

    # Function to execute OpenSSL command
    function Execute-OpenSSL {
        param([string]$Command)
        if (Get-Command Invoke-Run -ErrorAction SilentlyContinue) {
            Invoke-Run -Commands $Command
        } else {
            Invoke-Expression $Command
        }
    }

    foreach ($file in $Files) {
        if (Test-Path $file -PathType Leaf) {
            $isEncrypted = $file.EndsWith('.enc')
            $outputFile = if ($isEncrypted) { $file.Substring(0, $file.Length - 4) } else { "$file.enc" }
            $action = if ($isEncrypted) { "decrypt" } else { "encrypt" }

            try {
                $opensslCommand = if ($isEncrypted) {
                    "openssl enc -aes-256-cbc -d -md sha512 -pbkdf2 -iter 100000 -salt -in `"$file`" -k `"$PassPhrase`" -out `"$outputFile`""
                } else {
                    "openssl enc -aes-256-cbc -e -md sha512 -pbkdf2 -iter 100000 -salt -in `"$file`" -k `"$PassPhrase`" -out `"$outputFile`""
                }

                Execute-OpenSSL $opensslCommand

                if ($?) {
                    Remove-Item $file -Force
                    Write-Host "[Invoke-Crypt:$($file | Split-Path -Leaf)] Successfully $($action)ed!" -ForegroundColor Green
                } else {
                    throw "OpenSSL operation failed"
                }
            } catch {
                Write-Error "Failed to $($action) file '$file': $($_.Exception.Message)"
                if (Test-Path $outputFile) { Remove-Item $outputFile -Force }
                continue
            }
        } else {
            Write-Error "[Invoke-Crypt:$($file | Split-Path -Leaf)] Input is not a valid file!"
            continue
        }
    }
}

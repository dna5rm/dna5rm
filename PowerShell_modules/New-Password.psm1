<#
.SYNOPSIS
Generates a random password string.

.DESCRIPTION
The New-Password function creates a random password string using a combination of 
uppercase and lowercase letters, numbers, and special characters. Additional options
allow customization of the character set and inclusion of specific character types.

.PARAMETER Length
The length of the password to generate. If not specified, defaults to 16 characters.

.PARAMETER ExcludeCharacters
A string of characters to exclude from the password.

.PARAMETER IncludeSymbols
If specified, includes special characters in the password. Defaults to true.

.PARAMETER IncludeNumbers
If specified, includes numeric characters in the password. Defaults to true.

.PARAMETER IncludeUppercase
If specified, includes uppercase letters in the password. Defaults to true.

.PARAMETER IncludeLowercase
If specified, includes lowercase letters in the password. Defaults to true.

.EXAMPLE
New-Password
Generates a random 16-character password.

.EXAMPLE
New-Password -Length 20 -ExcludeCharacters "O0l1"
Generates a random 20-character password excluding characters 'O', '0', 'l', and '1'.

.EXAMPLE
New-Password -Length 12 -IncludeSymbols:$false
Generates a random 12-character password without special characters.

.NOTES
This function is inspired by a similar Bash function and is designed to provide
a quick way to generate secure random passwords in PowerShell.
#>

function New-Password {
    param (
        [Parameter(Position=0)]
        [int]$Length = 16,

        [string]$ExcludeCharacters = "",

        [switch]$IncludeSymbols = $true,

        [switch]$IncludeNumbers = $true,

        [switch]$IncludeUppercase = $true,

        [switch]$IncludeLowercase = $true
    )

    $CharSet = ""

    if ($IncludeLowercase) { $CharSet += 'abcdefghijklmnopqrstuvwxyz' }
    if ($IncludeUppercase) { $CharSet += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' }
    if ($IncludeNumbers)   { $CharSet += '0123456789' }
    if ($IncludeSymbols)   { $CharSet += '!@#$%^&*()' }

    if ([string]::IsNullOrEmpty($CharSet)) {
        Write-Error "No character sets selected for password generation."
        return
    }

    # Remove excluded characters
    if (-not [string]::IsNullOrEmpty($ExcludeCharacters)) {
        $CharSet = ($CharSet -split '').Where({ $ExcludeCharacters -notlike "*$_*" }) -join ''
    }

    if ([string]::IsNullOrEmpty($CharSet)) {
        Write-Error "Character set is empty after applying exclusions."
        return
    }

    $Password = -join ((1..$Length) | ForEach-Object { $CharSet[(Get-Random -Maximum $CharSet.Length)] })

    return $Password
}

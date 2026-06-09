param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$distDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$instDir = "${env:ProgramFiles(x86)}\ViaVoice"

function IsAdmin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object System.Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (IsAdmin)) {
    Write-Host "Restarting as Administrator..."
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $($MyInvocation.BoundParameters.Keys)"
    exit
}

if ($Uninstall) {
    Write-Host "=== Uninstalling ViaVoice ==="

    # Unregister DLL
    $dll = "$instDir\bin\ttseng_dyn.dll"
    if (Test-Path $dll) {
        & "$env:SystemRoot\SysWOW64\regsvr32.exe" /s /u "$dll"
        Write-Host "DLL unregistered"
    }

    # Remove voice tokens from both hives
    $paths = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Speech\Voices\Tokens",
        "HKLM:\SOFTWARE\Microsoft\Speech\Voices\Tokens"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) {
            Get-ChildItem $p | Where-Object { $_.PSChildName -like "VE_Voice*" } | Remove-Item -Recurse -Force
        }
    }
    Write-Host "Voice tokens removed"

    # Remove user profile data
    $userKey = "HKCU:\Software\ViaVoice"
    if (Test-Path $userKey) { Remove-Item -Recurse -Force $userKey }

    # Remove Start Menu shortcut
    $shortcut = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\ViaVoice Manager.lnk"
    if (Test-Path $shortcut) { Remove-Item -Force $shortcut }

    # Remove uninstall entry
    $uninstKey = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\ViaVoice"
    if (Test-Path $uninstKey) { Remove-Item -Recurse -Force $uninstKey }

    # Remove installed files
    if (Test-Path $instDir) { Remove-Item -Recurse -Force $instDir }

    Write-Host "Uninstall complete."
    exit
}

Write-Host "=== Installing ViaVoice ==="

# Stop any running PowerShell that holds DLL locks
Get-Process | Where-Object { $_.ProcessName -match 'powershell|python' -and $_.Id -ne $pid } | Stop-Process -Force -ErrorAction SilentlyContinue

# Create directories
New-Item -ItemType Directory -Force -Path "$instDir\bin", "$instDir\VoiceManager" | Out-Null

# Copy files
Copy-Item -Force "$distDir\bin\ttseng_dyn.dll" "$instDir\bin\"
Copy-Item -Force "$distDir\bin\IBMECI.dll" "$instDir\bin\"
Copy-Item -Force "$distDir\VoiceManager\voice_manager.py" "$instDir\VoiceManager\"

# Register DLL
& "$env:SystemRoot\SysWOW64\regsvr32.exe" /s "$instDir\bin\ttseng_dyn.dll"
Write-Host "DLL registered"

# Create voice tokens (both 32-bit and 64-bit hives)
$paths = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Speech\Voices\Tokens",
    "HKLM:\SOFTWARE\Microsoft\Speech\Voices\Tokens"
)

$voices = @(
    @{Name="Wade";     Gender="Male";   Age="Adult"},
    @{Name="Shelly";   Gender="Female"; Age="Adult"},
    @{Name="Bobbie";   Gender="Male";   Age="Adult"},
    @{Name="Roko";     Gender="Male";   Age="Adult"},
    @{Name="Glenn";    Gender="Male";   Age="Adult"},
    @{Name="Female2";  Gender="Female"; Age="Adult"},
    @{Name="Grandma";  Gender="Female"; Age="Adult"},
    @{Name="Grandpa";  Gender="Male";   Age="Adult"},
    @{Name="Smooth";   Gender="Male";   Age="Adult"},
    @{Name="Deep";     Gender="Male";   Age="Adult"},
    @{Name="Mix";      Gender="Male";   Age="Adult"},
    @{Name="Resonant"; Gender="Male";   Age="Adult"},
    @{Name="Cheerful"; Gender="Female"; Age="Adult"},
    @{Name="Warm";     Gender="Male";   Age="Adult"},
    @{Name="Marble";   Gender="Male";   Age="Adult"},
    @{Name="Echo";     Gender="Male";   Age="Adult"},
    @{Name="Bold";     Gender="Male";   Age="Adult"},
    @{Name="Crystal";  Gender="Female"; Age="Adult"},
    @{Name="Mellow";   Gender="Female"; Age="Adult"},
    @{Name="Vibrant";  Gender="Male";   Age="Adult"}
)

$clsid = "{301EDFC4-D65B-4823-A598-450EE4656837}"
$count = 0

foreach ($v in $voices) {
    $num = [array]::IndexOf($voices, $v) + 1
    foreach ($rate in @("22kHz", "8kHz")) {
        $rateVal = if ($rate -eq "22kHz") { 0 } else { 1 }
        $tokenName = "VE_Voice${num}_$($v.Name)_${rate}"

        foreach ($path in $paths) {
            $fullPath = "$path\$tokenName"
            New-Item -Path "$fullPath" -Force | Out-Null
            Set-ItemProperty -Path "$fullPath" -Name "(Default)" -Value "ViaVoice Voice $num - $($v.Name)"
            Set-ItemProperty -Path "$fullPath" -Name "CLSID" -Value $clsid
            Set-ItemProperty -Path "$fullPath" -Name "Language" -Type DWord -Value 1
            Set-ItemProperty -Path "$fullPath" -Name "Voice" -Type DWord -Value $num
            Set-ItemProperty -Path "$fullPath" -Name "SampleRate" -Type DWord -Value $rateVal

            $attrPath = "$fullPath\Attributes"
            New-Item -Path "$attrPath" -Force | Out-Null
            Set-ItemProperty -Path "$attrPath" -Name "Name" -Value $v.Name
            Set-ItemProperty -Path "$attrPath" -Name "Gender" -Value $v.Gender
            Set-ItemProperty -Path "$attrPath" -Name "Age" -Value $v.Age
            Set-ItemProperty -Path "$attrPath" -Name "Language" -Value "409;9"
        }
        $count++
    }
}

Write-Host "$count voice tokens created"

# Start Menu shortcut
$WshShell = New-Object -ComObject WScript.Shell
$shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\ViaVoice Manager.lnk")
$shortcut.TargetPath = "pythonw.exe"
$shortcut.Arguments = "`"$instDir\VoiceManager\voice_manager.py`""
$shortcut.WorkingDirectory = "$instDir\VoiceManager"
$shortcut.Description = "Configure ViaVoice voice profiles"
$shortcut.Save()
Write-Host "Start Menu shortcut created"

# Save default voice profiles to HKCU
& "$env:SystemRoot\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" -Command "
`$root = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\ViaVoice\Voices')
for (`$i = 0; `$i -lt 20; `$i++) {
    `$key = `$root.CreateSubKey('Voice' + (`$i + 1))
    `$key.SetValue('Name', '$($voices[$i].Name)')
    `$key.SetValue('Enabled', 1)
    `$key.SetValue('BaseVoice', `$i + 1)
    `$key.SetValue('PitchBaseline', 60)
    `$key.SetValue('PitchFluctuation', 50)
    `$key.SetValue('Speed', 50)
    `$key.SetValue('Roughness', 0)
    `$key.SetValue('Breathiness', 0)
    `$key.SetValue('HeadSize', 50)
    `$key.SetValue('Gender', 0)
    `$key.SetValue('Age', 0)
}
`$root.Close()
" 2>$null
Write-Host "Default voice profiles saved"

# Uninstall entry
$uninstKey = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\ViaVoice"
$uninst = @{
    "DisplayName" = "ViaVoice SAPI5 Engine"
    "Publisher" = "ViaVoice"
    "DisplayVersion" = "1.0"
    "UninstallString" = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$instDir\install.ps1`" -Uninstall"
    "DisplayIcon" = "pythonw.exe"
    "InstallLocation" = $instDir
    "EstimatedSize" = 2000
}
New-Item -Path "$uninstKey" -Force | Out-Null
foreach ($k in $uninst.Keys) {
    Set-ItemProperty -Path "$uninstKey" -Name $k -Value $uninst[$k]
}
Write-Host "Uninstall entry registered"

Write-Host "`n=== Install complete ==="
Write-Host "Installed to: $instDir"
Write-Host "40 SAPI5 voice tokens (20 @ 22kHz + 20 @ 8kHz)"
Write-Host "Voice Manager: Start Menu > ViaVoice Manager"

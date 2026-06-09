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

foreach ($v in $voices) {
    $num = [array]::IndexOf($voices, $v) + 1
    $voiceHex = "0x{0:X2}" -f $num

    foreach ($rate in @("22kHz", "8kHz")) {
        $rateVal = if ($rate -eq "22kHz") { 0 } else { 1 }
        $tokenName = "VE_Voice${num}_$($v.Name)_${rate}"
        $displayName = "ViaVoice Voice $num - $($v.Name)"

        foreach ($path in $paths) {
            $fullPath = "$path\$tokenName"
            New-Item -Path "$fullPath" -Force | Out-Null
            Set-ItemProperty -Path "$fullPath" -Name "(Default)" -Value $displayName
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
    }

    $tokenName22 = "VE_Voice${num}_$($v.Name)_22kHz"
    Write-Host ("Created {0,-30} Voice=0x{1:X2}" -f $tokenName22, $num)
}

Write-Host "`nAll 40 tokens registered successfully."

# escape=`
FROM microsoft/windowsservercore

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

RUN $env:chocolateyUseWindowsCompression = 'false'; Invoke-WebRequest -Uri 'https://chocolatey.org/install.ps1' -UseBasicParsing -Verbose | Invoke-Expression -Verbose;
RUN choco feature enable -n=allowGlobalConfirmation

# Install Visual C++ Build Tools 2015 with ATL/MFC SDK
RUN choco install visualcppbuildtools -version 14.0.25420.1 --params="'--Features VisualCppBuildTools_ATLMFC_SDK'" --execution-timeout=14400

# Install Windows SDK 10 - avoids installing 'Windows IP Over USB-x86_en-us.msi'
RUN Invoke-WebRequest -Uri 'http://download.microsoft.com/download/2/1/2/2122BA8F-7EA6-4784-9195-A8CFB7E7388E/StandaloneSDK/sdksetup.exe' -UseBasicParsing -OutFile 'sdksetup.exe'

RUN $ExpectedSHA='4CD4BFE507EA78D70AAB139045B69ED57BD28BE446B07A40251F1283BB8B1D92'; `
    $ActualSHA=$(Get-FileHash -Path C:\sdksetup.exe -Algorithm SHA256).Hash; `
    If ($ExpectedSHA -ne $ActualSHA) { Throw 'sdksetup.exe hash does not match the expected value!' }

RUN New-Item -Path c:\sdksetup -Type Directory -Force|out-null ; `
    $procArgs=@('-norestart','-quiet','-ceip off','-Log c:\sdksetup\sdksetup.exe.log','-Layout c:\sdksetup', `
        '-Features OptionId.NetFxSoftwareDevelopmentKit OptionId.WindowsSoftwareDevelopmentKit'); `
    Write-Host 'Executing download of Win10SDK files (approximately 400mb)...'; `
    $proc=Start-Process -FilePath c:\sdksetup.exe -ArgumentList $procArgs -wait -PassThru ; `
    dir c:\sdksetup\Installers ; `
    if ($proc.ExitCode -eq 0) { `
        Write-Host 'Win10SDK download complete.' `
    } else { `
        get-content -Path c:\sdksetup\sdksetup.exe.log -ea Ignore| write-output ; `
        throw ('C:\SdkSetup.exe returned '+$proc.ExitCode) `
    }

RUN 'MobileIntellisense-x86.msi','UAPMobile-ARM.msi','UAPMobile-x86.msi','Universal CRT Extension SDK-x86_en-us.msi','Universal CRT Headers Libraries and Sources-x86_en-us.msi','Universal CRT Redistributable-x86_en-us.msi','Universal CRT Tools x64-x64_en-us.msi','Universal CRT Tools x86-x86_en-us.msi','Universal General MIDI DLS Extension SDK-x86_en-us.msi','WinAppDeploy-x86_en-us.msi','WinRT Intellisense Desktop - Other Languages-x86_en-us.msi','WinRT Intellisense Desktop - en-us-x86_en-us.msi','WinRT Intellisense IoT - Other Languages-x86_en-us.msi','WinRT Intellisense IoT - en-us-x86_en-us.msi','WinRT Intellisense PPI - Other Languages-x86_en-us.msi','WinRT Intellisense PPI - en-us-x86_en-us.msi','WinRT Intellisense UAP - Other Languages-x86_en-us.msi','WinRT Intellisense UAP - en-us-x86_en-us.msi','WinRT Intellisense Xbox Live Extension SDK - Other Languages-x86_en-us.msi','WinRT Intellisense Xbox Live Extension SDK - en-us-x86_en-us.msi','Windows Desktop Extension SDK Contracts-x86_en-us.msi','Windows Desktop Extension SDK-x86_en-us.msi','Windows IoT Extension SDK Contracts-x86_en-us.msi','Windows IoT Extension SDK-x86_en-us.msi','Windows SDK Desktop Headers Libs Metadata-x86_en-us.msi','Windows SDK Desktop Tools-x86_en-us.msi','Windows SDK DirectX x64 Remote-x64_en-us.msi','Windows SDK DirectX x86 Remote-x86_en-us.msi','Windows SDK EULA-x86_en-us.msi','Windows SDK Redistributables-x86_en-us.msi','Windows SDK for Windows Store Apps Contracts-x86_en-us.msi','Windows SDK for Windows Store Apps DirectX x64 Remote-x64_en-us.msi','Windows SDK for Windows Store Apps DirectX x86 Remote-x86_en-us.msi','Windows SDK for Windows Store Apps Headers Libs-x86_en-us.msi','Windows SDK for Windows Store Apps Tools-x86_en-us.msi','Windows SDK for Windows Store Apps-x86_en-us.msi','Windows SDK-x86_en-us.msi','Windows Team Extension SDK Contracts-x86_en-us.msi','Windows Team Extension SDK-x86_en-us.msi','WindowsPhoneSdk-Desktop.msi' ` `
    | ForEach-Object -Process { `
        Write-Host ('Executing MsiExec.exe with parameters:'); `
        $MsiArgs=@(('/i '+[char]0x0022+'c:\sdksetup\Installers\'+$_+[char]0x0022), `
            ('/log '+[char]0x0022+'c:\sdksetup\'+$_+'.log'+[char]0x0022),'/qn','/norestart'); `
        Write-Output $MsiArgs; `
        $proc=Start-Process msiexec.exe -ArgumentList $MsiArgs -Wait -PassThru -Verbose; `
        if ($proc.ExitCode -eq 0) { Write-Host '...Success!' `
        } else { `
            get-content -Path ('c:\sdksetup\'+$_+'.log') -ea Ignore | write-output; `
            throw ('...Failure!  '+$_+' returned '+$proc.ExitCode) `
        } `
    }; `
    $win10sdkBinPath = ${env:ProgramFiles(x86)}+'\Windows Kits\10\bin\x64'; `
    if (Test-Path -Path $win10sdkBinPath\mc.exe) { `
      Write-Host 'Win10 SDK 10.0.10586 Installation Complete.' ; `
      Remove-Item c:\sdksetup.exe -Force; `
      Remove-Item c:\sdksetup\ -Recurse -Force; `
    } else { Throw 'Installation failed!  See logs under c:\sdksetup\' };

RUN choco install cmake -version 3.7.0
RUN choco install git -version 2.10.2
RUN choco install sliksvn -version 1.8.5.20140421
RUN choco install python -version 3.5.2.20161029
RUN python -m pip install --upgrade pip
RUN python -m pip install requests requests_toolbelt
RUN choco install ant -version 1.9.7
RUN choco install jom -version 1.0.16
RUN choco install nasm -version 2.12.02

RUN New-Item C:\scripts -type directory; New-Item C:\scripts\signfile.ps1 -type file

RUN [Environment]::SetEnvironmentVariable('Path', $env:Path + ';C:\Program Files\CMake\bin;C:\Program Files (x86)\NASM;C:\scripts', [EnvironmentVariableTarget]::Machine);

WORKDIR "C:/workdir"

RUN Write-Host 'Configuring environment'; pushd 'C:\Program Files (x86)\Microsoft Visual C++ Build Tools' ; cmd /c 'vcbuildtools.bat amd64 & set' | foreach { if ($_ -match '=') { $v = $_.split('='); [Environment]::SetEnvironmentVariable($v[0], $v[1], [EnvironmentVariableTarget]::Machine) } } ; popd

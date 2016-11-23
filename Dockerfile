FROM microsoft/windowsservercore

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

RUN $env:chocolateyUseWindowsCompression = 'false'; Invoke-WebRequest -Uri 'https://chocolatey.org/install.ps1' -UseBasicParsing -Verbose | Invoke-Expression -Verbose;

RUN choco feature enable -n=allowGlobalConfirmation
RUN choco install visualcppbuildtools -packageParameters --execution-timeout=14400
RUN choco install cmake -version 3.7.0
RUN choco install git -version 2.10.2
RUN choco install sliksvn -version 1.8.5.20140421
RUN choco install python -version 3.5.2.20161029
RUN python -m pip install --upgrade pip
RUN python -m pip install requests requests_toolbelt
RUN choco install ant -version 1.9.7

RUN [Environment]::SetEnvironmentVariable('Path', $env:Path + ';C:\Program Files\CMake\bin', [EnvironmentVariableTarget]::Machine);

WORKDIR "C:/workdir"

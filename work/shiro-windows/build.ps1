$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path "$PSScriptRoot/../..").Path
$Output = Join-Path $ProjectRoot 'outputs/Shiro-Windows-x64'
dotnet run --project "$PSScriptRoot/Tests/Tests.csproj" -c Release
if ($LASTEXITCODE -ne 0) { throw 'Tests failed' }
dotnet publish "$PSScriptRoot/Shiro.csproj" -c Release -r win-x64 --self-contained true -o $Output -p:PublishReadyToRun=false
if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
Copy-Item "$ProjectRoot/Инструкция.md" "$Output/README.txt"
Copy-Item "$ProjectRoot/work/shiro-ui-assets/fonts/OFL-*.txt" $Output
Copy-Item "$ProjectRoot/work/shiro-ui-assets/sounds/CREDITS.txt" $Output
Compress-Archive -Path $Output -DestinationPath "$ProjectRoot/outputs/Shiro-Windows-x64.zip" -Force

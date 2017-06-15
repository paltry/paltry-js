@echo off
title Paltry JS

set SSH_REPO_URL=" "
set HTTPS_REPO_URL="https://github.com/skidding/flatris.git"
set REPO_FOLDER="test-repo"
set PROJECT_FOLDER="."
set CONFIG_XML_FILE="pom.xml"
set CONFIG_XML_XPATH="//*[name()='nodeVersion']"

set TMP_SCRIPT="%TMP%\%~n0.ps1"
for /f "delims=:" %%a in ('findstr -n "^___" %0') do set "Line=%%a"
(for /f "skip=%Line% tokens=* eol=_" %%a in ('type %0') do echo(%%a) > %TMP_SCRIPT%

powershell -ExecutionPolicy RemoteSigned -File %TMP_SCRIPT% ^
  -SshRepoUrl "%SSH_REPO_URL%" -HttpsRepoUrl "%HTTPS_REPO_URL%" ^
  -RepoFolder "%REPO_FOLDER%" -ProjectFolder "%PROJECT_FOLDER%" ^
  -ConfigXmlFile "%CONFIG_XML_FILE%" -ConfigXmlXpath "%CONFIG_XML_XPATH%"

exit

___SCRIPT___
Param(
  [string]$SshRepoUrl,
  [string]$HttpsRepoUrl,
  [string]$RepoFolder,
  [string]$ProjectFolder,
  [string]$ConfigXmlFile,
  [string]$ConfigXmlXpath
)
Add-Type -Assembly "System.IO.Compression.FileSystem"
$CurrentFolder = $PWD
$UserProfile = $Env:USERPROFILE
$DownloadsFolder = "$UserProfile\Downloads"
$TempFolder = "$UserProfile\Temp"
$ToolsFolder = "$CurrentFolder\tools"
$VsCodeDataFolder = "$CurrentFolder\vscode"
$FullRepoFolder = "$CurrentFolder\$RepoFolder"
$WebClient = New-Object System.Net.WebClient
$WebClient.Headers.Add("User-Agent", "PowerShell")
$Online = Test-Connection -ComputerName 8.8.8.8 -Quiet -ErrorAction Ignore
New-Item -ItemType Directory -Force -Path $DownloadsFolder | Out-Null
New-Item -ItemType Directory -Force -Path $TempFolder | Out-Null
New-Item -ItemType Directory -Force -Path $ToolsFolder | Out-Null

Function Log-Info($Message) {
  Write-Host -ForegroundColor "Green" $Message
}
Function Log-Warn($Message) {
  Write-Host -ForegroundColor "Yellow" $Message
}

Function Require-Online {
  if(!$Online) {
    $ErrorMessage = "Required files not downloaded and you are offline"
    (New-Object -ComObject Wscript.Shell).Popup($ErrorMessage, 0, "ERROR!", 16)
    exit 1
  }
}

Function InstallTool($Name, $Url, $Prefix) {
  if($Online) {
    $ToolFile = $Url.Split("/") | Select-Object -Last 1
    $ToolFolder = [io.path]::GetFileNameWithoutExtension($ToolFile)
    if(!($ToolFolder.Contains("."))) {
      $Url = [System.Net.WebRequest]::Create($Url).GetResponse().ResponseUri.AbsoluteUri
      $ToolFile = $Url.Split("/") | Select-Object -Last 1
      $ToolFolder = [io.path]::GetFileNameWithoutExtension($ToolFile)
    }
    $DownloadedFile = "$DownloadsFolder\$ToolFile"
    $ExtractedFolder = "$TempFolder\$Name"
    $InstalledFolder = "$ToolsFolder\$ToolFolder"
  } else {
    $InstalledFolder = Get-ChildItem $ToolsFolder -Filter $Prefix |
    Sort-Object Name -Descending | Select-Object -First 1 | %{ $_.FullName }
    if(!$InstalledFolder) {
      Require-Online
    }
  }
  if(!(Test-Path $InstalledFolder)) {
    if(!(Test-Path $DownloadedFile)) {
      Require-Online
      Log-Info "Downloading $Name..."
      $WebClient.DownloadFile($Url, $DownloadedFile)
    }
    Log-Info "Extracting $Name..."
    Remove-Item -Recurse -ErrorAction Ignore $ExtractedFolder
    [System.IO.Compression.ZipFile]::ExtractToDirectory($DownloadedFile, $ExtractedFolder)
    $ExtractedContents = Get-ChildItem $ExtractedFolder
    if($ExtractedContents.Length -eq 1 -And $ExtractedContents[0].PSIsContainer) {
      Move-Item $ExtractedContents[0].FullName $InstalledFolder
      Remove-Item $ExtractedFolder
    } else {
      Move-Item $ExtractedFolder $InstalledFolder
    }
  }
  $ToolBinFolder = Get-ChildItem -Recurse $InstalledFolder -Filter *.exe | Select-Object -First 1 | %{ $_.Directory.FullName }
  $Env:Path = "$ToolBinFolder;$Env:Path"
}

$GitReleaseApiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
if($Online) {
  $MinGitRelease = $WebClient.DownloadString($GitReleaseApiUrl) | ConvertFrom-Json |
    Select -Expand assets | Where-Object { $_.name -Match "MinGit.*64-bit.zip" }
}
$MinGitUrl = $MinGitRelease.browser_download_url
InstallTool -Name "Git" -Url $MinGitUrl -Prefix MinGit*
if(!(Test-Path $FullRepoFolder)) {
  Require-Online
  Log-Info "Cloning Repo..."
  if((Test-Path "$UserProfile\.ssh") -And $SshRepoUrl) {
    git clone $SshRepoUrl $RepoFolder
  }
  if(!(Test-Path $FullRepoFolder)) {
    git clone $HttpsRepoUrl $RepoFolder
  }
}

$ConfigXmlPath = "$FullRepoFolder\$ConfigXmlFile"
if((Test-Path $ConfigXmlPath) -And $ConfigXmlXpath) {
  $NodeVersion = Select-Xml -Path $ConfigXmlPath -XPath $ConfigXmlXpath | %{ $_.Node.'#text' }
}
if(!$NodeVersion) {
  $NodeVersion = $Env:NODE_VERSION
}
if(!$NodeVersion -And $Online) {
  $LatestNodeHashesUrl = "https://nodejs.org/dist/latest/SHASUMS256.txt"
  $NodeVersionRegEx = "^node-v([\d\.]+)-win-x64.zip$"
  $NodeVersion = $WebClient.DownloadString($LatestNodeHashesUrl) -Split "\n" |
    %{ $_ -Split "\s+" | Select-Object -Last 1 } | ?{ $_ -Match $NodeVersionRegEx } |
    %{ $_ -Replace $NodeVersionRegEx, '$1' }
}
$NodeUrl = "https://nodejs.org/dist/v$NodeVersion/node-v$NodeVersion-win-x64.zip"
InstallTool -Name "Node.js" -Url $NodeUrl -Prefix node*
cd "$FullRepoFolder\$ProjectFolder"
if($Online) {
  if(!(Test-Path node_modules)) {
    Log-Info "Installing JavaScript Dependencies..."
    Log-Warn "Please be patient, this will take a moment..."
  } else {
    Log-Info "Updating JavaScript Dependencies..."
  }
  npm install
}

$VsCodeUrl = "https://vscode-update.azurewebsites.net/latest/win32-archive/stable"
InstallTool -Name "VS Code" -Url $VsCodeUrl -Prefix VSCode*
Log-Info "Launching VS Code..."
code --user-data-dir $VsCodeDataFolder --extensions-dir "$VsCodeDataFolder\extensions" .
powershell
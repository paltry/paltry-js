#!/bin/bash

gitRepoUrl="https://github.com/skidding/flatris.git"
gitRepoFolder="test-repo"
projectFolder="."

mkdir -p ~/Downloads
mkdir -p tools

if [[ ! -e $gitRepoFolder ]]; then
  echo Cloning Repo...
  git clone $gitRepoUrl $gitRepoFolder
fi

# TODO: find version from project

# TODO: get latest node version as fallback
nodeVersion=8.0.0
case $(uname -s) in
  Darwin)
    gitUrl=https://nodejs.org/dist/v$nodeVersion/node-v$nodeVersion-darwin-x64.tar.gz
    extractedNode=$(pwd)/tools/$(basename $gitUrl .tar.gz)
    ;;
  Linux)
    gitUrl=https://nodejs.org/dist/v$nodeVersion/node-v$nodeVersion-linux-x64.tar.xz
    extractedNode=$(pwd)/tools/$(basename $gitUrl .tar.xz)
    ;;
esac
downloadedNode=~/Downloads/$(basename $gitUrl)
if [[ ! -e $extractedNode ]]; then
  if [[ ! -e $downloadedNode ]]; then
    echo Downloading Node.js...
    curl $gitUrl > $downloadedNode
  fi
  echo Extracting Node.js...
  tar xf $downloadedNode -C tools
fi
export PATH="$extractedNode/bin:$PATH"

case $(uname -s) in
  Darwin)
    vsCodeUrl=https://vscode-update.azurewebsites.net/latest/darwin/stable
    downloadedVsCode=~/Downloads/VSCode-darwin-stable.zip
    extractedVsCode=$(pwd)/tools/Visual\ Studio\ Code.app
    ;;
  Linux)
    vsCodeUrl=https://vscode-update.azurewebsites.net/latest/linux-x64/stable
    downloadedVsCode=~/Downloads/VSCode-linux-x64-stable.tar.gz
    extractedVsCode=$(pwd)/tools/VSCode-linux-x64
    ;;
esac
if [[ ! -e $extractedVsCode ]]; then
  if [[ ! -e $downloadedVsCode ]]; then
    echo Downloading VS Code...
    curl -L $vsCodeUrl > $downloadedVsCode
  fi
  echo Extracting VS Code...
  case $(uname -s) in
    Darwin)
      unzip -q $downloadedVsCode -d tools
      ;;
    Linux)
      tar xf $downloadedVsCode -C tools
      ;;
  esac
fi

cd $gitRepoFolder
if [[ ! -e node_modules ]]; then
  echo Installing JavaScript Dependencies...
  echo Please be patient, this will take a moment...
else
  echo Updating JavaScript Dependencies...
fi
npm install

case $(uname -s) in
  Darwin)
    ../tools/Visual\ Studio\ Code.app/Contents/MacOS/Electron --user-data-dir data --extensions-dir data/extensions .
    ;;
  Linux)
    ../tools/VSCode-linux-x64/bin/code --user-data-dir data --extensions-dir data/extensions .
    ;;
esac
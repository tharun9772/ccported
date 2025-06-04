# CCPorted Self-Hosting Setup Script for Windows
# PowerShell Script

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "CCPorted Self-Hosting Setup (Windows)" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# Check and install required tools
Write-Host "Checking for required tools..." -ForegroundColor Yellow
$requiredTools = @(
    @{Name = "git"; InstallCommand = { 
        Write-Host "Installing Git..." -ForegroundColor Yellow
        $installerUrl = "https://github.com/git-for-windows/git/releases/download/v2.41.0.windows.3/Git-2.41.0.3-64-bit.exe"
        $installerPath = "$env:TEMP\GitInstaller.exe"
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
        Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT /NORESTART" -Wait
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }},
    @{Name = "node"; InstallCommand = { 
        Write-Host "Installing Node.js..." -ForegroundColor Yellow
        $installerUrl = "https://nodejs.org/dist/v20.11.1/node-v20.11.1-x64.msi"
        $installerPath = "$env:TEMP\NodeInstaller.msi"
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$installerPath`" /qn" -Wait
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }}
)

foreach ($tool in $requiredTools) {
    if (-not (Get-Command $tool.Name -ErrorAction SilentlyContinue)) {
        Write-Host "⚠️ $($tool.Name) is not installed. Installing now..." -ForegroundColor Yellow
        & $tool.InstallCommand
        
        # Check if installation was successful
        if (-not (Get-Command $tool.Name -ErrorAction SilentlyContinue)) {
            Write-Host "❌ Failed to install $($tool.Name). Please install it manually and try again." -ForegroundColor Red
            exit 1
        }
    }
}

# Check for AWS CLI (optional)
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "AWS CLI is not installed. It will be installed if you choose to download games." -ForegroundColor Yellow
}

Write-Host "✅ Required tools found or installed" -ForegroundColor Green

# Create project directory
$installDir = "$PWD\ccported"
Write-Host "Setting up CCPorted in: $installDir" -ForegroundColor Yellow
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}
Set-Location $installDir

# Clone repository
Write-Host "Cloning the CCPorted repository..." -ForegroundColor Yellow
if (Test-Path ".git") {
    git pull
} else {
    git clone https://github.com/ccported/ccported.github.io.git .
}

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Yellow
npm install

# Install htmlc globally
Write-Host "Installing htmlc compiler..." -ForegroundColor Yellow
npm install -g @sojs_coder/htmlc@1.3.5

# Create directory for games
Write-Host "Creating directories..." -ForegroundColor Yellow
if (-not (Test-Path "games")) {
    New-Item -ItemType Directory -Path "games" | Out-Null
}

# Clone emdata repository
Write-Host "Setting up emulator data..." -ForegroundColor Yellow
if (-not (Test-Path "emdata")) {
    Write-Host "Cloning emdata repository..." -ForegroundColor Yellow
    git clone https://github.com/ccported/emdata.git emdata
    
    # Make sure /data is in the right place
    if (Test-Path "emdata\data" -PathType Container) {
        Write-Host "✅ Emdata repository cloned successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Emdata repository structure is different than expected. Checking branch..." -ForegroundColor Yellow
        Set-Location emdata
        git checkout main
        if (-not (Test-Path "data" -PathType Container)) {
            Write-Host "Creating data directory..." -ForegroundColor Yellow
            New-Item -ItemType Directory -Path "data" | Out-Null
        }
        Set-Location ..
    }
} else {
    Write-Host "Updating emdata repository..." -ForegroundColor Yellow
    Set-Location emdata
    git pull
    Set-Location ..
}

# Download games from S3 bucket (optional)
Write-Host "Do you want to download games from the S3 bucket? (This is a public bucket, no credentials required)" -ForegroundColor Yellow
$downloadGames = Read-Host "Download games? (y/n)"

if ($downloadGames -eq "y" -or $downloadGames -eq "Y") {
    Write-Host "Preparing to download games from the public S3 bucket..." -ForegroundColor Yellow
    
    # Check if AWS CLI is installed, if not install it
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Host "Installing AWS CLI..." -ForegroundColor Yellow
        $awsInstaller = "$env:TEMP\AWSCLIV2.msi"
        Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $awsInstaller
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$awsInstaller`" /qn" -Wait
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # Verify installation
        if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
            Write-Host "AWS CLI installation might have failed. Trying alternative download method..." -ForegroundColor Yellow
            
            # Create a directory for game categories
            $gameCategories = @("gb", "gba", "nes", "snes", "n64", "genesis")
            foreach ($category in $gameCategories) {
                if (-not (Test-Path "games\$category")) {
                    New-Item -ItemType Directory -Path "games\$category" -Force | Out-Null
                }
            }
            
            # Use direct HTTP download instead
            Write-Host "Using direct HTTP download for sample games..." -ForegroundColor Yellow
            try {
                # Example: Download a few sample games
                $baseUrl = "https://ccportedroms.s3.us-west-2.amazonaws.com"
                $samples = @(
                    @{Category="gb"; File="tetris.gb"},
                    @{Category="gba"; File="pokemon_emerald.gba"},
                    @{Category="nes"; File="super_mario_bros.nes"}
                )
                
                foreach ($sample in $samples) {
                    $url = "$baseUrl/$($sample.Category)/$($sample.File)"
                    $destination = "games\$($sample.Category)\$($sample.File)"
                    Write-Host "Downloading $($sample.File) to $destination..." -ForegroundColor Yellow
                    try {
                        Invoke-WebRequest -Uri $url -OutFile $destination
                    } catch {
                        Write-Host "Could not download $($sample.File): $_" -ForegroundColor Red
                    }
                }
            } catch {
                Write-Host "Error during direct download: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "AWS CLI installed successfully" -ForegroundColor Green
        }
    }
    
    try {
        # Configure AWS CLI for anonymous access
        Write-Host "Configuring AWS CLI for public bucket access..." -ForegroundColor Yellow
        aws configure set default.region us-west-2
        
        # Download from S3 with public access (no credentials needed)
        Write-Host "Downloading games from S3 bucket (this may take a while)..." -ForegroundColor Yellow
        aws s3 sync s3://ccportedroms games/ --no-sign-request --region us-west-2
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠️ There might have been issues downloading all games. Some games may be missing." -ForegroundColor Yellow
        } else {
            Write-Host "✅ Games downloaded successfully" -ForegroundColor Green
        }
        
        # Create roms.json based on downloaded content
        Write-Host "Creating roms.json file..." -ForegroundColor Yellow
        
        # Create directory if it doesn't exist
        if (-not (Test-Path "static\roms")) {
            New-Item -ItemType Directory -Path "static\roms" | Out-Null
        }
        
        # Create a simple roms.json based on directory structure
        $romCategories = @{}
        
        Get-ChildItem -Path "games" -Directory | ForEach-Object {
            $categoryName = $_.Name
            $files = @()
            
            Get-ChildItem -Path $_.FullName -File | ForEach-Object {
                $fileName = $_.Name
                $displayName = $fileName -replace '\.[^.]+$', '' -replace '_', ' '
                $displayName = (Get-Culture).TextInfo.ToTitleCase($displayName)
                $files += ,@($fileName, $displayName)
            }
            
            if ($files.Count -gt 0) {
                $romCategories[$categoryName] = $files
            }
        }
        
        $romCategories | ConvertTo-Json -Depth 3 | Out-File -FilePath "static\roms\roms.json" -Encoding utf8
    } catch {
        Write-Host "❌ Error downloading games: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Skipping game downloads." -ForegroundColor Yellow
}

# Build the site
Write-Host "Building the site..." -ForegroundColor Yellow
htmlc static --out=build

# Configure the server
Write-Host "Configuring server..." -ForegroundColor Yellow

# Use the self-hosted server.js version
Write-Host "Setting up self-hosted server configuration..." -ForegroundColor Yellow
if (Test-Path "server.self-hosted.js") {
    Copy-Item -Path "server.self-hosted.js" -Destination "server.js" -Force
} else {
    Write-Host "Creating custom server configuration..." -ForegroundColor Yellow
    $serverContent = @'
import { serve } from 'bun';
import { join } from 'path';
import { statSync, existsSync } from 'fs';
import { createBareServer } from '@tomphttp/bare-server-node';

// Config
const PORT = process.env.PORT || 3000;
const BUILD_DIR = './build';
const GAMES_DIR = './games';
const EMDATA_DIR = './emdata/data'; // Updated path to emdata repository data
const BARE_PATH = '/bare/';

// Initialize bare-server
const bareServer = createBareServer(BARE_PATH);

// Helper to serve static files
function serveStatic(baseDir, pathname, shave = true) {
  const relativePath = shave ? pathname.substring(pathname.indexOf('/', 1)) : pathname;
  const filePath = join(process.cwd(), baseDir, relativePath);

  try {
    if (existsSync(filePath)) {
      const stat = statSync(filePath);

      if (stat.isDirectory()) {
        const indexPath = join(filePath, 'index.html');
        if (existsSync(indexPath)) {
          return new Response(Bun.file(indexPath));
        }
        return new Response('Directory listing not allowed', { status: 403 });
      }

      return new Response(Bun.file(filePath));
    }
  } catch (err) {
    console.error(`[ERROR] Serving ${filePath}:`, err);
  }

  return new Response('Not found', { status: 404 });
}

serve({
  port: PORT,
  fetch: async (req) => {
    const url = new URL(req.url);
    const path = url.pathname;

    console.log(`[REQ] ${req.method} ${path}`);

    if (bareServer.shouldRoute(req)) {
      return bareServer.handleRequest(req);
    }

    if (path.startsWith('/games/')) {
      return serveStatic(GAMES_DIR, path);
    }

    if (path.startsWith('/emdata/')) {
      return serveStatic(EMDATA_DIR, path);
    }

    // /roms/ route is disabled in self-hosted version
    if (path.startsWith('/roms/')) {
      return new Response('The /roms/ route is disabled in self-hosted mode', { status: 403 });
    }

    return serveStatic(BUILD_DIR, path, false);
  },

  websocket: {
    // Bun requires `message` handler to be defined
    message(ws, message) {
      // no-op (bare handles WebSocket internally)
    },

    open(ws) {
      // optional
    },

    close(ws) {
      // optional
    },

    upgrade(req, socket) {
      if (bareServer.shouldRoute(req)) {
        bareServer.routeUpgrade(req, socket);
      } else {
        socket.end();
      }
    }
  }
});

console.log(`✅ Server running at http://localhost:${PORT} with bare proxy at ${BARE_PATH}`);
console.log(`✅ Games served from ${GAMES_DIR}`);
console.log(`✅ Emulator data served from ${EMDATA_DIR}`);
console.log(`❌ /roms/ route is disabled in self-hosted mode`);
'@

    Set-Content -Path "server.js" -Value $serverContent
}

# Create .env file if it doesn't exist
if (-not (Test-Path ".env")) {
    @"
PORT=3000
WEBSITE_URL="http://localhost:3000"
"@ | Out-File -FilePath ".env" -Encoding utf8
}

# Make sure bun is installed
if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Bun runtime..." -ForegroundColor Yellow
    
    # Use PowerShell to download and run the Bun installer
    powershell -Command "iwr https://bun.sh/install.ps1 -UseBasicParsing | iex"
    
    # Update PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    
    if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
        Write-Host "❌ Bun installation failed. Using Node.js fallback." -ForegroundColor Yellow
        
        # Create a Node.js fallback server
        $nodeServerContent = @'
const express = require('express');
const path = require('path');
const fs = require('fs');

// Create Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files from build directory
app.use(express.static(path.join(__dirname, 'build')));

// Games route
app.use('/games', express.static(path.join(__dirname, 'games')));

// Emdata route
app.use('/emdata', express.static(path.join(__dirname, 'emdata/data')));

// Disable /roms/ route
app.use('/roms', (req, res) => {
  res.status(403).send('The /roms/ route is disabled in self-hosted mode');
});

// All other routes serve index.html
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'build', 'index.html'));
});

// Start server
app.listen(PORT, () => {
  console.log(`✅ Server running at http://localhost:${PORT}`);
  console.log(`✅ Games served from ./games`);
  console.log(`✅ Emulator data served from ./emdata/data`);
  console.log(`❌ /roms/ route is disabled in self-hosted mode`);
});
'@
        Set-Content -Path "node-server.js" -Value $nodeServerContent
        
        # Install Express
        npm install express --save
        
        # Update package.json start script
        $packageJson = Get-Content -Path "package.json" -Raw | ConvertFrom-Json
        $packageJson.scripts.start = "node node-server.js"
        $packageJson | ConvertTo-Json -Depth 4 | Set-Content -Path "package.json"
    }
}

# Create batch file to start the server
@"
@echo off
cd %~dp0
echo Starting CCPorted server...
echo If you encounter any issues starting with Bun, try uncommenting the Node.js fallback below.

bun run server.js
REM If Bun doesn't work, try Node.js fallback:
REM node node-server.js

pause
"@ | Out-File -FilePath "start-ccported.bat" -Encoding ascii

Write-Host "=====================================" -ForegroundColor Green
Write-Host "✅ CCPorted setup complete!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host "To start the server, run: start-ccported.bat" -ForegroundColor Cyan
Write-Host "Once started, visit: http://localhost:3000" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Green

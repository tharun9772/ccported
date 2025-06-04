# CCPorted Deployment Guide

This document provides detailed instructions for deploying CCPorted in various environments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Basic Deployment](#basic-deployment)
- [Advanced Configuration](#advanced-configuration)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

The setup scripts will automatically install:
- **Node.js** (v14 or later)
- **npm** (comes with Node.js)
- **Git** (for cloning the repository)
- **AWS CLI** (for downloading games from S3, only if you choose to download games)
- **Bun** (runtime for the server, with Node.js fallback)

### System Requirements

- At least 1GB of RAM
- 2GB+ of disk space (more if downloading multiple games)
- A modern operating system (Linux, macOS, Windows)

## Basic Deployment

### 1. Setup with Automated Script

#### Linux/macOS
```bash
wget -O setup-ccported.sh https://raw.githubusercontent.com/ccported/ccported.github.io/main/setup-ccported.sh
chmod +x setup-ccported.sh
./setup-ccported.sh
```

#### Windows
```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/ccported/ccported.github.io/main/setup-ccported.ps1 -OutFile setup-ccported.ps1
.\setup-ccported.ps1
```

### 2. Manual Setup

If you prefer to set up everything manually:

1. Clone the repository:
   ```bash
   git clone https://github.com/ccported/ccported.github.io.git
   cd ccported.github.io
   ```

2. Install dependencies:
   ```bash
   npm install
   npm install -g @sojs_coder/htmlc@1.3.5
   ```

3. Create necessary directories:
   ```bash
   mkdir -p games emdata
   ```

4. Build the site:
   ```bash
   htmlc static --out=build
   ```

5. Start the server:
   ```bash
   npm start
   ```

## Advanced Configuration

### Environment Variables

Create a `.env` file in the project root:

```
PORT=3000                        # The port to run the server on
WEBSITE_URL=http://example.com   # Your website URL (for absolute URLs)
```

### Emulator Data Structure

The setup script automatically clones the emdata repository from GitHub:

```
emdata/
└── data/
    ├── cores/
    │   └── (various emulator cores)
    ├── js/
    │   └── (emulator JavaScript files)
    └── wasm/
        └── (WebAssembly files)
```

### Custom Game Structure

Games are served from the `games/` directory and downloaded from the public S3 bucket. No credentials are required for access. Organize games by category:

```
games/
├── gba/
│   ├── game1.gba
│   └── game2.gba
├── nes/
│   ├── game3.nes
│   └── game4.nes
└── gb/
    ├── game5.gb
    └── game6.gb
```

Then create a corresponding `static/roms/roms.json` file:

```json
{
  "gba": [
    ["game1.gba", "Game 1 Title"],
    ["game2.gba", "Game 2 Title"]
  ],
  "nes": [
    ["game3.nes", "Game 3 Title"],
    ["game4.nes", "Game 4 Title"]
  ],
  "gb": [
    ["game5.gb", "Game 5 Title"],
    ["game6.gb", "Game 6 Title"]
  ]
}
```

## Troubleshooting

### Common Issues

1. **"Cannot find module '@sojs_coder/htmlc'"**
   - Make sure you've installed htmlc globally: `npm install -g @sojs_coder/htmlc@1.3.5`

2. **"Error: Cannot find module 'bun'"**
   - The Bun runtime may have failed to install. Use the Node.js fallback:
   ```powershell
   # Windows
   node node-server.js
   
   # Linux/macOS
   node node-server.js
   ```

3. **"EADDRINUSE: address already in use"**
   - Change the port in .env file or stop the process using the current port:
   ```powershell
   # Find the process using port 3000
   Get-NetTCPConnection -LocalPort 3000 | Format-List
   
   # Kill the process
   Stop-Process -Id <PID>
   ```

4. **Games not showing up**
   - Check that the games are in the correct directory structure
   - Verify that roms.json has been created properly
   - Make sure paths in roms.json match your actual file structure
   - Check that the `/games/` route is working correctly

5. **Emulator data not loading**
   - Verify the emdata repository was cloned correctly: `ls emdata/data`
   - Check that the `/emdata/` route is working and returns the correct files
   - Ensure the emdata files are being served from `./emdata/data`

6. **Blank/white page**
   - Check the browser console for errors
   - Verify that the build process completed successfully
   - Make sure all required files are in the build directory

### Getting Support

If you encounter issues not covered here, you can:

- Join the Discord server: https://discord.gg/GDEFRBTT3Z
- Create an issue on the GitHub repository
- Check the project's documentation for updates

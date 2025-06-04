#!/bin/bash
# CCPorted Quick Setup Script
# Run with: wget -O - https://raw.githubusercontent.com/ccported/ccported.github.io/main/quicksetup.sh | bash

echo "====================================="
echo "CCPorted Quick Setup"
echo "====================================="

# Auto-install required packages
install_if_missing() {
    if ! command -v $1 &> /dev/null; then
        echo "Installing $1..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -q
            sudo apt-get install -y $2
        elif command -v yum &> /dev/null; then
            sudo yum install -y $2
        elif command -v brew &> /dev/null; then
            brew install $2
        else
            echo "Unable to install $1. Please install it manually."
            return 1
        fi
    fi
}

# Install required tools
install_if_missing git git
install_if_missing node nodejs
install_if_missing npm npm

# Create or use existing directory
INSTALL_DIR="$(pwd)/ccported"
echo "Setting up CCPorted in: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Clone repository
echo "Cloning CCPorted repository..."
git clone https://github.com/ccported/ccported.github.io.git .
if [ $? -ne 0 ]; then
    # If directory isn't empty, just pull latest changes
    git pull
fi

# Install dependencies
echo "Installing dependencies..."
npm install
npm install -g @sojs_coder/htmlc@1.3.5

# Clone emdata repository
echo "Setting up emulator data..."
if [ ! -d "emdata" ]; then
    echo "Cloning emdata repository..."
    git clone https://github.com/ccported/emdata.git emdata
fi

# Create games directory
mkdir -p games
echo "Downloading some sample games from S3 (public bucket, no credentials needed)..."
# Try to install AWS CLI if not available
if ! command -v aws &> /dev/null; then
    if command -v curl &> /dev/null; then
        # Use curl to download a few sample games directly
        mkdir -p games/{gb,gba,nes}
        curl -s "https://ccportedroms.s3.us-west-2.amazonaws.com/gb/tetris.gb" -o "games/gb/tetris.gb" || true
        curl -s "https://ccportedroms.s3.us-west-2.amazonaws.com/gba/pokemon_emerald.gba" -o "games/gba/pokemon_emerald.gba" || true
        curl -s "https://ccportedroms.s3.us-west-2.amazonaws.com/nes/super_mario_bros.nes" -o "games/nes/super_mario_bros.nes" || true
    fi
else
    # Use AWS CLI with public access (no credentials needed)
    aws s3 sync s3://ccportedroms games/ --no-sign-request --region us-west-2
fi

# Create roms.json
echo "Creating roms.json file..."
mkdir -p static/roms
echo '{' > static/roms/roms.json
first_category=true

for category in $(find games -type d -mindepth 1 -maxdepth 1 | sort); do
  category_name=$(basename "$category")
  
  if [ "$first_category" = true ]; then
    first_category=false
  else
    echo ',' >> static/roms/roms.json
  fi
  
  echo "  \"$category_name\": [" >> static/roms/roms.json
  
  first_file=true
  for file in $(find "$category" -type f | sort); do
    filename=$(basename "$file")
    display_name=$(echo "$filename" | sed 's/\.[^.]*$//' | tr '_' ' ' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
    
    if [ "$first_file" = true ]; then
      first_file=false
    else
      echo ',' >> static/roms/roms.json
    fi
    
    echo "    [\"$filename\", \"$display_name\"]" >> static/roms/roms.json
  done
  
  echo '  ]' >> static/roms/roms.json
done

echo '}' >> static/roms/roms.json

# Setup server.js for self-hosted mode
echo "Setting up self-hosted server..."
cat > server.js << 'EOL'
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
EOL

# Create a Node.js fallback server
echo "Creating Node.js fallback server..."
cat > node-server.js << 'EOL'
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
EOL

# Install Express for the fallback server
npm install express --save

# Build the site
echo "Building the site..."
htmlc static --out=build

# Create .env file
cat > .env << EOL
PORT=3000
WEBSITE_URL="http://localhost:3000"
EOL

# Create startup script
cat > start.sh << 'EOL'
#!/bin/bash
# Start CCPorted server
cd "$(dirname "$0")"

echo "Starting CCPorted server..."
echo "Try to use Bun first, fallback to Node.js if needed"

# Try bun first
if command -v bun &> /dev/null; then
  bun run server.js
else
  # Node.js fallback
  node node-server.js
fi
EOL
chmod +x start.sh

# Start server
echo "====================================="
echo "Setup complete! Starting the server..."
echo "Press Ctrl+C to stop the server"
echo "====================================="
./start.sh

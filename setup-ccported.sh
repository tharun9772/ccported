#!/bin/bash
# CCPorted Self-Hosting Setup Script
# This script sets up CCPorted on your local machine

# Exit on error
set -e

echo "====================================="
echo "CCPorted Self-Hosting Setup"
echo "====================================="

# Check and install required tools
echo "Checking for required tools..."

# Function to install packages
install_package() {
  if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    sudo apt-get update
    sudo apt-get install -y $1
  elif [ -f /etc/redhat-release ]; then
    # CentOS/RHEL/Fedora
    sudo yum install -y $1
  elif [ -f /etc/arch-release ]; then
    # Arch Linux
    sudo pacman -Sy --noconfirm $1
  elif [ -f /etc/SuSE-release ]; then
    # OpenSUSE
    sudo zypper install -y $1
  elif [ "$(uname)" == "Darwin" ]; then
    # macOS
    brew install $1
  else
    echo "❌ Unsupported distribution. Please install $1 manually."
    return 1
  fi
}

# Check and install git
if ! command -v git &> /dev/null; then
  echo "⚠️ git is not installed. Installing..."
  install_package git
fi

# Check and install Node.js and npm
if ! command -v node &> /dev/null; then
  echo "⚠️ Node.js is not installed. Installing..."
  
  # Using the NodeSource repository for consistent installation
  if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
  elif [ -f /etc/redhat-release ]; then
    # CentOS/RHEL/Fedora
    curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
    sudo yum install -y nodejs
  elif [ "$(uname)" == "Darwin" ]; then
    # macOS
    brew install node
  else
    echo "❌ Unsupported distribution for automatic Node.js installation. Please install Node.js and npm manually."
    exit 1
  fi
fi

# Check and install curl
if ! command -v curl &> /dev/null; then
  echo "⚠️ curl is not installed. Installing..."
  install_package curl
fi

echo "✅ Required tools found or installed"

# Create project directory
INSTALL_DIR="$(pwd)/ccported"
echo "Setting up CCPorted in: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Clone repository
echo "Cloning the CCPorted repository..."
if [ -d ".git" ]; then
  git pull
else
  git clone https://github.com/ccported/ccported.github.io.git .
fi

# Install dependencies
echo "Installing dependencies..."
npm install

# Install htmlc globally
echo "Installing htmlc compiler..."
npm install -g @sojs_coder/htmlc@1.3.5

# Create directory for games
mkdir -p games

# Clone emdata repository
echo "Setting up emulator data..."
if [ ! -d "emdata" ]; then
  echo "Cloning emdata repository..."
  git clone https://github.com/ccported/emdata.git emdata
  
  # Make sure /data is in the right place
  if [ -d "emdata/data" ]; then
    echo "✅ Emdata repository cloned successfully"
  else
    echo "⚠️ Emdata repository structure is different than expected. Checking branch..."
    cd emdata
    git checkout main
    if [ ! -d "data" ]; then
      echo "Creating data directory..."
      mkdir -p data
    fi
    cd ..
  fi
else
  echo "Updating emdata repository..."
  cd emdata
  git pull
  cd ..
fi

# Download games from S3 bucket
echo "Downloading games from S3 bucket..."
echo "This will use the AWS CLI with public access (no credentials needed)"

# Ask user if they want to download games
read -p "Do you want to download games from the S3 bucket? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  # Check for and install AWS CLI if needed
  if ! command -v aws &> /dev/null; then
    echo "⚠️ AWS CLI not installed. Installing..."
    
    if [ "$(uname)" == "Darwin" ]; then
      # macOS
      curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
      sudo installer -pkg AWSCLIV2.pkg -target /
      rm AWSCLIV2.pkg
    else
      # Linux
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
      unzip awscliv2.zip
      sudo ./aws/install
      rm -rf aws awscliv2.zip
    fi
  fi

  # Download roms from S3 with public access (no credentials needed)
  echo "Downloading ROMs from S3 bucket (this may take a while)..."
  aws s3 sync s3://ccportedroms games/ --no-sign-request --region us-west-2
  
  if [ $? -ne 0 ]; then
    echo "⚠️ There might have been issues with AWS CLI. Trying alternative download method..."
    
    # Create directories for game categories
    mkdir -p games/{gb,gba,nes,snes,n64,genesis}
    
    # Alternative download method using curl
    echo "Using direct download for sample games..."
    baseUrl="https://ccportedroms.s3.us-west-2.amazonaws.com"
    
    # Sample games to download
    curl -s "$baseUrl/gb/tetris.gb" -o "games/gb/tetris.gb" || echo "Could not download tetris.gb"
    curl -s "$baseUrl/gba/pokemon_emerald.gba" -o "games/gba/pokemon_emerald.gba" || echo "Could not download pokemon_emerald.gba"
    curl -s "$baseUrl/nes/super_mario_bros.nes" -o "games/nes/super_mario_bros.nes" || echo "Could not download super_mario_bros.nes"
  fi
  
  # Create dummy roms.json if it doesn't exist
  if [ ! -f "static/roms/roms.json" ]; then
    echo "Creating roms.json file..."
    mkdir -p static/roms
    
    # Create categories from directory structure
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
  fi
else
  echo "Skipping game downloads."
fi

# Build the site
echo "Building the site..."
htmlc static --out=build

# Configure the server
echo "Configuring server..."

# Use the self-hosted server.js version
echo "Setting up self-hosted server configuration..."
if [ -f "server.self-hosted.js" ]; then
  cp server.self-hosted.js server.js
else
  echo "Creating custom server configuration..."
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
fi

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
  cat > .env << EOL
PORT=3000
WEBSITE_URL="http://localhost:3000"
EOL
fi

# Install Bun if not available
if ! command -v bun &> /dev/null; then
  echo "Installing Bun runtime..."
  curl -fsSL https://bun.sh/install | bash
  
  # Update PATH
  export PATH=$HOME/.bun/bin:$PATH
  
  # If Bun failed to install, create a Node.js fallback
  if ! command -v bun &> /dev/null; then
    echo "❌ Bun installation failed. Creating Node.js fallback."
    
    # Create a Node.js fallback server
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
    
    # Install Express
    npm install express --save
    
    # Update package.json start script
    if [ -f "package.json" ]; then
      # Use jq if available
      if command -v jq &> /dev/null; then
        jq '.scripts.start = "node node-server.js"' package.json > package.json.tmp && mv package.json.tmp package.json
      else
        # Simple sed replacement (less reliable but works for simple cases)
        sed -i 's/"start": ".*"/"start": "node node-server.js"/g' package.json
      fi
    fi
  fi
fi

# Create a startup script
cat > start.sh << 'EOL'
#!/bin/bash
# Start CCPorted server
cd "$(dirname "$0")"

echo "Starting CCPorted server..."
echo "If you encounter any issues starting with Bun, try uncommenting the Node.js fallback below."

# Try bun first
if command -v bun &> /dev/null; then
  bun run server.js
else
  # Node.js fallback
  node node-server.js
fi
EOL
chmod +x start.sh

# Ask if user wants to set up a systemd service
if command -v systemctl &> /dev/null; then
  echo "Systemd detected. Would you like to install CCPorted as a service?"
  read -p "This will allow CCPorted to start automatically at boot (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Create systemd service file
    SERVICE_FILE="$INSTALL_DIR/ccported.service"
    cat > "$SERVICE_FILE" << EOL
[Unit]
Description=CCPorted Games Server
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$INSTALL_DIR
ExecStart=$(command -v npm) start
Restart=on-failure
Environment=PORT=3000
Environment=WEBSITE_URL=http://localhost:3000

[Install]
WantedBy=multi-user.target
EOL

    # Install service
    sudo cp "$SERVICE_FILE" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable ccported.service
    sudo systemctl start ccported.service
    
    echo "✅ Systemd service installed and started"
    echo "   To check service status: sudo systemctl status ccported"
    echo "   To stop the service: sudo systemctl stop ccported"
    echo "   To start the service: sudo systemctl start ccported"
  fi
fi

echo "====================================="
echo "✅ CCPorted setup complete!"
echo "====================================="
echo "To start the server manually, run: ./start.sh"
echo "Once started, visit: http://localhost:3000"
echo "====================================="

# CCPorted is down!

Check back august 2025.

<!-- # CCPorted - Unblocked games for all!!

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/T6T81D9XVW)

Visit [ccported.github.io](https://ccported.github.io)

## Self-Hosting Guide

CCPorted can be self-hosted on your own server. This guide will help you set up your own instance.

### Quick Start

#### Linux/macOS

To quickly set up CCPorted on a Linux/macOS server, use the following command:

```bash
wget -O setup-ccported.sh https://raw.githubusercontent.com/ccported/ccported.github.io/main/setup-ccported.sh && chmod +x setup-ccported.sh && ./setup-ccported.sh
```

#### Windows

For Windows systems, open PowerShell as administrator and run:

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/ccported/ccported.github.io/main/setup-ccported.ps1 -OutFile setup-ccported.ps1
.\setup-ccported.ps1
```

The setup will:
1. Install all required tools automatically
2. Clone the emdata repository from GitHub (https://github.com/ccported/emdata)
3. Download games from the S3 bucket (optional, no credentials needed)
4. Build the website content using htmlc
5. Set up a server to serve games at `/games/` and emulator data at `/emdata/`

For detailed deployment instructions, troubleshooting, and advanced configurations, see [DEPLOYMENT.md](DEPLOYMENT.md)

### Manual Setup

If you prefer a manual setup, follow these steps:

1. **Clone the repository**
   ```bash
   git clone https://github.com/ccported/ccported.github.io.git
   cd ccported.github.io
   ```

2. **Install dependencies**
   ```bash
   npm install
   npm install -g @sojs_coder/htmlc@1.3.5
   ```

3. **Set up emdata and game files**
   Clone the emdata repository and create games directory:
   ```bash
   git clone https://github.com/ccported/emdata.git emdata
   mkdir -p games/gb games/gba games/nes
   
   # Optional: Download games from public S3 bucket
   aws s3 sync s3://ccportedroms games/ --no-sign-request --region us-west-2
   ```

4. **Build the website**
   ```bash
   htmlc static --out=build
   ```

5. **Start the server**
   ```bash
   npm start
   ```

6. Visit `http://localhost:3000` in your browser

### Requirements

- Node.js and npm
- AWS CLI (if downloading games from S3)
- Git

### Directory Structure

- `/games/` - Contains game files organized by category
- `/build/` - Generated website files
- `/static/` - Static assets and templates
- `/emdata/` - Emulator data files (optional)

### Configuration

You can configure the server by editing the `.env` file:

```env
PORT=3000
WEBSITE_URL="http://localhost:3000"
```

### Advanced Setup Options

#### Running as a Systemd Service

To run CCPorted as a background service that starts automatically on boot:

1. **Create a systemd service file**
   ```bash
   sudo nano /etc/systemd/system/ccported.service
   ```

2. **Add the following content** (adjust paths and username as needed)
   ```
   [Unit]
   Description=CCPorted Games Server
   After=network.target

   [Service]
   Type=simple
   User=your_username
   WorkingDirectory=/path/to/ccported
   ExecStart=/usr/bin/npm start
   Restart=on-failure
   Environment=PORT=3000
   Environment=WEBSITE_URL=http://your-domain-or-ip:3000

   [Install]
   WantedBy=multi-user.target
   ```

3. **Enable and start the service**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable ccported.service
   sudo systemctl start ccported.service
   ```

#### Using Nginx as a Reverse Proxy

To serve CCPorted behind Nginx (useful for SSL/TLS, domain names, etc.):

1. **Install Nginx**
   ```bash
   sudo apt update
   sudo apt install nginx
   ```

2. **Create a site configuration**
   ```bash
   sudo nano /etc/nginx/sites-available/ccported
   ```
   
   Use the provided `nginx-ccported.conf` in the repository as a template.

3. **Enable the site**
   ```bash
   sudo ln -s /etc/nginx/sites-available/ccported /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl reload nginx
   ```

### Docker Setup

CCPorted can also be run using Docker:

1. **Using docker-compose (recommended)**
   ```bash
   # Clone the repository
   git clone https://github.com/ccported/ccported.github.io.git
   cd ccported.github.io
   
   # Start the container
   docker-compose up -d
   ```

2. **Manual Docker setup**
   ```bash
   # Build the Docker image
   docker build -t ccported .
   
   # Run the container
   docker run -d -p 3000:3000 -v $(pwd)/games:/app/games -v $(pwd)/emdata:/app/emdata ccported
   ```

Visit `http://localhost:3000` in your browser.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. -->

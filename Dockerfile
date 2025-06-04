FROM oven/bun:latest

# Install git, AWS CLI, and Node.js
RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# Install htmlc globally
RUN npm install -g @sojs_coder/htmlc@1.3.5

WORKDIR /app

# Copy entire app for building
COPY . .

# Install dependencies
RUN bun install

# Build the site
RUN htmlc static --out=build

# Create directories for mounted volumes
RUN mkdir -p games emdata

# Expose port
EXPOSE 3000

# Set the entrypoint
CMD ["bun", "run", "server.js"]
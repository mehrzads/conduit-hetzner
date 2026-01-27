# Conduit on Hetzner

A bash CLI tool to create and manage [Hetzner Cloud](https://www.hetzner.com/cloud) servers and deploy [Conduit](https://github.com/SamNet-dev/conduit-manager) on them.

## Prerequisites

- A [Hetzner Cloud](https://www.hetzner.com/cloud) account
- `curl` and `jq` installed on your machine
- An SSH key pair on your local machine (you probably already have one at `~/.ssh/id_rsa.pub`)

## Setup

### 1. Get a Hetzner API Token

1. Log in to the [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Select your project (or create a new one)
3. Go to **Security** > **API Tokens**
4. Click **Generate API Token**
5. Give it a name (e.g. `conduit-cli`) and select **Read & Write** permissions
6. Click **Generate API Token** and copy the token — you won't be able to see it again

### 2. Upload Your SSH Key to Hetzner

Adding your SSH key lets you log into servers without a password.

1. Copy your public key to your clipboard:
   ```bash
   # macOS
   cat ~/.ssh/id_rsa.pub | pbcopy

   # Linux
   cat ~/.ssh/id_rsa.pub | xclip -selection clipboard
   ```
   If you don't have an SSH key yet, generate one first:
   ```bash
   ssh-keygen -t rsa -b 4096
   ```
2. In the Hetzner Cloud Console, go to **Security** > **SSH Keys**
3. Click **Add SSH Key**
4. Paste your public key and give it a name (e.g. `my-laptop`)
5. Remember this name — you'll use it in the config below

### 3. Install Dependencies

Install `jq` if you don't have it:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq
```

### 4. Install

```bash
git clone https://github.com/SamNet-dev/conduit-hetzner.git
cd conduit-hetzner
chmod +x hetzner
```

### 5. Configure

Copy the example config and add your API token:

```bash
cp .env.example .env
```

Edit `.env` and set your values:

```bash
HETZNER_API_TOKEN='your-api-token-here'
SSH_KEY_NAME='my-laptop'
```

The token is required. Everything else has sensible defaults.

| Variable | Default | Description |
|----------|---------|-------------|
| `HETZNER_API_TOKEN` | *(required)* | Your Hetzner Cloud API token |
| `SSH_KEY_NAME` | *(none)* | Name of the SSH key you uploaded to Hetzner |
| `SERVER_TYPE` | `cpx11` | Server size ([see options](https://www.hetzner.com/cloud#pricing)) |
| `LOCATION` | `ash` | Datacenter location |
| `IMAGE` | `ubuntu-22.04` | OS image |

Available locations: `ash` (Ashburn, US), `hil` (Hillsboro, US), `nbg1` (Nuremberg, DE), `fsn1` (Falkenstein, DE), `hel1` (Helsinki, FI)

## Usage

```
./hetzner <command> [options]
```

### List all servers

```bash
./hetzner list
```

Shows a table of all your servers with their ID, name, IP, type, location, and status.

### Create a server

```bash
./hetzner create
```

Creates a new server using the settings from your `.env` file. Outputs the server ID and IP address once it's ready.

### Get server info

```bash
./hetzner info <server-id>
```

Shows detailed info about a server (CPU, memory, disk, datacenter, etc).

### SSH into a server

```bash
./hetzner ssh <server-id>
```

Opens an SSH connection to the server. No need to remember the IP — just use the server ID.

### Install Conduit on a server

```bash
./hetzner run <server-id>
```

Downloads and runs the Conduit installation script on the server.

### Check Conduit stats

```bash
./hetzner stats <server-id>
```

Shows a summary of Conduit performance on the server (connections, bandwidth, uptime).

### Generate a cluster report

```bash
./hetzner report
```

Fetches stats from all servers and prints a summary. Saves the report to a timestamped file.

### Delete a server

```bash
./hetzner delete <server-id>
```

Deletes a server after a confirmation prompt.

### Deploy a cluster

```bash
./deploy-cluster.sh
```

Creates 5 servers and installs Conduit on all of them automatically.

## Quick Example

```bash
# Create a server
./hetzner create
# Server created! ID: 12345, IP: 1.2.3.4

# Install Conduit on it
./hetzner run 12345

# Check stats
./hetzner stats 12345

# SSH in to inspect
./hetzner ssh 12345

# Done with it? Delete it
./hetzner delete 12345
```

## Troubleshooting

- **"HETZNER_API_TOKEN is not set"** — Make sure your `.env` file exists in the same directory and contains your token.
- **"SSH key not found"** — The `SSH_KEY_NAME` in `.env` must match the name you gave the key in the Hetzner console exactly.
- **"jq: command not found"** — Install jq (see [Install Dependencies](#3-install-dependencies)).
- **Can't SSH into server** — Wait a minute after creation for the server to finish booting. If you didn't set `SSH_KEY_NAME`, use the root password printed during creation.

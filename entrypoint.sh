#!/usr/bin/env bash
set -euo pipefail

# ─── Environment Variables with Defaults ────────────────────────────────────
: "${WALLET_NAME:=maincold}"      # cold wallet folder
: "${HOTKEY:=miner01}"            # miner identity
: "${BT_NETWORK:=finney}"         # main network
: "${NETUID:=27}"                 # Subnet-27
: "${MNEMONIC:=}"                 # 24-word coldkey seed – required on first run
: "${HOTKEY_MNEMONIC:=}"          # optional hotkey seed (usually leave blank)
: "${AXON_PORT:=8091}"
: "${SSH_PORT:=4444}"

WALLET_DIR="/root/.bittensor/wallets"
mkdir -p "$WALLET_DIR"

# ─── Activate Python environment ─────────────────────────────────────────────
echo "🔧 Activating Python environment..."
source /app/venv/bin/activate
cd /app

# ─── Debug: Check Python path and modules ───────────────────────────────────
echo "🔍 Checking Python environment..."
python -c "import sys; print('Python path:', sys.path)"
echo "📦 Installed packages:"
pip list | grep -E "(bittensor|nicompute|compute)" || echo "No matching packages found"

# ─── Coldkey setup ───────────────────────────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" >/dev/null 2>&1; then
    if [ -n "$MNEMONIC" ]; then
        echo "🔑 Restoring coldkey from mnemonic..."
        btcli wallet regen-coldkey \
             --wallet.name "$WALLET_NAME" \
             --wallet.path "$WALLET_DIR" \
             --mnemonic "$MNEMONIC" \
             --no-use-password
    else
        echo "❌ No coldkey found and no MNEMONIC provided."
        echo "   Please set MNEMONIC environment variable."
        exit 1
    fi
else
    echo "✅ Coldkey '$WALLET_NAME' found"
fi

# ─── Hotkey setup ────────────────────────────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" --wallet.hotkey "$HOTKEY" >/dev/null 2>&1; then
    if [ -n "$HOTKEY_MNEMONIC" ]; then
        echo "🔑 Restoring hotkey from mnemonic..."
        btcli wallet regen-hotkey \
             --wallet.name "$WALLET_NAME" \
             --wallet.hotkey "$HOTKEY" \
             --wallet.path "$WALLET_DIR" \
             --mnemonic "$HOTKEY_MNEMONIC" \
             --no-use-password
    else
        echo "🆕 Creating new hotkey..."
        btcli wallet new-hotkey \
             --wallet.name "$WALLET_NAME" \
             --wallet.hotkey "$HOTKEY" \
             --wallet.path "$WALLET_DIR" \
             --n_words 12 \
             --no-use-password
    fi
else
    echo "✅ Hotkey '$HOTKEY' found"
fi

# ─── Registration check ──────────────────────────────────────────────────────
echo "🌐 Checking subnet registration..."
if ! btcli subnets list --subtensor.network "$BT_NETWORK" | grep -q "hotkey.*$HOTKEY.*netuid.*$NETUID"; then
    echo "📝 Attempting to register on subnet $NETUID..."
    btcli subnets register \
         --subtensor.network "$BT_NETWORK" \
         --netuid "$NETUID" \
         --wallet.name "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --no_prompt || {
        echo "⚠️  Registration failed. Continuing anyway - you may need to register manually."
    }
else
    echo "✅ Already registered on subnet $NETUID"
fi

# ─── Launch miner ────────────────────────────────────────────────────────────
echo "🚀 Starting NI Compute miner..."
echo "   Network: $BT_NETWORK"
echo "   Netuid: $NETUID" 
echo "   Wallet: $WALLET_NAME"
echo "   Hotkey: $HOTKEY"

# Check if neurons/miner.py exists
if [ -f "neurons/miner.py" ]; then
    echo "📂 Found neurons/miner.py"
    exec python neurons/miner.py \
         --netuid "$NETUID" \
         --wallet.name "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --subtensor.network "$BT_NETWORK" \
         --axon.port "$AXON_PORT" \
         --ssh.port "$SSH_PORT" \
         --logging.debug
else
    echo "❌ neurons/miner.py not found!"
    echo "📁 Current directory contents:"
    ls -la
    echo "📁 Looking for Python files:"
    find . -name "*.py" -path "*/miner*" -o -name "miner.py" 2>/dev/null || echo "No miner files found"
    exit 1
fi

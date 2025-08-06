#!/usr/bin/env bash
set -euo pipefail

# ─── Environment Variables with Defaults ────────────────────────────────────
: "${WALLET_NAME:=default}"
: "${HOTKEY:=default}"
: "${BT_NETWORK:=finney}"
: "${NETUID:=27}"
: "${MNEMONIC:=}"
: "${HOTKEY_MNEMONIC:=}"
: "${AXON_PORT:=8091}"
: "${SSH_PORT:=4444}"
: "${WANDB_API_KEY:=}"
: "${AUTO_REGISTER:=true}"
: "${LOG_LEVEL:=INFO}"

# ─── Setup ───────────────────────────────────────────────────────────────────
WALLET_DIR="/root/.bittensor/wallets"
mkdir -p "$WALLET_DIR"

echo "🔧 Activating Python environment..."
source /app/venv/bin/activate
cd /app

# ─── WandB Setup (Optional) ──────────────────────────────────────────────────
if [ -n "$WANDB_API_KEY" ]; then
    echo "🔑 Setting up WandB..."
    pip install wandb --quiet
    wandb login "$WANDB_API_KEY"
fi

# ─── Wallet Management ───────────────────────────────────────────────────────
echo "👛 Checking wallet configuration..."

# Check if coldkey exists
if ! btcli wallet info --wallet.name "$WALLET_NAME" >/dev/null 2>&1; then
    if [ -n "$MNEMONIC" ]; then
        echo "🔑 Restoring coldkey from mnemonic..."
        echo "$MNEMONIC" | btcli wallet regen-coldkey \
             --wallet.name "$WALLET_NAME" \
             --wallet.path "$WALLET_DIR" \
             --no-use-password \
             --stdin
    else
        echo "❌ No coldkey found and no MNEMONIC provided."
        echo "   Please provide MNEMONIC environment variable or create wallet manually."
        exit 1
    fi
else
    echo "✅ Coldkey '$WALLET_NAME' found"
fi

# Check if hotkey exists
if ! btcli wallet info --wallet.name "$WALLET_NAME" --wallet.hotkey "$HOTKEY" >/dev/null 2>&1; then
    if [ -n "$HOTKEY_MNEMONIC" ]; then
        echo "🔑 Restoring hotkey from mnemonic..."
        echo "$HOTKEY_MNEMONIC" | btcli wallet regen-hotkey \
             --wallet.name "$WALLET_NAME" \
             --wallet.hotkey "$HOTKEY" \
             --wallet.path "$WALLET_DIR" \
             --no-use-password \
             --stdin
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

# ─── Registration Check ──────────────────────────────────────────────────────
echo "🌐 Checking subnet registration..."

if [ "$AUTO_REGISTER" = "true" ]; then
    # Check if already registered
    if ! btcli subnets list --subtensor.network "$BT_NETWORK" | grep -q "hotkey.*$HOTKEY.*netuid.*$NETUID"; then
        echo "📝 Attempting to register on subnet $NETUID..."
        btcli subnets register \
             --subtensor.network "$BT_NETWORK" \
             --netuid "$NETUID" \
             --wallet.name "$WALLET_NAME" \
             --wallet.hotkey "$HOTKEY" \
             --no_prompt || {
            echo "⚠️  Registration failed. Please ensure your wallet has sufficient TAO."
            echo "   You can register manually: btcli subnets register --netuid $NETUID"
        }
    else
        echo "✅ Already registered on subnet $NETUID"
    fi
fi

# ─── Display Wallet Info ─────────────────────────────────────────────────────
echo "📊 Wallet Information:"
btcli wallet info --wallet.name "$WALLET_NAME" --wallet.hotkey "$HOTKEY" || true

# ─── Launch Miner ────────────────────────────────────────────────────────────
echo "🚀 Starting NI Compute miner..."
echo "   Network: $BT_NETWORK"
echo "   Netuid: $NETUID"
echo "   Wallet: $WALLET_NAME"
echo "   Hotkey: $HOTKEY"
echo "   Axon Port: $AXON_PORT"
echo "   SSH Port: $SSH_PORT"

exec python neurons/miner.py \
     --netuid "$NETUID" \
     --wallet.name "$WALLET_NAME" \
     --wallet.hotkey "$HOTKEY" \
     --subtensor.network "$BT_NETWORK" \
     --axon.port "$AXON_PORT" \
     --ssh.port "$SSH_PORT" \
     --logging."${LOG_LEVEL,,}"

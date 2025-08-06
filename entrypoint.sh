#!/usr/bin/env bash
set -euo pipefail

# ─── 1 · ENV defaults ───────────────────────────────────────────────────────
: "${WALLET_NAME:=default}"       # cold wallet folder (changed from maincold to default)
: "${HOTKEY:=default}"            # miner identity (changed from miner01 to default)
: "${BT_NETWORK:=finney}"         # main network
: "${NETUID:=27}"                 # Subnet-27
: "${MNEMONIC:=}"                 # 24-word coldkey seed – required on first run
: "${HOTKEY_MNEMONIC:=}"          # optional hotkey seed (usually leave blank)
: "${AXON_PORT:=8091}"            # axon port
: "${SSH_PORT:=4444}"             # ssh port for allocations

WALLET_DIR="${HOME}/.bittensor/wallets"
mkdir -p "$WALLET_DIR"            # avoid wallet path prompt

# ─── 2 · Activate venv & cd ─────────────────────────────────────────────────
source /miner/venv/bin/activate
cd /miner

# ─── 3 · Coldkey restore / create ───────────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" >/dev/null 2>&1; then
  if [ -n "$MNEMONIC" ]; then
    echo "Restoring coldkey from mnemonic..."
    echo "$MNEMONIC" | btcli wallet regen-coldkey \
         --wallet.name  "$WALLET_NAME" \
         --wallet.path  "$WALLET_DIR" \
         --no-use-password \
         --stdin
  else
    echo "Creating new coldkey..."
    btcli wallet new-coldkey \
         --wallet.name  "$WALLET_NAME" \
         --wallet.path  "$WALLET_DIR" \
         --no-use-password
  fi
fi

# ─── 4 · Hotkey ensure ──────────────────────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" >/dev/null 2>&1; then
  if [ -n "$HOTKEY_MNEMONIC" ]; then
    echo "Restoring hotkey from mnemonic..."
    echo "$HOTKEY_MNEMONIC" | btcli wallet regen-hotkey \
         --wallet.name   "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --wallet.path   "$WALLET_DIR" \
         --no-use-password \
         --stdin
  else
    echo "Creating new hotkey..."
    btcli wallet new-hotkey \
         --wallet.name   "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --wallet.path   "$WALLET_DIR" \
         --n_words       12 \
         --no-use-password
  fi
fi

# ─── 5 · Register if not yet on subnet ──────────────────────────────────────
echo "Checking registration status..."
if ! btcli subnets list --subtensor.network "$BT_NETWORK" | grep -q "hotkey.*$HOTKEY.*netuid *$NETUID"; then
  echo "Registering on subnet $NETUID..."
  btcli subnets register \
       --subtensor.network "$BT_NETWORK" \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --no_prompt
fi

# ─── 6 · Launch miner ──────────────────────────────────────────────────────
echo "Starting miner..."
exec python neurons/miner.py \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --subtensor.network "$BT_NETWORK" \
       --axon.port         "$AXON_PORT" \
       --ssh.port          "$SSH_PORT" \
       --logging.debug

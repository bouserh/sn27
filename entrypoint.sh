#!/usr/bin/env bash
set -euo pipefail

# ─── 1 · ENV defaults ───────────────────────────────────────────────────────
: "${WALLET_NAME:=maincold}"      # cold wallet folder name
: "${HOTKEY:=miner01}"            # miner identity
: "${BT_NETWORK:=finney}"         # main network
: "${NETUID:=27}"                 # Subnet-27
: "${MNEMONIC:=}"                 # 24-word coldkey seed (required first run)
: "${HOTKEY_MNEMONIC:=}"          # optional hotkey seed (usually leave blank)

WALLET_DIR="${HOME}/.bittensor/wallets"
mkdir -p "$WALLET_DIR"            # avoids directory prompt

# activate venv
source /miner/venv/bin/activate
cd /miner/neurons

# ─── 2 · Coldkey restore / create ───────────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" >/dev/null 2>&1; then
  if [ -z "$MNEMONIC" ]; then
    echo "[FATAL] MNEMONIC env var is required on first boot." >&2
    exit 1
  fi
  btcli wallet regen-coldkey \
       --wallet.name  "$WALLET_NAME" \
       --wallet.path  "$WALLET_DIR" \
       --mnemonic     "$MNEMONIC" \
       --no-use-password
fi

# ─── 3 · Hotkey ensure ──────────────────────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" >/dev/null 2>&1; then
  if [ -n "$HOTKEY_MNEMONIC" ]; then
    btcli wallet regen-hotkey \
         --wallet.name   "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --wallet.path   "$WALLET_DIR" \
         --mnemonic      "$HOTKEY_MNEMONIC" \
         --no-use-password
  else
    btcli wallet new-hotkey \
         --wallet.name   "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --wallet.path   "$WALLET_DIR" \
         --no-use-password
  fi
fi

# ─── 4 · Register if not yet registered ─────────────────────────────────────
if ! btcli subnets list --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" | grep -q "netuid *$NETUID"; then
  btcli subnets register \
       --subtensor.network "$BT_NETWORK" \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --no_prompt
fi

# ─── 5 · Launch miner ───────────────────────────────────────────────────────
exec python neurons/miner.py \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --subtensor.network "$BT_NETWORK" \
       --axon.port         8091 \
       --logging.debug

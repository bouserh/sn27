#!/usr/bin/env bash
set -euo pipefail

# ─── 1 · ENV defaults ───────────────────────────────────────────────────────
: "${WALLET_NAME:=maincold}"      # cold wallet folder
: "${HOTKEY:=miner01}"            # miner identity
: "${BT_NETWORK:=finney}"         # main network
: "${NETUID:=27}"                 # Subnet-27
: "${MNEMONIC:=}"                 # 24-word coldkey seed  (required 1st run)
: "${HOTKEY_MNEMONIC:=}"          # optional hotkey seed

WALLET_DIR="${HOME}/.bittensor/wallets"
mkdir -p "$WALLET_DIR"            # avoid directory prompt

# ─── 2 · Activate venv & cd ─────────────────────────────────────────────────
source /miner/venv/bin/activate
cd /miner/neurons

# ─── 3 · Coldkey restore / create ───────────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" >/dev/null 2>&1; then
  [ -z "$MNEMONIC" ] && { echo "[FATAL] MNEMONIC env var missing"; exit 1; }
  btcli wallet regen-coldkey \
       --wallet.name  "$WALLET_NAME" \
       --wallet.path  "$WALLET_DIR" \
       --mnemonic     "$MNEMONIC" \
       --no-use-password
fi

# ─── 4 · Hotkey ensure ──────────────────────────────────────────────────────
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
         --n_words       12 \
         --no-use-password
  fi
fi

# ─── 5 · Auto-register if not yet on subnet ────────────────────────────────
if ! btcli subnets list --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" | grep -q "netuid *$NETUID"; then
  btcli subnets register \
       --subtensor.network "$BT_NETWORK" \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --no_prompt
fi

# ─── 6 · Launch miner ──────────────────────────────────────────────────────
exec python neurons/miner.py \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --subtensor.network "$BT_NETWORK" \
       --axon.port         8091 \
       --logging.debug

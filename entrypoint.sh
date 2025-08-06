#!/usr/bin/env bash
set -euo pipefail

# ─── 1 · ENV defaults ───────────────────────────────────────────────────────
: "${WALLET_NAME:=maincold}"
: "${HOTKEY:=miner01}"
: "${BT_NETWORK:=finney}"          # main network
: "${NETUID:=27}"                  # Subnet-27
: "${MNEMONIC:=}"                  # coldkey seed (24 words)  – required on first run
: "${HOTKEY_MNEMONIC:=}"           # optional hotkey seed

# ─── 2 · Activate venv & cd ─────────────────────────────────────────────────
source /miner/venv/bin/activate
cd /miner/neurons

# ─── 3 · Restore (or create) the coldkey ───────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" >/dev/null 2>&1; then
  if [ -z "$MNEMONIC" ]; then
    echo "[FATAL] MNEMONIC env var is required on first boot." >&2
    exit 1
  fi
  btcli wallet regen-coldkey \
       --wallet.name "$WALLET_NAME" \
       --mnemonic "$MNEMONIC" \
       --no-use-password
fi

# ─── 4 · Ensure the hotkey exists ──────────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" >/dev/null 2>&1; then
  if [ -n "$HOTKEY_MNEMONIC" ]; then
    btcli wallet regen-hotkey \
         --wallet.name "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --mnemonic "$HOTKEY_MNEMONIC" \
         --no-use-password
  else
    btcli wallet new-hotkey \
         --wallet.name "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --no_password
  fi
fi

# ─── 5 · Auto-register if not on subnet ────────────────────────────────────
if ! btcli subnets list --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" | grep -q "netuid *$NETUID"; then
  btcli subnets register \
       --subtensor.network "$BT_NETWORK" \
       --netuid "$NETUID" \
       --wallet.name "$WALLET_NAME" \
       --wallet.hotkey "$HOTKEY" \
       --no_prompt
fi

# ─── 6 · Launch miner ──────────────────────────────────────────────────────
exec python neurons/miner.py \
       --netuid "$NETUID" \
       --wallet.name "$WALLET_NAME" \
       --wallet.hotkey "$HOTKEY" \
       --subtensor.network "$BT_NETWORK" \
       --axon.port 8091 \
       --logging.debug

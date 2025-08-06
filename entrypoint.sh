#!/usr/bin/env bash
set -euo pipefail

# ─── 1 · ENV defaults ───────────────────────────────────────────────────────
: "${WALLET_NAME:=maincold}"      # cold wallet folder
: "${HOTKEY:=miner01}"            # miner identity
: "${BT_NETWORK:=finney}"         # main network
: "${NETUID:=27}"                 # Subnet-27
: "${MNEMONIC:=}"                 # coldkey seed (24 words) – required 1st run

# ─── 2 · Optional hotkey seed (rare) ────────────────────────────────────────
: "${HOTKEY_MNEMONIC:=}"          # leave empty to auto-generate hotkey

# ─── 3 · Activate venv & cd ─────────────────────────────────────────────────
source /miner/venv/bin/activate
cd /miner/neurons

# ─── 4 · Restore or create the coldkey ──────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" >/dev/null 2>&1; then
  if [ -z "$MNEMONIC" ]; then
    echo "[FATAL] MNEMONIC env var is required on first boot." >&2
    exit 1
  fi
  btcli wallet regen-coldkey \
       --wallet.name  "$WALLET_NAME" \
       --mnemonic     "$MNEMONIC" \
       --no-use-password \
       --no-prompt
fi

# ─── 5 · Ensure the hotkey exists ───────────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" >/dev/null 2>&1; then
  if [ -n "$HOTKEY_MNEMONIC" ]; then
    btcli wallet regen-hotkey \
         --wallet.name   "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --mnemonic      "$HOTKEY_MNEMONIC" \
         --no-use-password \
         --no-prompt
  else
    btcli wallet new-hotkey \
         --wallet.name   "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --no_password \
         --no_prompt
  fi
fi

# ─── 6 · Auto-register if not yet on subnet ────────────────────────────────
if ! btcli subnets list --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" | grep -q "netuid *$NETUID"; then
  btcli subnets register \
       --subtensor.network "$BT_NETWORK" \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --no_prompt
fi

# ─── 7 · Launch the miner ──────────────────────────────────────────────────
exec python neurons/miner.py \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --subtensor.network "$BT_NETWORK" \
       --axon.port         8091 \
       --logging.debug

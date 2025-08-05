#!/usr/bin/env bash
set -euo pipefail

# ── 1 · ENV defaults ────────────────────────────────────────────────────────
: "${WALLET_NAME:=maincold}"
: "${HOTKEY:=miner01}"
: "${BT_NETWORK:=finney}"      # main network
: "${NETUID:=27}"
: "${MNEMONIC:=}"              # coldkey seed (24 words)
: "${HOTKEY_MNEMONIC:=}"       # optional separate hotkey seed for the hotkey

# ── 2 · Activate venv & cd ─────────────────────────────────────────────────
source /miner/venv/bin/activate
cd /miner/neurons

# ── 3 · Coldkey bootstrap ──────────────────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" >/dev/null 2>&1; then
  if [ -z "$MNEMONIC" ]; then
     echo "[ERR] Seed phrase required (MNEMONIC env) on first run" >&2
     exit 1
  fi
  echo "$MNEMONIC" | btcli wallet import-coldkey \
       --wallet.name "$WALLET_NAME" --no_prompt --seed_type raw
fi

# ── 4 · Hotkey bootstrap ──────────────────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" >/dev/null 2>&1; then
  if [ -n "$HOTKEY_MNEMONIC" ]; then
     echo "$HOTKEY_MNEMONIC" | btcli wallet import-hotkey \
          --wallet.name "$WALLET_NAME" --wallet.hotkey "$HOTKEY" \
          --no_prompt --seed_type raw
  else
     btcli wallet new_hotkey \
          --wallet.name "$WALLET_NAME" --wallet.hotkey "$HOTKEY" --no_prompt
  fi
fi

# ── 5 · Auto-register if not yet on subnet ────────────────────────────────
if ! btcli subnets list --wallet.name "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" | grep -q "netuid *$NETUID"; then
  btcli subnets register \
       --subtensor.network "$BT_NETWORK" \
       --netuid "$NETUID" \
       --wallet.name "$WALLET_NAME" \
       --wallet.hotkey "$HOTKEY" \
       --no_prompt
fi

# ── 6 · Launch miner ──────────────────────────────────────────────────────
exec python neurons/miner.py \
       --netuid "$NETUID" \
       --wallet.name "$WALLET_NAME" \
       --wallet.hotkey "$HOTKEY" \
       --subtensor.network "$BT_NETWORK" \
       --axon.port 8091 \
       --logging.debug

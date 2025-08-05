#!/usr/bin/env bash
set -euo pipefail

# ---------- 1 · Environment defaults ----------------------------------
: "${WALLET_NAME:=maincold}"
: "${HOTKEY:=miner01}"
: "${BT_NETWORK:=finney}"          # main net
: "${NETUID:=27}"
: "${MNEMONIC:=}"                  # 24-word coldkey seed (pass as secret)
: "${HOTKEY_MNEMONIC:=}"           # optional separate hotkey seed

# ---------- 2 · Activate venv  ---------------------------------------
source /miner/venv/bin/activate
export PATH="/miner/venv/bin:$PATH"   # so btcli is on PATH
cd /miner/neurons

# ---------- 3 · Wallet bootstrap -------------------------------------
if ! btcli wallet info --wallet.name "$WALLET_NAME" >/dev/null 2>&1; then
  if [ -z "$MNEMONIC" ]; then
     echo "❌  Coldkey mnemonic (MNEMONIC env) required on first run"; exit 1
  fi
  echo "$MNEMONIC" | btcli wallet import \
      --wallet.name "$WALLET_NAME" --no_prompt --seed_type raw
fi

if ! btcli wallet info --wallet.name "$WALLET_NAME" \
       --wallet.hotkey "$HOTKEY" >/dev/null 2>&1; then
  if [ -n "$HOTKEY_MNEMONIC" ]; then
     echo "$HOTKEY_MNEMONIC" | btcli wallet import_hotkey \
        --wallet.name "$WALLET_NAME" --wallet.hotkey "$HOTKEY" \
        --no_prompt --seed_type raw
  else
     btcli wallet new_hotkey \
        --wallet.name "$WALLET_NAME" --wallet.hotkey "$HOTKEY" --no_prompt
  fi
fi

# ---------- 4 · Auto-register if needed -------------------------------
if ! btcli subnets list --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" | grep -q "netuid *$NETUID"; then
  btcli subnets register \
      --subtensor.network "$BT_NETWORK" \
      --netuid "$NETUID" \
      --wallet.name "$WALLET_NAME" \
      --wallet.hotkey "$HOTKEY" \
      --no_prompt
fi

# ---------- 5 · Start miner ------------------------------------------
exec python neurons/miner.py \
      --netuid "$NETUID" \
      --wallet.name "$WALLET_NAME" \
      --wallet.hotkey "$HOTKEY" \
      --subtensor.network "$BT_NETWORK" \
      --axon.port 8091 \
      --logging.debug

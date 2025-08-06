#!/usr/bin/env bash
set -euo pipefail

: "${WALLET_NAME:=maincold}"
: "${HOTKEY:=miner01}"
: "${BT_NETWORK:=finney}"
: "${NETUID:=27}"
: "${MNEMONIC:=}"                 # required on first boot
: "${HOTKEY_MNEMONIC:=}"          # optional

WALLET_PATH="${HOME}/.bittensor/wallets"

source /miner/venv/bin/activate
cd /miner/neurons

# --- coldkey ----------------------------------------------------------
if ! btcli wallet info --wallet.name "$WALLET_NAME" >/dev/null 2>&1; then
  [ -z "$MNEMONIC" ] && { echo "[FATAL] MNEMONIC env var missing"; exit 1; }
  btcli wallet regen-coldkey \
       --wallet.name "$WALLET_NAME" \
       --mnemonic    "$MNEMONIC" \
       --no-use-password
fi

# --- hotkey -----------------------------------------------------------
if ! btcli wallet info --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" >/dev/null 2>&1; then
  if [ -n "$HOTKEY_MNEMONIC" ]; then
    btcli wallet regen-hotkey \
         --wallet.name   "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --mnemonic      "$HOTKEY_MNEMONIC" \
         --no-use-password
  else
    btcli wallet new-hotkey \
         --wallet.name   "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --no_password
  fi
fi

# --- register ---------------------------------------------------------
if ! btcli subnets list --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" | grep -q "netuid *$NETUID"; then
  btcli subnets register \
       --subtensor.network "$BT_NETWORK" \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --no_prompt
fi

# --- miner ------------------------------------------------------------
exec python neurons/miner.py \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --subtensor.network "$BT_NETWORK" \
       --axon.port         8091 \
       --logging.debug

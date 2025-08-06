#!/usr/bin/env bash
set -euo pipefail

: "${WALLET_NAME:=maincold}"
: "${HOTKEY:=miner01}"
: "${BT_NETWORK:=finney}"
: "${NETUID:=27}"
: "${MNEMONIC:=}"                # 24-word seed
: "${HOTKEY_MNEMONIC:=}"         # optional

# absolute wallet directory — same for all commands
WALLET_DIR="${HOME}/.bittensor/wallets"

# 1 ─ make sure the directory exists (avoids the prompt)
mkdir -p "$WALLET_DIR"

source /miner/venv/bin/activate
cd /miner/neurons

# 2 ─ coldkey restore (no prompt)
if ! btcli wallet info --wallet.name "$WALLET_NAME" >/dev/null 2>&1; then
  [ -z "$MNEMONIC" ] && { echo "[FATAL] MNEMONIC missing"; exit 1; }
  btcli wallet regen-coldkey \
       --wallet.name  "$WALLET_NAME" \
       --wallet.path  "$WALLET_DIR" \
       --mnemonic     "$MNEMONIC" \
       --no-use-password
fi

# 3 ─ hotkey ensure
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
         --no_password
  fi
fi

# 4 ─ register (no prompt)
if ! btcli subnets list --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" | grep -q "netuid *$NETUID"; then
  btcli subnets register \
       --subtensor.network "$BT_NETWORK" \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --no_prompt
fi

# 5 ─ start miner
exec python neurons/miner.py \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --subtensor.network "$BT_NETWORK" \
       --axon.port         8091 \
       --logging.debug

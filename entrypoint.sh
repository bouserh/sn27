#!/usr/bin/env bash
set -euo pipefail

# ─── 1 · ENV defaults ────────────────────────────────────────────────────────
: "${WALLET_NAME:=maincold}"        # cold wallet folder name
: "${HOTKEY:=miner01}"              # miner identity
: "${BT_NETWORK:=finney}"           # main network
: "${NETUID:=27}"                   # Subnet-27
: "${MNEMONIC:=}"                   # 24-word coldkey seed (required 1st run)
: "${HOTKEY_MNEMONIC:=}"            # optional hotkey seed

WALLET_PATH="${HOME}/.bittensor/wallets"

# ─── 2 · Activate venv & cd ──────────────────────────────────────────────────
source /miner/venv/bin/activate
cd /miner/neurons

# ─── 3 · Restore (or create) the coldkey ─────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" >/dev/null 2>&1; then
  if [ -z "$MNEMONIC" ]; then
    echo "[FATAL] MNEMONIC env var is required on first boot." >&2
    exit 1
  fi
  btcli wallet regen-coldkey \
       --wallet.name  "$WALLET_NAME" \
       --wallet.path  "$WALLET_PATH" \
       --mnemonic     "$MNEMONIC" \
       --no-use-password \
       --no_prompt
fi

# ─── 4 · Ensure the hotkey exists ────────────────────────────────────────────
if ! btcli wallet info --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" >/dev/null 2>&1; then
  if [ -n "$HOTKEY_MNEMONIC" ]; then
    btcli wallet regen-hotkey \
         --wallet.name   "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --wallet.path   "$WALLET_PATH" \
         --mnemonic      "$HOTKEY_MNEMONIC" \
         --no-use-password \
         --no_prompt
  else
    btcli wallet new-hotkey \
         --wallet.name   "$WALLET_NAME" \
         --wallet.hotkey "$HOTKEY" \
         --wallet.path   "$WALLET_PATH" \
         --no_password \
         --no_prompt
  fi
fi

# ─── 5 · Auto-register if not yet registered ────────────────────────────────
if ! btcli subnets list --wallet.name "$WALLET_NAME" \
        --wallet.hotkey "$HOTKEY" | grep -q "netuid *$NETUID"; then
  btcli subnets register \
       --subtensor.network "$BT_NETWORK" \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --no_prompt
fi

# ─── 6 · Launch miner ───────────────────────────────────────────────────────
exec python neurons/miner.py \
       --netuid            "$NETUID" \
       --wallet.name       "$WALLET_NAME" \
       --wallet.hotkey     "$HOTKEY" \
       --subtensor.network "$BT_NETWORK" \
       --axon.port         8091 \
       --logging.debug

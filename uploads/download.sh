#!/usr/bin/env bash
set -euo pipefail

# Put all your HF tokens here (space separated)
TOKENS=(

)

CMD_BASE=(huggingface-cli download Sylvest/libero_plus_lerobot --repo-type dataset --local-dir /coc/testnvme/xzhang3205/dexbotic/data/libero_plus_lerobot)

# cooldown time for rate-limited tokens (in seconds)
COOLDOWN=300  # 5 minutes

declare -A COOLDOWN_UNTIL=()

while true; do
  now=$(date +%s)
  usable_tokens=()

  # collect all tokens whose cooldown expired
  for TOKEN in "${TOKENS[@]}"; do
    expire_at=${COOLDOWN_UNTIL[$TOKEN]:-0}
    if (( now >= expire_at )); then
      usable_tokens+=("$TOKEN")
    fi
  done

  if ((${#usable_tokens[@]} == 0)); then
    echo "⏳ All tokens cooling down. Waiting 30s..."
    sleep 30
    continue
  fi

  TOKEN=${usable_tokens[$((RANDOM % ${#usable_tokens[@]}))]}
  echo "Trying token: ${TOKEN:0:12}..."

  export HF_TOKEN="$TOKEN"
  export HUGGINGFACE_HUB_TOKEN="$TOKEN"

  OUTPUT=$("${CMD_BASE[@]}" 2>&1) && CODE=0 || CODE=$?

  if [[ $CODE -eq 0 ]]; then
    echo "✅ Download succeeded with token ${TOKEN:0:12}"
    exit 0
  fi

  if echo "$OUTPUT" | grep -q "429" || echo "$OUTPUT" | grep -qi "Too Many Requests"; then
    echo "⚠️  Token ${TOKEN:0:12} hit rate limit. Cooling down for ${COOLDOWN}s."
    COOLDOWN_UNTIL[$TOKEN]=$(( now + COOLDOWN ))
    sleep 5
    continue
  else
    echo "❌ Unexpected error with token ${TOKEN:0:12}:"
    echo "$OUTPUT"
    # Don’t exit—just move on to next token
    COOLDOWN_UNTIL[$TOKEN]=$(( now + 60 ))
    continue
  fi
done

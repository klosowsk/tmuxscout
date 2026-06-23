#!/usr/bin/env bash
# Realistic mock agent session for the tmuxscout demo. Prints a believable
# AI-coding-agent conversation (Claude Code / pi / Codex / OpenCode style), then
# idles so the popup preview — and the window behind it — show real-looking chat.
kind="${1:-claude}"

case "$kind" in
  claude) cat <<'EOF'
> Refactor the auth middleware to use the new token-validation helper.

  Got it. I'll point requireAuth() at verifyToken() and check the call
  sites so nothing breaks.

● Read(src/auth.js)        ⎿  24 lines
● Read(src/session.js)     ⎿  41 lines
● Update(src/auth.js)      ⎿  +6 -3
● Bash(npm test -- auth)   ⎿  12 passed

  The middleware is done. One catch: this changes how the session store is
  keyed, so everyone currently signed in would get logged out.

  Want me to add a migration so existing sessions keep working?
  ❯ 1. Yes, migrate   2. No, that's fine     (waiting for you)
EOF
  ;;
  opencode) cat <<'EOF'
> Add end-to-end coverage for the checkout flow.

  Sure — I'll cover cart → checkout → confirmation, including the coupon path.

▸ write  e2e/checkout.spec.ts   (+128)
▸ run    npx playwright test e2e/checkout.spec.ts
   ✓ adds item to cart          ✓ applies coupon code
   ✓ completes payment          ✓ shows confirmation page
   14 passed in 8.2s

  All green — 14 specs across the whole flow. Want me to wire them into CI
  so they run on every PR?
EOF
  ;;
  codex) cat <<'EOF'
> Make the billing client resilient to flaky payment APIs.

  I'll add retry with exponential backoff, and turn 402s into a typed error
  so callers can handle "payment required" cleanly.

  edit  src/billing.js          (+22 -4)
  exec  npm run test:billing
     ✓ retries on 5xx with backoff
     ✓ surfaces 402 as PaymentRequiredError
     3 passed

  Done — retries are in and the 402 path is covered. Ready for your review.
EOF
  ;;
  pi) cat <<'EOF'
> Backfill the daily aggregates for the last 30 days.

  I can do that — but heads up, the backfill truncates and rewrites
  warehouse.daily_agg, so I want to confirm before touching staging.

●  read  README.md, pipeline.py
●  plan  recompute 30 days → warehouse.daily_agg  (staging)

  This step is destructive. Should I run it on staging now?
  ❯ yes / no       (awaiting your confirmation)
EOF
  ;;
esac

# idle so the conversation stays on screen for the preview / background
exec sleep 100000

#!/usr/bin/env bash
# Generates WorkoutTracker/Services/Secrets.swift from the values in .env at the repo
# root. Re-run this whenever .env changes (or after a fresh clone). The generated
# Secrets.swift is gitignored — it's checked into the Xcode project but never committed.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
    echo "error: .env not found at $(pwd)/.env" >&2
    exit 1
fi

KEY=$(grep -E '^GEMINI_API_KEY=' .env | head -1 | cut -d'=' -f2- | tr -d '"' | tr -d "'")

if [ -z "$KEY" ]; then
    echo "error: GEMINI_API_KEY missing or empty in .env" >&2
    exit 1
fi

cat > WorkoutTracker/Services/Secrets.swift <<EOF
import Foundation

/// Build-time secrets. This file is **gitignored** — regenerate it from \`.env\` if you
/// re-clone the repo by running \`scripts/gen-secrets.sh\` (or by editing this file by
/// hand). Never commit real keys.
///
/// At runtime, \`GeminiClient\` prefers a user-provided override stored in \`UserDefaults\`
/// (set from the Settings tab). If that override is empty, it falls back to the value
/// here.
enum Secrets {
    static let geminiAPIKey = "$KEY"
}
EOF

echo "wrote WorkoutTracker/Services/Secrets.swift"

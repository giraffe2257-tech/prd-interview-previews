#!/usr/bin/env bash
# Deploy the interview preview site to GitHub Pages.
# Run this from the site/ directory (or anywhere — it cd's correctly).
#
#   ! bash deploy.sh
#
# What this does:
#   1. Reads the GitHub PAT from your macOS keychain
#   2. Creates the public repo "prd-interview-previews" on github.com/giraffe2257-tech
#   3. Initialises a git repo here, commits all files, pushes to main
#   4. Enables GitHub Pages on the main branch (root path)
#   5. Prints the public URL
#
# Safe to re-run: if the repo already exists, step 2 reports that and continues.
# If git/.git already initialised, steps 3+ still work.

set -e
cd "$(dirname "$0")"

OWNER="giraffe2257-tech"
REPO="prd-interview-previews"
DESC="Interview preview documents for MSc dissertation (KCL) — PRD as Boundary Object in cross-functional teams."
EMAIL="devlab20230424@gmail.com"
NAME="Wang Wei"

# --- token -----------------------------------------------------------
TOKEN=$(security find-generic-password -a wangwei -s claude-code-github-mcp -w 2>/dev/null) || {
  echo "ERROR: could not read PAT from keychain (service=claude-code-github-mcp)." >&2
  exit 1
}

echo "→ Step 1/4: verify repo $OWNER/$REPO exists"
EXISTS_RESP=$(curl -sS -o /tmp/repo-check.json -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$OWNER/$REPO")
if [ "$EXISTS_RESP" = "200" ]; then
  echo "  ✓ repo exists"
elif [ "$EXISTS_RESP" = "404" ]; then
  echo "  ✗ repo does not exist yet."
  echo ""
  echo "    Fine-grained PATs cannot create repos. Please create it manually:"
  echo "      https://github.com/new"
  echo "      Name:        $REPO"
  echo "      Visibility:  Public"
  echo "      Description: $DESC"
  echo "    (Leave README / .gitignore / license unchecked — this script provides them.)"
  echo ""
  echo "    Then re-run this script."
  exit 1
else
  echo "  ✗ unexpected response ($EXISTS_RESP):"
  cat /tmp/repo-check.json
  exit 1
fi

# --- git -------------------------------------------------------------
echo "→ Step 2/4: git init + commit"
if [ ! -d .git ]; then
  git init -b main >/dev/null
fi

# Optional: .gitignore for preview screenshots
cat > .gitignore <<'EOF'
_preview-*.png
.DS_Store
EOF

git add .
if git diff --cached --quiet; then
  echo "  · no changes to commit"
else
  git -c user.email="$EMAIL" -c user.name="$NAME" \
    commit -m "Publish interview previews + consent forms" >/dev/null
  echo "  ✓ committed"
fi

# --- push ------------------------------------------------------------
echo "→ Step 3/4: push to origin"
# Set remote without storing token (use credential helper inline).
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/$OWNER/$REPO.git"

# One-shot push using inline credential helper — token never written to .git/config.
GIT_ASKPASS_TOKEN="$TOKEN" \
git -c "credential.helper=" \
    -c "credential.helper=!f() { echo username=x-access-token; echo password=\$GIT_ASKPASS_TOKEN; }; f" \
    push -u origin main

echo "  ✓ pushed"

# --- pages -----------------------------------------------------------
echo "→ Step 4/4: enable GitHub Pages"
PAGES_RESP=$(curl -sS -o /tmp/pages.json -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$OWNER/$REPO/pages" \
  -d '{"source":{"branch":"main","path":"/"}}')
if [ "$PAGES_RESP" = "201" ]; then
  echo "  ✓ Pages enabled"
elif [ "$PAGES_RESP" = "409" ]; then
  echo "  ✓ Pages already enabled"
else
  echo "  · Pages API response $PAGES_RESP:"
  cat /tmp/pages.json
fi

echo ""
echo "==============================================================="
echo "  Done. Public URL (allow ~30–60s for first build):"
echo "  https://$OWNER.github.io/$REPO/"
echo "==============================================================="

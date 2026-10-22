#!/usr/bin/env bash
# Build every "Guide - *" vault into a Kindle-ready EPUB with a thumbnail-legible
# cover. Run from the vault root:  bash .tools/build-guides.sh
set -euo pipefail

cd "$(dirname "$0")/.."
TOOLS=".tools"
COVERS="$TOOLS/covers"
mkdir -p "$COVERS"

# root | book title (dc:title) | output basename | cover title | accent hex
GUIDES=(
  "Guide - AI|AI Engineer Master Guide|Artificial Intelligence - Guide|Artificial Intelligence|2f6f4f"
  "Guide - Backend|Backend Engineering Master Guide|Backend Engineering - Guide|Backend Engineering|1f5f8b"
  "Guide - Frontend|Frontend Master Course|Frontend Engineering - Guide|Frontend Engineering|8b3a62"
  "Guide - Salesforce|Salesforce Master Guide|Salesforce Development - Guide|Salesforce Development|1d6fa5"
  "Guide - System Design/High Level Design|High Level Design|High Level Design - Guide|High Level Design|5b4b8a"
  "Guide - System Design/Low Level Design|Low Level Design|Low Level Design - Guide|Low Level Design|9c5a2d"
)

for row in "${GUIDES[@]}"; do
  IFS='|' read -r root title base covertitle accent <<< "$row"
  cover="$COVERS/${base}.png"
  echo "=== $covertitle"
  python3 "$TOOLS/make-cover.py" "$covertitle" "Guide" "$cover" "#$accent"
  perl "$TOOLS/vault-to-epub.pl" "$root" "$title" "$base" "$cover"
  # drop the intermediate markdown
  rm -f "$root/$base.md"
  echo
done

echo "All guides built."

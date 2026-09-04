#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_ROOT=${SCRIPT_DIR:h:h}

cd "$PROJECT_ROOT"

required_files=(
  LICENSE
  NOTICE
  README.md
  README.zh-CN.md
  CHANGELOG.md
  CONTRIBUTING.md
  SECURITY.md
  CODE_OF_CONDUCT.md
  docs/DISTRIBUTION.md
  docs/PRIVACY.md
  .github/workflows/ci.yml
)

for file in $required_files; do
  test -f "$file" || { echo "Missing required release file: $file" >&2; exit 1; }
done

if [[ -n $(git status --porcelain) ]]; then
  echo "Release preflight requires a clean Git working tree." >&2
  git status --short >&2
  exit 1
fi

if git ls-files | grep -E '(^|/)(build|DerivedData|artifacts)/|^release/|\.(xcarchive|xcresult|dSYM|dmg|pkg|zip)$' >/dev/null; then
  echo "Generated release or build artifacts are tracked by Git." >&2
  exit 1
fi

echo "==> Repository"
git log -1 --oneline
echo "branch: $(git branch --show-current)"

"$PROJECT_ROOT/scripts/ci.sh"

echo "Release preflight passed. Manual compatibility, signing, notarization, and clean-Mac installation checks remain required."

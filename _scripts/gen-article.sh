#!/bin/bash
# 記事・SNS投稿文を生成するスクリプト
# 使い方: ./gen-article.sh [YYYY-MM-DD] [-f]
#   YYYY-MM-DD  対象日付（省略時は今日）
#   -f          出力ファイルが存在しても強制的に再生成

SCRIPT_DIR="$(dirname "$0")"
DATE=""
FORCE=false

for arg in "$@"; do
  case "$arg" in
    -f) FORCE=true ;;
    *)  DATE="$arg" ;;
  esac
done
DATE=${DATE:-$(date +%Y-%m-%d)}

echo "対象日付: $DATE (force=$FORCE)"

# --- [1/3] Claude: 記事生成 ---
ARTICLE_FILE=$(ls "$SCRIPT_DIR/../_posts/${DATE}-"*.md 2>/dev/null | head -1)
if [ -n "$ARTICLE_FILE" ] && [ "$FORCE" = false ]; then
  echo "--- [1/3] スキップ: 記事がすでに存在します ($ARTICLE_FILE)"
  RAN_ARTICLE=false
else
  echo "--- [1/3] Claude: 記事生成 ---"
  ARTICLE_PROMPT=$(sed "s/{{DATE}}/$DATE/g" "$SCRIPT_DIR/../prompts/new-article.md")
  echo "$ARTICLE_PROMPT" | claude -p --dangerously-skip-permissions --output-format stream-json --verbose
  RAN_ARTICLE=true
fi

# --- [2/3] Codex: 動画URL修正（記事生成を実行した場合のみ）---
if [ "$RAN_ARTICLE" = false ]; then
  echo "--- [2/3] スキップ: 記事生成をスキップしたため"
else
  echo "--- [2/3] Codex: 動画URL修正 ---"
  VIDEO_PROMPT=$(sed "s/{{DATE}}/$DATE/g" "$SCRIPT_DIR/../prompts/fix-video.md")
  codex exec -s danger-full-access "$VIDEO_PROMPT"
fi

# --- [3/3] Claude: SNS投稿文生成 ---
SNS_DIR="$SCRIPT_DIR/../_sns/$DATE"
if [ -d "$SNS_DIR" ] && [ "$FORCE" = false ]; then
  echo "--- [3/3] スキップ: SNS投稿文がすでに存在します ($SNS_DIR)"
else
  echo "--- [3/3] Claude: SNS投稿文生成 ---"
  SNS_PROMPT=$(sed "s/{{DATE}}/$DATE/g" "$SCRIPT_DIR/../prompts/new-sns.md")
  echo "$SNS_PROMPT" | claude -p --dangerously-skip-permissions --output-format stream-json --verbose
fi

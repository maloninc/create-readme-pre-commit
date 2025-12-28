#!/bin/bash
set -euo pipefail

# Analyze code changes and suggest documentation updates

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}✓${NC} $1" >&2
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1" >&2
}

# Get list of changed files
get_changed_files() {
    if [ ! -f "changed_files.txt" ]; then
        log_error "No changed files found"
        return 1
    fi
    cat changed_files.txt
}

# Get the diff for a specific file
get_file_diff() {
    local file_path="$1"
    local base_ref="$2"
    local head_sha="$3"

    git diff "origin/${base_ref}...${head_sha}" -- "$file_path" 2>/dev/null || echo ""
}

# Read file content
read_file_content() {
    local file_path="$1"

    if [ -f "$file_path" ]; then
        cat "$file_path"
    else
        echo ""
    fi
}

# Escape JSON string
json_escape() {
    local input="$1"
    # Escape backslashes, quotes, newlines, tabs, etc.
    echo "$input" | jq -Rs .
}

# Call GitHub Models API
call_github_models_api() {
    local prompt="$1"
    local model="${2:-gpt-4o}"
    local token="$3"

    if [ -z "$token" ]; then
        log_error "MODELS_TOKEN is required"
        return 1
    fi

    local url="https://models.inference.ai.azure.com/chat/completions"

    # Build JSON payload
    local system_message="あなたは技術ドキュメントのアシスタントです。コードの変更を分析し、README.mdとAPI-spec.mdファイルの更新を日本語で提案してください。提案はdiff形式で具体的に示してください。"

    local payload=$(jq -n \
        --arg model "$model" \
        --arg system_msg "$system_message" \
        --arg user_msg "$prompt" \
        '{
            model: $model,
            messages: [
                {
                    role: "system",
                    content: $system_msg
                },
                {
                    role: "user",
                    content: $user_msg
                }
            ],
            temperature: 0.3,
            max_tokens: 4000
        }')

    # Make API call
    local response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -d "$payload" \
        --max-time 60)

    # Extract HTTP status code (last line)
    local http_code=$(echo "$response" | tail -n1)
    # Extract response body (all but last line)
    local response_body=$(echo "$response" | sed '$d')

    if [ "$http_code" != "200" ]; then
        log_error "API call failed with status $http_code"
        echo "Response: $response_body" >&2
        return 1
    fi

    # Extract content from response
    echo "$response_body" | jq -r '.choices[0].message.content'
}

# Analyze changes and generate documentation suggestions
analyze_changes() {
    local changed_files="$1"
    local base_ref="$2"
    local head_sha="$3"
    local models_token="$4"

    # Filter for relevant files (Ruby source files)
    local relevant_files=$(echo "$changed_files" | grep -E '\.(rb|ru)$' || true)

    if [ -z "$relevant_files" ]; then
        log_info "No relevant source code changes detected"
        return 1
    fi

    log_info "Found $(echo "$relevant_files" | wc -l) relevant file(s)"

    # Read current documentation
    local api_spec=$(read_file_content "API-spec.md")
    local readme=$(read_file_content "README.md")

    # Build analysis prompt
    local prompt="# コード変更の分析依頼

以下のコード変更を分析し、ドキュメントの更新が必要かどうかを判断してください。

## 現在のAPI仕様書
"

    if [ -n "$api_spec" ]; then
        prompt+="
\`\`\`markdown
${api_spec}
\`\`\`
"
    else
        prompt+="
（API-spec.mdはまだ存在しません）
"
    fi

    prompt+="
## 現在のREADME
"

    if [ -n "$readme" ]; then
        prompt+="
\`\`\`markdown
${readme}
\`\`\`
"
    else
        prompt+="
（README.mdはまだ存在しません）
"
    fi

    prompt+="
## コードの変更内容
"

    # Add diffs for each relevant file
    while IFS= read -r file_path; do
        [ -z "$file_path" ] && continue

        local diff=$(get_file_diff "$file_path" "$base_ref" "$head_sha")
        if [ -n "$diff" ]; then
            prompt+="
### ファイル: ${file_path}
\`\`\`diff
${diff}
\`\`\`
"
        fi
    done <<< "$relevant_files"

    prompt+="
## 指示

コードの変更を分析して、以下を判断してください：

1. README.mdの作成または更新が必要か
2. API-spec.mdの更新が必要か
3. 更新が必要な場合は、以下を提供してください：
   - 何が変更されたかの明確な説明
   - 更新が必要なドキュメントのセクション
   - **diff形式**での具体的な変更提案

回答は以下の形式で記述してください：

## 📋 変更の概要
[変更内容の簡潔な要約]

## 📝 必要なドキュメント更新

### README.md
**更新の必要性**: [必要/不要/新規作成]

[必要な場合は以下のdiff形式で提案してください]

\`\`\`diff
--- README.md
+++ README.md
@@ -行番号,行数 +行番号,行数 @@
 既存の行
-削除する行
+追加する行
 既存の行
\`\`\`

### API-spec.md
**更新の必要性**: [必要/不要]

[必要な場合は以下のdiff形式で提案してください]

\`\`\`diff
--- API-spec.md
+++ API-spec.md
@@ -行番号,行数 +行番号,行数 @@
 既存の行
-削除する行
+追加する行
 既存の行
\`\`\`

**重要**:
- すべての提案は日本語で記述してください
- 変更箇所は必ずdiff形式で示してください
- 行番号は概算で構いません

ドキュメントの更新が不要な場合は、以下のように回答してください：
\"ドキュメントの更新は不要です。\"
"

    # Call API
    log_info "Calling GitHub Models API..."
    call_github_models_api "$prompt" "gpt-4o" "$models_token"
}

# Main function
main() {
    # Get environment variables
    local models_token="${MODELS_TOKEN:-}"
    local base_ref="${BASE_REF:-main}"
    local head_sha="${HEAD_SHA:-}"
    local github_output="${GITHUB_OUTPUT:-/dev/stdout}"

    if [ -z "$models_token" ]; then
        log_error "MODELS_TOKEN not set"
        exit 1
    fi

    # Get changed files
    local changed_files
    changed_files=$(get_changed_files) || {
        log_info "No files changed"
        echo "No files changed in this PR." > doc_suggestions.md
        echo "has_suggestions=false" >> "$github_output"
        exit 0
    }

    log_info "Analyzing $(echo "$changed_files" | wc -l) changed file(s)..."

    # Analyze changes
    local suggestions
    suggestions=$(analyze_changes "$changed_files" "$base_ref" "$head_sha" "$models_token") || {
        log_info "No documentation updates needed"
        echo "has_suggestions=false" >> "$github_output"
        exit 0
    }

    if [ -n "$suggestions" ] && ! echo "$suggestions" | grep -q "ドキュメントの更新は不要です"; then
        # Write suggestions to file
        cat > doc_suggestions.md <<EOF
## 📚 ドキュメント更新の提案

${suggestions}

---
*この分析はAIによって自動生成されました。提案内容を注意深くレビューしてください。*
EOF

        # Set output for GitHub Actions
        echo "has_suggestions=true" >> "$github_output"

        log_info "Documentation suggestions generated"
    else
        log_info "No documentation updates needed"
        echo "has_suggestions=false" >> "$github_output"
    fi
}

# Run main function
main "$@"

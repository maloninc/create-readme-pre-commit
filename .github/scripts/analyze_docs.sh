#!/bin/bash
set -euo pipefail

# Analyze code changes and suggest documentation updates

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
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
    local system_message="You are a technical documentation assistant. Analyze code changes and suggest documentation updates for README.md and API-spec.md files."

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
    local prompt="# Code Change Analysis Request

Please analyze the following code changes and determine if documentation updates are needed.

## Current API Specification
"

    if [ -n "$api_spec" ]; then
        prompt+="
\`\`\`markdown
${api_spec}
\`\`\`
"
    else
        prompt+="
(No API-spec.md exists yet)
"
    fi

    prompt+="
## Current README
"

    if [ -n "$readme" ]; then
        prompt+="
\`\`\`markdown
${readme}
\`\`\`
"
    else
        prompt+="
(No README.md exists yet)
"
    fi

    prompt+="
## Code Changes
"

    # Add diffs for each relevant file
    while IFS= read -r file_path; do
        [ -z "$file_path" ] && continue

        local diff=$(get_file_diff "$file_path" "$base_ref" "$head_sha")
        if [ -n "$diff" ]; then
            prompt+="
### File: ${file_path}
\`\`\`diff
${diff}
\`\`\`
"
        fi
    done <<< "$relevant_files"

    prompt+="
## Instructions

Analyze the code changes and:

1. Determine if README.md needs to be created or updated
2. Determine if API-spec.md needs to be updated
3. For each needed update, provide:
   - A clear explanation of what changed
   - The specific documentation sections that need updates
   - Concrete suggested changes in markdown format

Format your response as:

## Analysis Summary
[Brief summary of changes]

## Documentation Updates Needed

### README.md
[State if update needed: YES/NO/CREATE]
[If YES/CREATE: provide specific suggestions]

### API-spec.md
[State if update needed: YES/NO]
[If YES: provide specific suggestions]

If no documentation updates are needed, respond with:
\"No documentation updates required.\"
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

    if [ -n "$suggestions" ] && ! echo "$suggestions" | grep -q "No documentation updates required"; then
        # Write suggestions to file
        cat > doc_suggestions.md <<EOF
## 📚 Documentation Update Suggestions

${suggestions}

---
*This analysis was generated automatically by AI. Please review the suggestions carefully.*
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

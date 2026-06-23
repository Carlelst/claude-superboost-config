#!/usr/bin/env bash
# Wiki Skill - Shell-based CLI for Enflame Wiki
# VERSION: 2.0.0
# Replaces Python implementation with native shell (bash + curl + jq)
set -euo pipefail

VERSION="2.0.0"

# ============================================================
# Configuration paths & defaults
# ============================================================
readonly CONFIG_DIR="${HOME}/.config/wiki-cli"
readonly CONFIG_FILE="${CONFIG_DIR}/wiki.conf"
readonly LOCAL_CONFIG="./wiki.conf"
readonly _DEFAULT_WIKI_URL="http://wiki.enflame.cn/"
readonly _DEFAULT_LIMIT="50"

# ============================================================
# Runtime variables (set by load_config, overridden by config file)
# ============================================================
WIKI_USERNAME=""
WIKI_PASSWORD=""
WIKI_URL="$_DEFAULT_WIKI_URL"
DEFAULT_LIMIT="$_DEFAULT_LIMIT"

# ============================================================
# Dependency checks
# ============================================================
check_dependencies() {
    local missing=()

    if ! command -v curl &>/dev/null; then
        missing+=("curl")
    fi
    if ! command -v jq &>/dev/null; then
        missing+=("jq")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies: ${missing[*]}" >&2
        echo "Install them with: apt-get install ${missing[*]}" >&2
        exit 1
    fi
}

# ============================================================
# Config file management
# ============================================================
resolve_config_path() {
    if [ -f "$LOCAL_CONFIG" ]; then
        echo "$LOCAL_CONFIG"
    else
        echo "$CONFIG_FILE"
    fi
}

get_config_path() {
    if [ -f "$LOCAL_CONFIG" ]; then
        echo "$LOCAL_CONFIG"
    else
        mkdir -p "$CONFIG_DIR"
        echo "$CONFIG_FILE"
    fi
}

load_config() {
    local config_file
    config_file=$(resolve_config_path)

    # Set defaults first
    WIKI_URL="$_DEFAULT_WIKI_URL"
    DEFAULT_LIMIT="$_DEFAULT_LIMIT"
    WIKI_USERNAME=""
    WIKI_PASSWORD=""

    if [ -f "$config_file" ]; then
        # shellcheck source=/dev/null
        . "$config_file"
    fi
}

save_config() {
    local config_file
    config_file=$(get_config_path)

    cat > "$config_file" <<EOF
# Wiki Skill Configuration
WIKI_USERNAME="${WIKI_USERNAME}"
WIKI_PASSWORD="${WIKI_PASSWORD}"
WIKI_URL="${WIKI_URL}"
DEFAULT_LIMIT="${DEFAULT_LIMIT}"
EOF
}

# ============================================================
# Credential setup
# ============================================================
setup_credentials() {
    local username password

    echo "=== Wiki Skill Setup ==="

    read -r -p "Username: " username
    if [ -z "$username" ]; then
        echo "Username is required!" >&2
        return 1
    fi

    read -r -s -p "Password: " password
    echo
    if [ -z "$password" ]; then
        echo "Password is required!" >&2
        return 1
    fi

    WIKI_USERNAME="$username"
    WIKI_PASSWORD="$password"
    WIKI_URL="$_DEFAULT_WIKI_URL"
    DEFAULT_LIMIT="$_DEFAULT_LIMIT"

    if save_config; then
        echo "Credentials saved successfully!"
        return 0
    else
        echo "Failed to save credentials!" >&2
        return 1
    fi
}

ensure_credentials() {
    if [ -z "${WIKI_USERNAME:-}" ] || [ -z "${WIKI_PASSWORD:-}" ]; then
        echo "Credentials not configured. Please set up your account:"
        if ! setup_credentials; then
            echo "Setup failed. Exiting." >&2
            exit 1
        fi
        load_config
    fi
}

# ============================================================
# API call helper
# ============================================================
# Usage: api_call METHOD ENDPOINT [curl-options...]
# Prints response body to stdout on success.
# On HTTP error, prints error to stderr and returns non-zero.
api_call() {
    local method="$1" endpoint="$2"
    shift 2

    local url="${WIKI_URL%/}/${endpoint#/}"
    local tmpfile cred_file
    tmpfile=$(mktemp)
    cred_file=$(mktemp)
    local http_code

    # Clean up temp files on function return
    # shellcheck disable=SC2064
    trap "rm -f '$tmpfile' '$cred_file'" RETURN

    # Write credentials to a temp file so they stay off the process list.
    # curl reads them via -K (--config) and enforces file permissions.
    printf 'user = "%s:%s"\n' "$WIKI_USERNAME" "$WIKI_PASSWORD" > "$cred_file"
    chmod 600 "$cred_file"

    http_code=$(curl -s -w "%{http_code}" -o "$tmpfile" \
        -X "$method" \
        -K "$cred_file" \
        -H "Accept: application/json" \
        "$@" \
        "$url")

    if [ "$http_code" -ge 400 ]; then
        echo "Error: HTTP ${http_code}" >&2
        if [ -s "$tmpfile" ]; then
            cat "$tmpfile" >&2
        fi
        return 1
    fi

    cat "$tmpfile"
}

# ============================================================
# Display helpers
# ============================================================
print_separator() {
    printf '─%.0s' $(seq 1 60)
    echo
}

# ============================================================
# Wiki operations
# ============================================================

# --- spaces ---
cmd_spaces() {
    local limit="${1:-$DEFAULT_LIMIT}"
    local response

    echo "Fetching spaces (limit: $limit)..."
    response=$(api_call GET "/rest/api/space" -G --data-urlencode "limit=$limit") || return 1

    local count
    count=$(echo "$response" | jq -r '.results | length')
    echo "Found ${count} spaces:"
    print_separator

    echo "$response" | jq -r '.results[] | "\(.name) (\(.key)) [\(.type)]"'
}

# --- search ---
cmd_search() {
    local cql="$1" limit="${2:-$DEFAULT_LIMIT}"
    local response

    echo "Searching with CQL: ${cql}"
    response=$(api_call GET "/rest/api/content/search" \
        -G \
        --data-urlencode "cql=$cql" \
        --data-urlencode "limit=$limit") || return 1

    local count
    count=$(echo "$response" | jq -r '.results | length')
    echo "Found ${count} matching pages:"
    print_separator

    echo "$response" | jq -r \
        --arg base "$WIKI_URL" \
        '.results[] | "\(.title)  [ID: \(.id)]  \($base)pages/viewpage.action?pageId=\(.id)"'
}

# --- page (by page-id or space+title) ---
cmd_page() {
    local page_id="${1:-}" space="${2:-}" title="${3:-}" raw_mode="${4:-}"
    local response

    if [ -n "$page_id" ]; then
        response=$(api_call GET "/rest/api/content/${page_id}" \
            -G --data-urlencode "expand=body.storage,version,ancestors") || return 1

        if [ "$raw_mode" = "1" ]; then
            echo "$response" | jq -r '.body.storage.value'
        else
            echo "Page Info:"
            print_separator
            echo "$response" | jq -r \
                --arg base "$WIKI_URL" \
                '"
Title    : \(.title)
ID       : \(.id)
Space    : \(.space.key)
Version  : \(.version.number)
URL      : \($base)pages/viewpage.action?pageId=\(.id)
--
Content:
\(.body.storage.value)"'
        fi
    elif [ -n "$space" ] && [ -n "$title" ]; then
        response=$(api_call GET "/rest/api/content" \
            -G \
            --data-urlencode "spaceKey=$space" \
            --data-urlencode "title=$title" \
            --data-urlencode "expand=body.storage,version,ancestors") || return 1

        local count
        count=$(echo "$response" | jq -r '.results | length')
        if [ "$count" -eq 0 ]; then
            echo "Page not found"
            return 1
        fi

        if [ "$raw_mode" = "1" ]; then
            echo "$response" | jq -r '.results[0].body.storage.value'
        else
            echo "$response" | jq -r \
                --arg base "$WIKI_URL" \
                '.results[0] | "
Title    : \(.title)
ID       : \(.id)
Space    : \(.space.key)
Version  : \(.version.number)
URL      : \($base)pages/viewpage.action?pageId=\(.id)
--
Content:
\(.body.storage.value)"'
        fi
    else
        echo "Error: Provide either --page-id or both --space and --title" >&2
        return 1
    fi
}

# --- children ---
cmd_children() {
    local page_id="$1" limit="${2:-$DEFAULT_LIMIT}"

    echo "Fetching child pages for page ${page_id}..."
    response=$(api_call GET "/rest/api/content/${page_id}/child/page" \
        -G --data-urlencode "limit=$limit") || return 1

    local count
    count=$(echo "$response" | jq -r '.results | length')
    echo "Found ${count} child pages:"
    print_separator

    echo "$response" | jq -r \
        --arg base "$WIKI_URL" \
        '.results[] | "\(.title)  [ID: \(.id)]  \($base)pages/viewpage.action?pageId=\(.id)"'
}

# --- attachments ---
cmd_attachments() {
    local page_id="$1"

    echo "Fetching attachments for page ${page_id}..."
    response=$(api_call GET "/rest/api/content/${page_id}/child/attachment") || return 1

    local count
    count=$(echo "$response" | jq -r '.results | length')
    echo "Found ${count} attachments:"
    print_separator

    echo "$response" | jq -r \
        '.results[] | "\(.title // .filename)  [\(.metadata.mediaType // "Unknown")]  Size: \(.extensions.fileSize // "N/A")"'
}

# --- comments ---
cmd_comments() {
    local page_id="$1" limit="${2:-$DEFAULT_LIMIT}"

    echo "Fetching comments for page ${page_id}..."
    response=$(api_call GET "/rest/api/content/${page_id}/child/comment" \
        -G --data-urlencode "limit=$limit") || return 1

    local count
    count=$(echo "$response" | jq -r '.results | length')
    echo "Found ${count} comments:"
    print_separator

    echo "$response" | jq -r \
        '.results[] | "By \(.author.displayName // "Unknown") at \(.created // "N/A"):\n\(.body.storage.value[0:100])...\n"'
}

# --- create ---
cmd_create() {
    local space="$1" title="$2" body="$3" parent_id="${4:-}"
    local response

    local payload
    if [ -n "$parent_id" ]; then
        payload=$(jq -n \
            --arg space "$space" \
            --arg title "$title" \
            --arg body "$body" \
            --arg parent_id "$parent_id" \
            '{
                type: "page",
                title: $title,
                space: { key: $space },
                body: {
                    storage: {
                        value: $body,
                        representation: "storage"
                    }
                },
                ancestors: [{ id: $parent_id }]
            }')
    else
        payload=$(jq -n \
            --arg space "$space" \
            --arg title "$title" \
            --arg body "$body" \
            '{
                type: "page",
                title: $title,
                space: { key: $space },
                body: {
                    storage: {
                        value: $body,
                        representation: "storage"
                    }
                }
            }')
    fi

    echo "Creating page '${title}' in space '${space}'..."
    response=$(api_call POST "/rest/api/content" -H "Content-Type: application/json" -d "$payload") || return 1

    echo "Created page successfully!"
    print_separator
    echo "$response" | jq -r \
        --arg base "$WIKI_URL" \
        '"
Title : \(.title)
ID    : \(.id)
URL   : \($base)pages/viewpage.action?pageId=\(.id)"'
}

# --- update ---
cmd_update() {
    local page_id="$1" body="$2"
    local response current_version current_title

    # Fetch current page to get version number and title
    response=$(api_call GET "/rest/api/content/${page_id}") || return 1
    current_version=$(echo "$response" | jq -r '.version.number')
    current_title=$(echo "$response" | jq -r '.title')

    local payload
    payload=$(jq -n \
        --arg id "$page_id" \
        --arg title "$current_title" \
        --arg body "$body" \
        --argjson version $(( current_version + 1 )) \
        '{
            id: $id,
            type: "page",
            title: $title,
            body: {
                storage: {
                    value: $body,
                    representation: "storage"
                }
            },
            version: {
                number: $version
            }
        }')

    echo "Updating page '${current_title}' (ID: ${page_id}) to version $(( current_version + 1 ))..."
    response=$(api_call PUT "/rest/api/content/${page_id}" -H "Content-Type: application/json" -d "$payload") || return 1

    echo "Updated page successfully!"
    print_separator
    echo "$response" | jq -r \
        --arg base "$WIKI_URL" \
        '"
Title   : \(.title)
ID      : \(.id)
Version : \(.version.number)
URL     : \($base)pages/viewpage.action?pageId=\(.id)"'
}

# --- add-comment ---
cmd_add_comment() {
    local page_id="$1" comment="$2"
    local response

    local payload
    payload=$(jq -n \
        --arg comment "$comment" \
        '{
            type: "comment",
            body: {
                storage: {
                    value: $comment,
                    representation: "storage"
                }
            }
        }')

    echo "Adding comment to page ${page_id}..."
    response=$(api_call POST "/rest/api/content/${page_id}/child/comment" \
        -H "Content-Type: application/json" -d "$payload") || return 1

    echo "Added comment successfully!"
    print_separator
    echo "$response" | jq -r \
        --arg base "$WIKI_URL" \
        --arg pid "$page_id" \
        '"
Comment ID : \(.id)
URL        : \($base)pages/viewpage.action?pageId=\($pid)#comment-\(.id)"'
}

# --- config ---
cmd_config() {
    echo "Config file: $(resolve_config_path)"
    echo "Username   : ${WIKI_USERNAME:-Not set}"
    echo "Wiki URL   : ${WIKI_URL:-Not set}"
    echo "Limit      : ${DEFAULT_LIMIT:-Not set}"
}

# ============================================================
# CLI help
# ============================================================
print_help() {
    cat <<EOF
Wiki Skill CLI v${VERSION}

Usage: wiki_skill.sh <command> [options]

Commands:
  spaces     [--limit N]                 List all wiki spaces
  page       --page-id ID [--raw]           Get page by ID (--raw: body only, no header)
  page       --space KEY --title TITLE [--raw]  Get page by space and title
  search     --cql CQL [--limit N]       Search pages using CQL
  children   --page-id ID [--limit N]    Get child pages
  attachments --page-id ID               Get page attachments
  comments   --page-id ID [--limit N]    Get page comments
  create     --space KEY --title TITLE   Create a new page
             --body TEXT [--parent-id ID]
  update     --page-id ID --body TEXT      Update page content (title preserved)
  add-comment --page-id ID --comment TEXT Add a comment to a page
  config                                 Show current configuration
  setup                                  Re-run credential setup

Examples:
  wiki_skill.sh spaces --limit 10
  wiki_skill.sh search --cql "type=page and title~'技术文档'"
  wiki_skill.sh page --page-id 12345
  wiki_skill.sh create --space DEV --title "New Page" --body "<p>Hello</p>"

EOF
}

# ============================================================
# Argument parsing & dispatch
# ============================================================
main() {
    check_dependencies
    load_config

    local cmd="${1:-}"

    # Handle no-argument cases
    if [ -z "$cmd" ]; then
        if [ -z "${WIKI_USERNAME:-}" ] || [ -z "${WIKI_PASSWORD:-}" ]; then
            echo "Welcome to Wiki Skill v${VERSION}!"
            echo "It looks like you haven't configured your credentials yet."
            echo
            setup_credentials || exit 1
            echo
            print_help
        else
            print_help
        fi
        exit 0
    fi

    case "$cmd" in
    setup)
        setup_credentials
        exit $?
        ;;

    config)
        cmd_config
        exit 0
        ;;

    spaces)
        ensure_credentials
        local limit="$DEFAULT_LIMIT"
        shift
        while [ $# -gt 0 ]; do
            case "$1" in
            --limit) limit="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
            esac
        done
        cmd_spaces "$limit"
        ;;

    page)
        ensure_credentials
        local page_id="" space="" title="" raw_mode=""
        shift
        while [ $# -gt 0 ]; do
            case "$1" in
            --page-id) page_id="$2"; shift 2 ;;
            --space)   space="$2"; shift 2 ;;
            --title)   title="$2"; shift 2 ;;
            --raw)     raw_mode="1"; shift ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
            esac
        done
        cmd_page "$page_id" "$space" "$title" "$raw_mode"
        ;;

    search)
        ensure_credentials
        local cql="" limit="$DEFAULT_LIMIT"
        shift
        while [ $# -gt 0 ]; do
            case "$1" in
            --cql)   cql="$2"; shift 2 ;;
            --limit) limit="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
            esac
        done
        if [ -z "$cql" ]; then
            echo "Error: --cql is required for search command" >&2
            exit 1
        fi
        cmd_search "$cql" "$limit"
        ;;

    children)
        ensure_credentials
        local page_id="" limit="$DEFAULT_LIMIT"
        shift
        while [ $# -gt 0 ]; do
            case "$1" in
            --page-id) page_id="$2"; shift 2 ;;
            --limit)   limit="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
            esac
        done
        if [ -z "$page_id" ]; then
            echo "Error: --page-id is required for children command" >&2
            exit 1
        fi
        cmd_children "$page_id" "$limit"
        ;;

    attachments)
        ensure_credentials
        local page_id=""
        shift
        while [ $# -gt 0 ]; do
            case "$1" in
            --page-id) page_id="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
            esac
        done
        if [ -z "$page_id" ]; then
            echo "Error: --page-id is required for attachments command" >&2
            exit 1
        fi
        cmd_attachments "$page_id"
        ;;

    comments)
        ensure_credentials
        local page_id="" limit="$DEFAULT_LIMIT"
        shift
        while [ $# -gt 0 ]; do
            case "$1" in
            --page-id) page_id="$2"; shift 2 ;;
            --limit)   limit="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
            esac
        done
        if [ -z "$page_id" ]; then
            echo "Error: --page-id is required for comments command" >&2
            exit 1
        fi
        cmd_comments "$page_id" "$limit"
        ;;

    create)
        ensure_credentials
        local space="" title="" body="" parent_id=""
        shift
        while [ $# -gt 0 ]; do
            case "$1" in
            --space)     space="$2"; shift 2 ;;
            --title)     title="$2"; shift 2 ;;
            --body)      body="$2"; shift 2 ;;
            --parent-id) parent_id="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
            esac
        done
        if [ -z "$space" ] || [ -z "$title" ] || [ -z "$body" ]; then
            echo "Error: --space, --title, and --body are required for create command" >&2
            exit 1
        fi
        cmd_create "$space" "$title" "$body" "$parent_id"
        ;;

    update)
        ensure_credentials
        local page_id="" body=""
        shift
        while [ $# -gt 0 ]; do
            case "$1" in
            --page-id) page_id="$2"; shift 2 ;;
            --body)    body="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
            esac
        done
        if [ -z "$page_id" ] || [ -z "$body" ]; then
            echo "Error: --page-id and --body are required for update command" >&2
            exit 1
        fi
        cmd_update "$page_id" "$body"
        ;;

    add-comment)
        ensure_credentials
        local page_id="" comment=""
        shift
        while [ $# -gt 0 ]; do
            case "$1" in
            --page-id) page_id="$2"; shift 2 ;;
            --comment) comment="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
            esac
        done
        if [ -z "$page_id" ] || [ -z "$comment" ]; then
            echo "Error: --page-id and --comment are required for add-comment command" >&2
            exit 1
        fi
        cmd_add_comment "$page_id" "$comment"
        ;;

    -h|--help|help)
        print_help
        ;;

    *)
        echo "Unknown command: $cmd" >&2
        echo
        print_help
        exit 1
        ;;
    esac
}

# ============================================================
# Entry point
# ============================================================
main "$@"

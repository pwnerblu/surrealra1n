#!/usr/bin/env bash

get_latest_version() {
    local default_latest="$CURRENT_VERSION"
    local source_repo="${SURREALRA1N_UPDATE_REPO:-pwnerblu/surrealra1n}"
    local url=""

    if [[ "$source_repo" == "origin" ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local origin_url
        origin_url="$(git config --get remote.origin.url 2>/dev/null || true)"
        if [[ "$origin_url" =~ github.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
            source_repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        fi
    fi

    url="https://raw.githubusercontent.com/${source_repo}/main/update/latest.txt"
    UPDATE_SOURCE_REPO="$source_repo"
    UPDATE_SOURCE_URL="https://github.com/${source_repo}.git"
    UPDATE_SOURCE_BRANCH="${SURREALRA1N_UPDATE_BRANCH:-main}"
    export UPDATE_SOURCE_REPO UPDATE_SOURCE_URL UPDATE_SOURCE_BRANCH

    if curl -fsSL "$url" -o "$PROJECT_ROOT/update/latest.txt.tmp" 2>/dev/null; then
        LATEST_VERSION=$(awk 'NR==1 {gsub(/\r/,""); print; exit}' "$PROJECT_ROOT/update/latest.txt.tmp")
        RELEASE_NOTES=$(awk '/^RELEASE NOTES:/{flag=1; next} flag' "$PROJECT_ROOT/update/latest.txt.tmp")
        mv "$PROJECT_ROOT/update/latest.txt.tmp" "$PROJECT_ROOT/update/latest.txt"
    else
        LATEST_VERSION="$default_latest"
        RELEASE_NOTES=""
        rm -f "$PROJECT_ROOT/update/latest.txt.tmp"
    fi
}

try_git_auto_update() {
    if [[ "${SURREALRA1N_UPDATED_ONCE:-0}" == "1" ]]; then
        return 1
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 1
    fi

    echo "[*] Auto-updating to $LATEST_VERSION..."
    if git pull --rebase --autostash "$UPDATE_SOURCE_URL" "$UPDATE_SOURCE_BRANCH"; then
        echo "[*] Update complete, restarting..."
        SURREALRA1N_UPDATED_ONCE=1 exec "$PROJECT_ROOT/surrealra1n_new.sh" "$@"
    fi

    return 1
}

maybe_auto_update() {
    echo "[*] Checking for updates..."
    get_latest_version

    if [[ "$LATEST_VERSION" == "$CURRENT_VERSION" ]]; then
        echo "[*] Using current version: $CURRENT_VERSION"
        return 0
    fi

    echo "[*] New version detected: $LATEST_VERSION (current: $CURRENT_VERSION)"
    if [[ -n "${RELEASE_NOTES:-}" ]]; then
        echo "RELEASE NOTES:"
        echo "$RELEASE_NOTES"
    fi

    echo "[*] Update available. Starting auto-update..."
    try_git_auto_update "$@" || {
        echo "[!] Auto-update failed, continuing with current version: $CURRENT_VERSION"
        return 0
    }
}

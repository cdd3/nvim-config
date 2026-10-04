#!/usr/bin/env bash
# User-local Neovim bootstrap, revised 2026-10-04.
# Read main() at the bottom for the execution order.
# Run as the intended user, not through sudo. Requires Bash 4+, GNU/Linux.
# Python/Node installation and ripgrep/ctags await the configuration/plugin audit.
set -Eeuo pipefail

log() {
    printf '%s\n' "$*" >&2
}
die() {
    log "ERROR: $*"
    exit 1
}
report_error() {
    local status=$1 function_name=$2 line_number=$3
    printf 'ERROR: %s failed at line %s (status %s).\n' \
        "$function_name" "$line_number" "$status" >&2
    exit "$status"
}
trap 'report_error "$?" "${FUNCNAME[0]:-main}" "$LINENO"' ERR
WORK_DIR=''
cleanup() {
    if [[ -n "$WORK_DIR" ]]; then
        rm -rf -- "$WORK_DIR"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

usage() {
    cat <<'HELP'
Usage: nvim_setup_linux.sh [options]

  --config-dir DIR       Neovim config checkout (must contain init.lua/init.vim).
                         Default: script directory, then its parent.
  --non-interactive      Never prompt (also the default without stdin/stderr TTYs).
  --interactive          Permit conflict prompts; requires stdin/stderr TTYs.
  --force                Back up conflicting config/executable paths before linking.
  --update               Resolve latest stable releases even if already installed.
  --nvim-version TAG     Install a specific upstream release tag (e.g. v0.11.5).
  --luals-version TAG    Install a specific LuaLS release tag.
  --without-luals        Skip LuaLS installation and linking.
  --skip-plugins         Skip headless Lazy plugin installation (useful offline).
  --without-python      Skip Python discovery; does not change the config.
  --without-node        Skip Node discovery; does not change the config.
  --debug               Enable Bash command tracing.
  -h, --help            Show this help without making changes.

Installs into ~/tools, caches archives in ~/packages, links commands into ~/bin.
Config uses ${XDG_CONFIG_HOME:-~/.config}/nvim. No shell profiles are modified.
Existing local tools are reused by default; --update explicitly refreshes them.
Version tags pin tools only; plugin versions remain controlled by your Lazy config.
Python/Node are detected only, with no packages or providers installed.
Requires curl or wget, jq, tar, gzip, sha256sum, flock, and GNU coreutils.
Plugin installation additionally requires git and timeout. Network access is
needed for new tool releases and missing plugins. A fully provisioned installation
can be rerun offline with --skip-plugins and without --update/version options.
Only x86_64 and aarch64 Linux upstream binaries are supported (not 32-bit Pis).
Conflicts fail in automation unless --force is supplied; backups are retained.
HELP
}

INTERACTIVE=false
[[ -t 0 && -t 2 ]] && INTERACTIVE=true
FORCE=false
UPDATE=false
SKIP_PLUGINS=false
WITH_LUALS=true
WITH_PYTHON=true
WITH_NODE=true
CONFIG_SOURCE=''
NVIM_VERSION=''
LUALS_VERSION=''

parse_arguments() {
    while (($#)); do
        case "$1" in
            --config-dir | --nvim-version | --luals-version)
                if (($# < 2)); then
                    die "$1 requires a value."
                fi
                if [[ -z "$2" || "$2" == --* ]]; then
                    die "$1 requires a value."
                fi
                case "$1" in
                    --config-dir) CONFIG_SOURCE=$2 ;;
                    --nvim-version) NVIM_VERSION=$2 ;;
                    --luals-version) LUALS_VERSION=$2 ;;
                esac
                shift 2
                ;;
            --non-interactive)
                INTERACTIVE=false
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --update)
                UPDATE=true
                shift
                ;;
            --without-luals)
                WITH_LUALS=false
                shift
                ;;
            --skip-plugins)
                SKIP_PLUGINS=true
                shift
                ;;
            --without-python)
                WITH_PYTHON=false
                shift
                ;;
            --without-node)
                WITH_NODE=false
                shift
                ;;
            --debug)
                set -x
                shift
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *) die "Unknown argument: $1 (see --help)." ;;
        esac
    done

}

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        die "Required utility '$1' is missing; install it before rerunning."
}
# Include dangling symlinks, which -e alone would miss.
exists() {
    [[ -e "$1" || -L "$1" ]]
}
correct_link() {
    local source=$1 destination=$2
    [[ -L "$destination" && $(readlink -m -- "$destination") == "$(readlink -m -- "$source")" ]]
}
allow_conflict() {
    local path=$1 answer
    log "Conflicting path: $path"
    if "$FORCE"; then
        return
    fi
    if "$INTERACTIVE"; then
        printf 'Back up this path and replace it with a symlink? [y/N] ' >&2
        read -r answer || die "No response; leaving $path unchanged."
        [[ "$answer" == y || "$answer" == Y ]] && return
    fi
    die "Leaving $path unchanged. Use --force to preserve a backup and replace it."
}
backup_path() {
    local path=$1 backup
    backup=$(mktemp -d "${path}.backup.$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")
    mv -T -- "$path" "$backup/original"
    log "Preserved $path at $backup/original"
}
link_path() {
    local source=$1 dest=$2 staged
    correct_link "$source" "$dest" && return
    # Conflicts have already been authorized during preflight under the lock.
    if exists "$dest"; then
        backup_path "$dest"
    fi
    staged="$WORK_DIR/link"
    ln -s -- "$source" "$staged"
    mv -T -- "$staged" "$dest"
    log "Linked $dest -> $source"
}

discover_environment() {
    local utility tag
    # Discovery and preflight precede installation. No package-manager or root actions.
    [[ $(uname -s) == Linux ]] || die 'This installer supports Linux only.'
    [[ ${BASH_VERSINFO[0]} -ge 4 ]] || die 'Bash 4 or newer is required.'
    [[ -n ${HOME:-} && "$HOME" == /* && -d "$HOME" ]] || die 'HOME must name an existing absolute directory.'
    if "$INTERACTIVE"; then
        [[ -t 0 && -t 2 ]] || die '--interactive requires stdin and stderr terminals.'
    fi
    case $(uname -m) in
        x86_64 | amd64)
            NVIM_ARCH=x86_64
            LUALS_ARCH=x64
            ;;
        aarch64 | arm64)
            NVIM_ARCH=arm64
            LUALS_ARCH=arm64
            ;;
        *) die "Unsupported architecture $(uname -m). Use a distro package or source build; this script needs 64-bit x86/ARM upstream binaries." ;;
    esac
    for utility in jq tar gzip sha256sum flock readlink dirname mkdir mktemp mv ln rm date cat; do require_command "$utility"; done
    if command -v curl >/dev/null 2>&1; then
        FETCHER=curl
    elif command -v wget >/dev/null 2>&1; then
        FETCHER=wget
    else
        die 'Install curl or wget before rerunning.'
    fi
    if ! "$SKIP_PLUGINS"; then
        require_command git
        require_command timeout
    fi
    for tag in "$NVIM_VERSION" "$LUALS_VERSION"; do
        [[ -z "$tag" || "$tag" =~ ^[a-zA-Z0-9][a-zA-Z0-9._+-]*$ ]] || die "Invalid release tag: $tag"
    done
    [[ -z ${NVIM_APPNAME:-} || "$NVIM_APPNAME" == nvim ]] || die 'Unset NVIM_APPNAME; this installer configures nvim.'
}

resolve_configuration() {
    local candidate
    SCRIPT_DIR=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd -P)
    if [[ -z "$CONFIG_SOURCE" ]]; then
        for candidate in "$SCRIPT_DIR" "$SCRIPT_DIR/.."; do
            if [[ -f "$candidate/init.lua" || -f "$candidate/init.vim" ]]; then
                CONFIG_SOURCE=$candidate
                break
            fi
        done
    fi
    [[ -n "$CONFIG_SOURCE" && -d "$CONFIG_SOURCE" ]] || die 'Cannot find the config checkout. Place this script in its root/docs/scripts directory or use --config-dir DIR.'
    CONFIG_SOURCE=$(cd -- "$CONFIG_SOURCE" && pwd -P)
    [[ -f "$CONFIG_SOURCE/init.lua" || -f "$CONFIG_SOURCE/init.vim" ]] || die "No init.lua or init.vim in $CONFIG_SOURCE."
    CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
    [[ "$CONFIG_HOME" == /* ]] || die 'XDG_CONFIG_HOME must be absolute.'
    # Resolve parent aliases before checking whether backing up nvim would move
    # the checkout itself. Do not resolve the final nvim link: it may be correct.
    CONFIG_HOME=$(readlink -m -- "$CONFIG_HOME")
    CONFIG_DEST=$CONFIG_HOME/nvim
    # A parent destination would move the source itself during backup.
    [[ "$CONFIG_SOURCE" != "$CONFIG_DEST" && "$CONFIG_SOURCE" != "$CONFIG_DEST/"* ]] || die 'Config source must be outside the destination; use the original checkout.'
}

prepare_directories() {
    TOOLS_DIR=$HOME/tools
    CACHE_DIR=$HOME/packages
    BIN_DIR=$HOME/bin
    mkdir -p -- "$TOOLS_DIR" "$CACHE_DIR" "$BIN_DIR" "$CONFIG_HOME"
    exec 9>"$TOOLS_DIR/.nvim-setup.lock"
    flock -n 9 || die 'Another Neovim setup is running for this HOME.'
    WORK_DIR=$(mktemp -d "$TOOLS_DIR/.nvim-setup.XXXXXX")
}

report_existing_commands() {
    local spec
    for spec in python3 node nvim lua-language-server; do
        [[ "$spec" != python3 ]] || "$WITH_PYTHON" || continue
        [[ "$spec" != node ]] || "$WITH_NODE" || continue
        if command -v "$spec" >/dev/null 2>&1; then
            log "Detected $spec: $(command -v "$spec")"
        else
            log "Not detected: $spec"
        fi
    done
    log 'Python/Node providers and language-server packages are deferred pending the plugin audit.'
}

check_link_conflicts() {
    local spec source dest
    for spec in config nvim luals; do
        case "$spec" in
            config)
                source=$CONFIG_SOURCE
                dest=$CONFIG_DEST
                ;;
            nvim)
                source=$TOOLS_DIR/nvim/bin/nvim
                dest=$BIN_DIR/nvim
                ;;
            luals)
                "$WITH_LUALS" || continue
                source=$TOOLS_DIR/lua-language-server/bin/lua-language-server
                dest=$BIN_DIR/lua-language-server
                ;;
        esac
        if exists "$dest" && ! correct_link "$source" "$dest"; then
            allow_conflict "$dest"
        fi
    done
}

fetch() {
    local url=$1 dest=$2
    case "$url" in https://api.github.com/* | https://github.com/*) ;; *) die "Unexpected download URL: $url" ;; esac
    if [[ "$FETCHER" == curl ]]; then
        curl --fail --location --silent --show-error \
            --retry 2 --connect-timeout 15 --max-time 300 \
            --proto '=https' --proto-redir '=https' \
            --output "$dest" "$url" || die "Download failed: $url (check connectivity or GitHub rate limits)."
    else
        wget --https-only --timeout=30 --tries=3 -q -O "$dest" "$url" || die "Download failed: $url (check connectivity or GitHub rate limits)."
    fi
}

# GitHub may omit digests on older releases; retain the existing HTTPS fallback.
verify_archive() {
    local archive=$1 digest=$2 asset=$3 sum
    if [[ "$digest" =~ ^sha256:([a-fA-F0-9]{64})$ ]]; then
        sum=$(sha256sum -- "$archive")
        sum=${sum%% *}
        [[ "${sum,,}" == "${BASH_REMATCH[1],,}" ]] || die "Checksum mismatch for $archive; remove the cached archive and retry."
    else
        log "WARNING: No upstream SHA-256 digest for $asset; archive received over HTTPS."
    fi
}

# Validate the staged executable before changing the live installation.
extract_and_validate_release() {
    local archive=$1 stage=$2 strip=$3 name=$4 version=$5
    # Archive contents are upstream release data. Do not restore ownership/modes.
    if ! tar -xzf "$archive" --strip-components="$strip" --no-same-owner --no-same-permissions -C "$stage"; then
        rm -rf -- "$stage"
        die "Cannot extract $archive; remove the cached archive and retry."
    fi
    if [[ ! -x "$stage/bin/$name" ]] || ! "$stage/bin/$name" --version >"$WORK_DIR/version.log" 2>&1; then
        log "Release validation failed (wrong architecture or missing system libraries):"
        [[ ! -f "$WORK_DIR/version.log" ]] || cat "$WORK_DIR/version.log" >&2
        rm -rf -- "$stage"
        die "Cannot run $name $version; previous installation retained."
    fi
}

# Neovim archives have one enclosing directory; LuaLS archives do not.
# Arguments: executable name, GitHub repository, optional tag, architecture,
# and number of archive path components to remove during extraction.
install_tool() {
    local name=$1 repo=$2 tag=$3 arch=$4 strip=$5
    local live="$TOOLS_DIR/$name" api metadata asset url digest version archive stage root executable
    executable="$live/bin/$name"
    if [[ -x "$executable" && -n "$tag" && -f "$live/.setup-release" ]] &&
        [[ $(cat "$live/.setup-release") == "$repo $tag $arch" ]]; then
        "$executable" --version >/dev/null || die "Existing pinned $name cannot run; check system libraries."
        log "Reusing pinned $name $tag"
        return
    fi
    if [[ -x "$executable" && -z "$tag" ]] && ! "$UPDATE"; then
        "$executable" --version >/dev/null || die "Existing $name cannot run; try --update or check system libraries."
        log "Reusing $name: $executable"
        return
    fi
    # Only our symlinks may be automatically replaced. Legacy directories are
    # backed up when --update/pinning is explicitly requested.
    if exists "$live"; then
        if [[ ! -L "$live" || $(readlink -m -- "$live") != "$TOOLS_DIR/.${name}-versions/"* ]]; then
            allow_conflict "$live"
        fi
    fi
    api="https://api.github.com/repos/$repo/releases"
    if [[ -n "$tag" ]]; then
        api+="/tags/$tag"
    else
        api+='/latest'
    fi
    metadata="$WORK_DIR/$name.json"
    fetch "$api" "$metadata"
    version=$(jq -er '.tag_name | select(type == "string" and test("^[a-zA-Z0-9][a-zA-Z0-9._+-]*$"))' "$metadata") || die "Invalid release metadata for $name."
    if [[ -x "$executable" && -f "$live/.setup-release" ]] &&
        [[ $(cat "$live/.setup-release") == "$repo $version $arch" ]]; then
        "$executable" --version >/dev/null || die "Existing $name cannot run; check system libraries."
        log "$name $version is already current."
        return
    fi
    if [[ "$name" == nvim ]]; then
        asset="nvim-linux-$arch.tar.gz"
    else
        asset="lua-language-server-$version-linux-$arch.tar.gz"
    fi
    url=$(jq -er --arg name "$asset" '[.assets[] | select(.name == $name)] | select(length == 1) | .[0].browser_download_url' "$metadata") || die "Release $version lacks $asset; this platform may require a source build."
    digest=$(jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .digest // ""' "$metadata")
    archive="$CACHE_DIR/$name-$version-$arch.tar.gz"
    if [[ ! -f "$archive" ]]; then
        log "Downloading $name $version ($arch)"
        fetch "$url" "$WORK_DIR/archive.part"
        mv -T -- "$WORK_DIR/archive.part" "$archive"
    fi
    verify_archive "$archive" "$digest" "$asset"
    root="$TOOLS_DIR/.${name}-versions"
    mkdir -p -- "$root"
    stage=$(mktemp -d "$root/$version-$arch.XXXXXX")
    extract_and_validate_release "$archive" "$stage" "$strip" "$name" "$version"
    printf '%s %s %s\n' "$repo" "$version" "$arch" >"$stage/.setup-release"
    # No live install is changed until extraction and execution have succeeded.
    if exists "$live" && [[ ! -L "$live" || $(readlink -m -- "$live") != "$root/"* ]]; then
        backup_path "$live"
    fi
    ln -s -- "$stage" "$WORK_DIR/tool-link"
    mv -Tf -- "$WORK_DIR/tool-link" "$live"
    log "Installed $name $version; previous version directories are retained in $root."
}

prepare_process_environment() {
    # PATH change applies only to this process and its children.
    case ":$PATH:" in *":$BIN_DIR:"*) ;; *) log "WARNING: $BIN_DIR is not in your shell PATH. Launch $BIN_DIR/nvim or add it via your dotfiles." ;; esac
    export PATH="$BIN_DIR:$PATH"
    export XDG_CONFIG_HOME="$CONFIG_HOME"
}

bootstrap_plugins() {
    "$SKIP_PLUGINS" && return

    log 'Installing missing Lazy plugins headlessly (15-minute limit).'
    # Configuration must initialize lazy.nvim. Lazy install waits for tasks and
    # avoids sync's clean/update operations. Inspect task errors before exiting;
    # Lazy has no public aggregate error status, so this uses its task objects.
    if ! timeout --kill-after=10s 900s "$BIN_DIR/nvim" --headless \
        -c 'lua
local ok, err = pcall(function()
    if vim.v.errmsg ~= "" then
        error(vim.v.errmsg)
    end

    require("lazy").install({ wait = true, show = false })
    for _, plugin in pairs(require("lazy.core.config").plugins) do
        for _, task in ipairs(plugin._.tasks or {}) do
            if task:has_errors() then
                error("Lazy task failed: " .. plugin.name)
            end
        end
    end
end)

if not ok then
    vim.api.nvim_err_writeln(tostring(err))
    vim.cmd("cquit 1")
end' \
        -c 'qa!'; then
        die 'Plugin bootstrap failed or timed out. Tools/config remain installed; inspect the output and rerun, or use --skip-plugins.'
    fi
}

main() {
    parse_arguments "$@"
    discover_environment
    resolve_configuration
    prepare_directories
    report_existing_commands
    check_link_conflicts

    install_tool nvim neovim/neovim "$NVIM_VERSION" "$NVIM_ARCH" 1
    if "$WITH_LUALS"; then
        install_tool lua-language-server LuaLS/lua-language-server "$LUALS_VERSION" "$LUALS_ARCH" 0
    fi

    link_path "$TOOLS_DIR/nvim/bin/nvim" "$BIN_DIR/nvim"
    if "$WITH_LUALS"; then
        link_path "$TOOLS_DIR/lua-language-server/bin/lua-language-server" "$BIN_DIR/lua-language-server"
    fi
    link_path "$CONFIG_SOURCE" "$CONFIG_DEST"

    prepare_process_environment
    bootstrap_plugins
    log "Setup complete. Run $BIN_DIR/nvim and :checkhealth to audit your configuration's remaining dependencies."
}

main "$@"

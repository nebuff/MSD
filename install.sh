#!/bin/bash
set -euo pipefail

# Print functions for log standardization
log_info() { echo "[INFO] $1"; }
log_success() { echo "[SUCCESS] $1"; }
log_error() { echo "[ERROR] $1" >&2; }

log_info "Starting MSD (MacBook Spotify Downloader) Installation..."
log_info "Credits: Asumi Hoshino"

# 1. Platform Check
if [[ "$(uname)" != "Darwin" ]]; then
    log_error "This script is exclusively designed for macOS (Darwin). Current platform: $(uname)"
    exit 1
fi
log_success "Platform verified as macOS."

# 2. Unattended Homebrew Provisioning
if ! command -v brew >/dev/null 2>&1; then
    log_info "Homebrew not found. Initiating unattended installation..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    log_success "Homebrew installation completed."
else
    log_info "Homebrew is already installed."
fi

# 3. Shell Environment Registration
# Determine the architecture for Homebrew paths
if [[ "$(uname -m)" == "arm64" ]]; then
    BREW_BIN="/opt/homebrew/bin/brew"
else
    BREW_BIN="/usr/local/bin/brew"
fi

if [[ -f "$BREW_BIN" ]]; then
    eval "$("$BREW_BIN" shellenv)"
fi

SHELL_RC=""
if [[ "${SHELL:-/bin/bash}" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "${SHELL:-/bin/bash}" == *"bash"* ]]; then
    if [[ -f "$HOME/.bash_profile" ]]; then
        SHELL_RC="$HOME/.bash_profile"
    else
        SHELL_RC="$HOME/.bashrc"
    fi
else
    SHELL_RC="$HOME/.profile"
fi

if ! grep -q "brew shellenv" "$SHELL_RC" 2>/dev/null; then
    log_info "Injecting Homebrew shell environment into $SHELL_RC..."
    echo "" >> "$SHELL_RC"
    echo "# Homebrew environment injected by MSD Installer" >> "$SHELL_RC"
    echo "eval \"\$($BREW_BIN shellenv)\"" >> "$SHELL_RC"
    log_success "Homebrew environment registered in $SHELL_RC."
else
    log_info "Homebrew shell environment already exists in $SHELL_RC."
fi

# 4. Automated Package Injection
log_info "Synchronizing core dependencies via Homebrew..."
brew install yt-dlp ffmpeg jq curl
log_success "Core dependencies installed successfully."

# 5. Global Execution Target deployment
INSTALL_DIR="$HOME/.local/bin"
log_info "Deploying msd-download to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# Self-extract the script directly to the bin directory to avoid external dependencies
cat << 'EOF' > "$INSTALL_DIR/msd-download"
#!/bin/bash
set -euo pipefail

# Configuration
LAVALINK_URL="${LAVALINK_URL:-http://localhost:2333}"
LAVALINK_PASSWORD="${LAVALINK_PASSWORD:-youshallnotpass}"
DOWNLOAD_BASE_DIR="$HOME/Downloads/Spotify-Downloads"

# Print functions for log standardization
log_info() { echo "[INFO] $1"; }
log_success() { echo "[SUCCESS] $1"; }
log_error() { echo "[ERROR] $1" >&2; }
log_debug() { echo "[DEBUG] $1"; }

SPOTIFY_URL=""
CSV_FILE=""
CSV_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -csv)
            if [[ -z "${2:-}" ]]; then
                log_error "Missing file path for -csv"
                exit 1
            fi
            CSV_FILE="${2/#\~/$HOME}"
            shift 2
            ;;
        -csv-dir)
            if [[ -z "${2:-}" ]]; then
                log_error "Missing directory path for -csv-dir"
                exit 1
            fi
            CSV_DIR="${2/#\~/$HOME}"
            shift 2
            ;;
        -d)
            if [[ -z "${2:-}" ]]; then
                log_error "Missing directory path for -d"
                exit 1
            fi
            DOWNLOAD_BASE_DIR="${2/#\~/$HOME}"
            shift 2
            ;;
        *)
            SPOTIFY_URL="$1"
            shift
            ;;
    esac
done

if [[ -z "$SPOTIFY_URL" && -z "$CSV_FILE" && -z "$CSV_DIR" ]]; then
    log_error "Usage: msd-download [-csv <file>] [-csv-dir <dir>] [-d <dir>] [<spotify-link>]"
    exit 1
fi

process_url() {
    local url="$1"

    if [[ ! "$url" =~ open\.spotify\.com/(track|album|artist|playlist)/([a-zA-Z0-9]+) ]]; then
        log_error "Invalid Spotify URL format: $url"
        return 1
    fi

    local SPOTIFY_TYPE="${BASH_REMATCH[1]}"
    local SPOTIFY_ID="${BASH_REMATCH[2]}"

    log_info "Detected Spotify ${SPOTIFY_TYPE} with ID: ${SPOTIFY_ID}"

    case "$SPOTIFY_TYPE" in
        track)
            process_track "$url"
            ;;
        album)
            process_album "$url"
            ;;
        artist)
            process_artist "$url"
            ;;
        *)
            log_error "Unsupported Spotify link type: $SPOTIFY_TYPE"
            return 1
            ;;
    esac
}

fetch_spotify_metadata() {
    local url="$1"
    local html_content
    html_content=$(curl -sSL -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" "$url")

    local title artist album cover_url

    # Use grep -Eo and sed to extract metadata (macOS compatible)
    title=$(echo "$html_content" | grep -Eo '<meta property="og:title" content="[^"]*"' | head -n 1 | sed 's/<meta property="og:title" content="//;s/"$//')

    local desc
    desc=$(echo "$html_content" | grep -Eo '<meta property="og:description" content="[^"]*"' | head -n 1 | sed 's/<meta property="og:description" content="//;s/"$//')

    if [[ "$desc" == *"·"* ]]; then
        artist=$(echo "$desc" | awk -F' · ' '{print $1}')
    else
        artist="Unknown Artist"
    fi

    album=$(echo "$html_content" | grep -Eo '<meta name="music:album" content="[^"]*"' | head -n 1 | sed 's/<meta name="music:album" content="//;s/"$//' || true)
    cover_url=$(echo "$html_content" | grep -Eo '<meta property="og:image" content="[^"]*"' | head -n 1 | sed 's/<meta property="og:image" content="//;s/"$//' || true)

    # Clean up Album URL if it extracted an actual URL instead of text
    if [[ "$album" == "http"* ]]; then
        album="Single"
    fi

    if [[ -z "$album" ]]; then
        album="Single"
    fi

    if [[ -z "$title" ]]; then
        log_error "Failed to extract metadata from Spotify URL: $url"
        return 1
    fi

    echo "${title}|${artist}|${album}|${cover_url}"
}

query_lavalink() {
    local search_query="$1"
    local response

    if ! response=$(curl -sS -G --data-urlencode "identifier=ytsearch:${search_query}" \
        -H "Authorization: ${LAVALINK_PASSWORD}" \
        "${LAVALINK_URL}/v4/loadtracks" 2>/dev/null); then
        log_error "Failed to connect to Lavalink node at ${LAVALINK_URL}"
        return 1
    fi

    local track_uri
    track_uri=$(echo "$response" | jq -r '.data[0].info.uri // empty')

    if [[ -z "$track_uri" || "$track_uri" == "null" ]]; then
        log_error "Lavalink could not find a stream for: $search_query"
        return 1
    fi

    echo "$track_uri"
}

process_track() {
    local url="$1"
    log_info "Fetching metadata for track: $url"

    local meta
    if ! meta=$(fetch_spotify_metadata "$url"); then
        return 1
    fi

    local track_title artist album cover_url
    track_title=$(echo "$meta" | cut -d'|' -f1)
    artist=$(echo "$meta" | cut -d'|' -f2)
    album=$(echo "$meta" | cut -d'|' -f3)
    cover_url=$(echo "$meta" | cut -d'|' -f4)

    log_success "Resolved: $track_title by $artist (Album: $album)"

    local search_query="${track_title} ${artist}"
    log_info "Querying Lavalink node for source stream..."

    local source_url
    if ! source_url=$(query_lavalink "$search_query"); then
        return 1
    fi

    log_success "Found source stream: $source_url"

    local safe_artist
    safe_artist=$(echo "$artist" | tr -d ':/\\')
    local safe_album
    safe_album=$(echo "$album" | tr -d ':/\\')
    local safe_title
    safe_title=$(echo "$track_title" | tr -d ':/\\')

    local output_dir="${DOWNLOAD_BASE_DIR}/${safe_artist}/${safe_album}"
    mkdir -p "$output_dir"

    log_info "Downloading with yt-dlp to: $output_dir"

    if yt-dlp -f "ba" \
           -x --audio-format mp3 --audio-quality 0 \
           --embed-metadata \
           --replace-in-metadata "title" ".*" "$track_title" \
           --replace-in-metadata "artist" ".*" "$artist" \
           --replace-in-metadata "album" ".*" "$album" \
           -o "${output_dir}/${safe_title}.%(ext)s" \
           "$source_url" > /dev/null 2>&1; then
        log_success "Download completed for: $track_title"
    else
        log_error "Download failed for: $track_title"
    fi
}

process_album() {
    local url="$1"
    log_info "Fetching album tracks..."
    local html_content
    html_content=$(curl -sSL -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" "$url")

    local track_urls
    # macOS compatible grep
    track_urls=$(echo "$html_content" | grep -Eo '<meta name="music:song" content="[^"]*"' | sed 's/<meta name="music:song" content="//;s/"$//')

    if [[ -z "$track_urls" ]]; then
        log_error "No tracks found for album."
        exit 1
    fi

    while IFS= read -r track_url; do
        if [[ -n "$track_url" ]]; then
            process_track "$track_url" || true
        fi
    done <<< "$track_urls"

    log_success "Album processing finished."
}

process_artist() {
    local url="$1"
    log_info "Fetching artist top tracks..."
    local html_content
    html_content=$(curl -sSL -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" "$url")

    local track_ids
    # Extract unique track IDs from the artist page
    track_ids=$(echo "$html_content" | grep -Eo 'spotify:track:[a-zA-Z0-9]+' | sed 's/spotify:track://' | sort | uniq)

    if [[ -z "$track_ids" ]]; then
        log_error "No tracks found for artist."
        exit 1
    fi

    while IFS= read -r tid; do
        if [[ -n "$tid" ]]; then
            process_track "https://open.spotify.com/track/$tid" || true
        fi
    done <<< "$track_ids"

    log_success "Artist processing finished."
}

process_csv_file() {
    local file="$1"
    log_info "Processing URLs from CSV file: $file"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ https?://open\.spotify\.com/(track|album|artist|playlist)/[a-zA-Z0-9]+ ]]; then
            process_url "${BASH_REMATCH[0]}"
        elif [[ "$line" =~ spotify:(track|album|artist|playlist):([a-zA-Z0-9]+) ]]; then
            process_url "https://open.spotify.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        fi
    done < "$file"
}

# Execution Flow
log_info "Engine initialized. Credits: Asumi Hoshino"

if [[ -n "$CSV_FILE" ]]; then
    if [[ ! -f "$CSV_FILE" ]]; then
        log_error "CSV file not found: $CSV_FILE"
        exit 1
    fi
    process_csv_file "$CSV_FILE"
fi

if [[ -n "$CSV_DIR" ]]; then
    if [[ ! -d "$CSV_DIR" ]]; then
        log_error "CSV directory not found: $CSV_DIR"
        exit 1
    fi
    log_info "Processing all CSV files in directory: $CSV_DIR"
    find "$CSV_DIR" -maxdepth 1 -name "*.csv" -print0 | while IFS= read -r -d '' file; do
        process_csv_file "$file"
    done
fi

if [[ -n "$SPOTIFY_URL" ]]; then
    process_url "$SPOTIFY_URL" || exit 1
fi

log_success "All tasks completed."
EOF

chmod +x "$INSTALL_DIR/msd-download"

if ! grep -q "$INSTALL_DIR" "$SHELL_RC" 2>/dev/null; then
    log_info "Injecting $INSTALL_DIR into PATH..."
    echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$SHELL_RC"
    export PATH="$INSTALL_DIR:$PATH"
fi

log_success "Deployment of msd-download complete."
log_info "Installation finished! You can now use 'msd-download <spotify-link>'."

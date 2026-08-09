# MSD (MacBook Spotify Downloader)

# THIS WAS MADE BY AI, This project was made by AI when I was using it for code creation, I do not LIKE AI, But for small scripts I do use it time to time, Remember, IF I used AI on a project, I will SAY, Since AI is trained on copyrighted content, And are litterally sucking up our ocean, In the meantime, I have entirely Stopped using AI

## Prerequisite Baselines

1. **Operating System:** macOS (Darwin)
2. **Architecture:** Native compatibility configured for both Apple Silicon (`arm64`) and Intel (`x86_64`) instruction sets
3. **Execution Environment:** Compatible with bash and zsh terminal
4. **Lavalink Server:** A valid, accessible Lavalink node (v4) is required

## Installation Sequence

The installation script is executed via a clean, unattended shell sequence. It will provision Homebrew if missing, synchronize environment paths, install all core dependencies, and compile the global executable.

```bash
curl -sSL https://raw.githubusercontent.com/nebuff/MSD/main/install.sh | bash
```

## System Configuration

The engine relies on structural environment variables to resolve its target Lavalink architecture. You can inject these directly into your terminal profile (`~/.zshrc` or `~/.bash_profile`) or declare them inline at execution.

```bash
export LAVALINK_URL="http://127.0.0.1:2333"
export LAVALINK_PASSWORD="youshallnotpass"
```

## Terminal Usage Examples

The core engine is compiled and executed via the `msd-download` alias.

Execute a single track resolution and download:
```bash
msd-download "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqThttps://open.spotify.com/track/3yCKJlbaX60oX6K4mgurgz?si=1fdaca45d3dc47d0"
```

Execute an album download loop:
```bash
msd-download "https://open.spotify.com/album/4eLPsYPBmXABThSJ821sqYhttps://open.spotify.com/album/6bgUdri7frTG9Aqo3Xusw7?si=ed59d81eea954bef"
```

Execute an artist download loop:

```bash
msd-download "https://open.spotify.com/artist/2YZyLoL8N0Wb9xBt1NhZWghttps://open.spotify.com/artist/7kZTWx6cRLc0TSRPq1XBMP?si=f2e9e82afbfe45ce"
```

Execute batch download via CSV:
```bash
msd-download -csv "~/Documents/music.csv"
```

Execute batch download via a directory of CSV files:
```bash
msd-download -csvd "~/Documents/Spotify Playlists"
```

Execute batch download via CSV to a specific directory:
```bash
msd-download -csv "~/Documents/music.csv" -d "~/Music"
```

Execute a single track resolution to a specific directory:
```bash
msd-download -d "~/Music" "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqThttps://open.spotify.com/track/3yCKJlbaX60oX6K4mgurgz?si=1fdaca45d3dc47d0"
```

*Note: Execution will yield formatted Unix output headers: `[INFO]`, `[SUCCESS]`, `[ERROR]`, `[DEBUG]` for strict tracking.*

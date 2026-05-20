#!/usr/bin/env bash

# Unified Compiler Benchmark Installer
# Targets: Ubuntu (22.04+) and Arch Linux (Stable)

set -euo pipefail

# --- 1. Argument Parsing & Help ---
show_help() {
    echo "Usage: $0 --languages=[LIST|all]"
    echo ""
    echo "Options:"
    echo "  --languages=all     Install all available languages and tools."
    echo "  --languages=LIST    Comma-separated list of specific languages to install."
    echo "  --help              Show this help message."
    echo ""
    echo "Available Language Keys:"
    echo "  gcc, llvm, repo, csharp, dmd, rust, nim, c3, vlang, zig, circle, swift, vox"
    echo ""
    echo "Examples:"
    echo "  $0 --languages=all"
    echo "  $0 --languages=zig,rust,c3"
    exit 0
}

# Default: Install nothing unless specified
INSTALL_ALL=false
declare -A SELECTED

if [ $# -eq 0 ]; then
    show_help
fi

for i in "$@"; do
    case $i in
        --languages=*)
        REQUESTED_LANGS="${i#*=}"
        if [ "$REQUESTED_LANGS" == "all" ]; then
            INSTALL_ALL=true
        else
            IFS=',' read -ra ADDR <<< "$REQUESTED_LANGS"
            for lang in "${ADDR[@]}"; do
                SELECTED[$(echo "$lang" | tr '[:upper:]' '[:lower:]')]=true
            done
        fi
        shift
        ;;
        --help)
            show_help
            ;;
        *)
        # Ignore unknown flags or handle error
        ;;
    esac
done

# Check if anything was actually selected
if [ "$INSTALL_ALL" = false ] && [ ${#SELECTED[@]} -eq 0 ]; then
    echo "Error: No languages specified."
    show_help
fi

should_install() {
    [[ "$INSTALL_ALL" == "true" ]] && return 0
    [[ -n "${SELECTED[$1]:-}" ]] && return 0
    return 1
}

# --- 2. Path & Environment Setup ---
INSTALL_DIR="${HOME}/.local"
BIN_DIR="${INSTALL_DIR}/bin"
mkdir -p "$BIN_DIR"

export PATH="${BIN_DIR}:${HOME}/.cargo/bin:${HOME}/.nimble/bin:${PATH}"

# --- 3. OS Detection ---
if [ -f /etc/arch-release ]; then
    OS="arch"
    PKG_MAN="sudo pacman -S --noconfirm --needed"
    echo ">> System: Arch Linux detected."
elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
    OS="ubuntu"
    PKG_MAN="sudo apt-get install -y"
    echo ">> System: Ubuntu/Debian detected."
else
    echo "Unsupported OS. Script optimized for Arch and Ubuntu."
    exit 1
fi

# --- 4. Base Build Essentials (Always Installed if any language is chosen) ---
echo ">> Installing Base Build Tools..."
if [ "$OS" == "arch" ]; then
    ${PKG_MAN} base-devel git curl wget unzip tar xz lld
else
    ${PKG_MAN} build-essential git curl wget unzip tar xz-utils software-properties-common lld
fi

# --- 5. GCC Suite (C, C++, Go, Ada, D) ---
if should_install "gcc"; then
    echo ">> Installing GCC Suite..."
    if [ "$OS" == "arch" ]; then
        ${PKG_MAN} gcc gcc-ada gcc-d gcc-go
    else
        ${PKG_MAN} gcc g++ gnat gdc gccgo
    fi
fi

# --- 6. LLVM / Clang (Version 17+) ---
if should_install "llvm"; then
    echo ">> Installing LLVM/Clang..."
    if [ "$OS" == "arch" ]; then
        ${PKG_MAN} clang lld llvm
    else
        CODENAME=$(lsb_release -cs)
        wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo apt-key add -
        sudo add-apt-repository -y "deb http://apt.llvm.org/${CODENAME}/ llvm-toolchain-${CODENAME}-17 main"
        sudo apt update
        ${PKG_MAN} clang-17 lld-17 llvm-17-dev
        sudo ln -sf /usr/bin/clang-17 /usr/bin/clang
        sudo ln -sf /usr/bin/clang++-17 /usr/bin/clang++
        sudo ln -sf /usr/bin/lld-17 /usr/bin/lld
    fi
fi

# --- 7. Repository Languages (Java, Julia, OCaml, Python, Scheme, TCC) ---
if should_install "repo"; then
    echo ">> Installing Repository Languages..."
    if [ "$OS" == "arch" ]; then
        ${PKG_MAN} jdk-openjdk julia ocaml python-psutil chezscheme tcc go
    else
        ${PKG_MAN} openjdk-21-jdk julia ocaml python3-psutil chezscheme tcc golang-go
    fi
fi

# --- 8. C# (Mono & .NET SDK) ---
if should_install "csharp"; then
    echo ">> Installing C# environment..."
    if [ "$OS" == "arch" ]; then
        ${PKG_MAN} mono dotnet-sdk
    else
        sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
        echo "deb https://download.mono-project.com/repo/ubuntu stable-focal main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
        sudo apt update
        ${PKG_MAN} mono-devel
        sudo snap install --classic dotnet-sdk || echo "Skipping dotnet snap - please install manually"
    fi
fi

# --- 9. DMD (D Language) ---
if should_install "dmd"; then
    echo ">> Installing DMD..."
    if [ "$OS" == "arch" ]; then
        ${PKG_MAN} dmd
    else
        DMD_VER=$(wget -q -O - "https://dlang.org/download.html" | grep -oP 'releases/2.x/\K\d+\.\d+\.\d+(?=/dmd_)' | head -n 1)
        ARCH_S=$( [ "$(uname -m)" == "x86_64" ] && echo "amd64" || echo "i386" )
        wget -q --show-progress "http://downloads.dlang.org/releases/2.x/${DMD_VER}/dmd_${DMD_VER}-0_${ARCH_S}.deb" -O /tmp/dmd.deb
        sudo dpkg -i /tmp/dmd.deb || sudo apt-get install -f -y
    fi
fi

# --- 10. Rust & Nim ---
if should_install "nim"; then
    echo ">> Installing Nim..."
    curl https://nim-lang.org/choosenim/init.sh -sSf | sh -s -- -y
fi

if should_install "rust"; then
    echo ">> Installing Rust..."
    curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain nightly
fi

# --- 11. Binary-distributed languages ---
if should_install "c3"; then
    echo ">> Installing C3..."
    curl -fsSL https://raw.githubusercontent.com/c3lang/c3c/refs/heads/master/install/install.sh | C3_VERSION=0.7.8 bash
fi

if should_install "vlang"; then
    echo ">> Installing Vlang..."
    V_ZIP=$(mktemp /tmp/vlang.XXXXXX.zip)
    curl -s -L -o "$V_ZIP" "https://github.com/vlang/v/releases/latest/download/v_linux.zip"
    unzip -o -qq "$V_ZIP" -d "$INSTALL_DIR"
    rm "$V_ZIP"
fi

if should_install "zig"; then
    echo ">> Installing Zig..."
    ZIG_URL=$(curl -s https://ziglang.org/download/index.json | grep -oP '"tarball":\s*"\Khttps://ziglang.org/builds/zig-linux-x86_64-[^"]+' | head -n 1)
    wget -q --show-progress -c "$ZIG_URL" -O - | tar -xJ -C "$INSTALL_DIR"
fi

if should_install "circle"; then
    echo ">> Installing Circle..."
    CIRCLE_VER=$(wget -q -O - "https://www.circle-lang.org/linux/" | grep -oP 'build_\K\d+(?=\.tgz)' | sort -nr | head -n 1)
    wget -q --show-progress -c "https://www.circle-lang.org/linux/build_${CIRCLE_VER}.tgz" -O - | tar -xz -C "${INSTALL_DIR}"
fi

if should_install "swift"; then
    echo ">> Installing Swift..."
	if [ "$OS" == "arch" ]; then
        ${PKG_MAN} swift-bin
    else
		SWIFT_URL="https://download.swift.org/swift-6.3.2-release/ubuntu2204/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE-ubuntu22.04.tar.gz"
		wget -q --show-progress -c "$SWIFT_URL" -O - | tar -xz -C "$INSTALL_DIR"
    fi
fi

# --- 12. Vox (Build from source) ---
if should_install "vox"; then
    echo ">> Building Vox..."
    if [ "$OS" == "arch" ]; then ${PKG_MAN} ldc; else ${PKG_MAN} ldc; fi

    VOX_TMP=$(mktemp -d)
    git clone --depth 1 https://github.com/MrSmith33/vox "$VOX_TMP"
    pushd "$VOX_TMP/source"
    ldc2 -d-version=cli -m64 -O3 -release -boundscheck=off -enable-inlining -flto=full -i main.d -of=vox.out
    cp vox.out "$BIN_DIR/vox"
    popd
    rm -rf "$VOX_TMP"
fi

# --- Finalization ---
echo "--------------------------------------------------------"
echo "✅ Requested installations complete for $OS!"
echo "--------------------------------------------------------"
echo "IMPORTANT: Ensure your PATH includes these directories:"
echo 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.nimble/bin:$PATH"'

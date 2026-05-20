#!/usr/bin/env bash

# Unified Compiler Benchmark Installer
# Targets: Ubuntu (22.04+) and Arch Linux (Stable)

set -euo pipefail

show_help() {
    echo "Usage: $0 --languages=[LIST|all]"
    echo ""
    echo "Options:"
    echo "  --languages=all     Install all available languages and tools."
    echo "  --languages=LIST    Comma-separated list of specific languages to install."
    echo "  --help              Show this help message."
    echo ""
    echo "Available Language Keys:"
    echo "  gcc, llvm, repo, csharp, dmd, rust, nim, c3, vlang, zig, circle, swift, vox, cproc"
    echo ""
    echo "Examples:"
    echo "  $0 --languages=all"
    echo "  $0 --languages=zig,rust,c3,cproc"
    exit 0
}

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

if [ "$INSTALL_ALL" = false ] && [ ${#SELECTED[@]} -eq 0 ]; then
    echo "Error: No languages specified."
    show_help
fi

should_install() {
    [[ "$INSTALL_ALL" == "true" ]] && return 0
    [[ -n "${SELECTED[$1]:-}" ]] && return 0
    return 1
}

INSTALL_DIR="${HOME}/.local"
BIN_DIR="${INSTALL_DIR}/bin"
mkdir -p "$BIN_DIR"

export PATH="${BIN_DIR}:${HOME}/.cargo/bin:${HOME}/.nimble/bin:${PATH}"

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

echo ">> Installing Base Build Tools..."
if [ "$OS" == "arch" ]; then
    ${PKG_MAN} base-devel git curl wget unzip tar xz lld
else
    ${PKG_MAN} build-essential git curl wget unzip tar xz-utils software-properties-common lld
fi

# GCC Suite (C, C++, Go, Ada, D)
if should_install "gcc"; then
    echo ">> Installing GCC Suite..."
    if [ "$OS" == "arch" ]; then
        ${PKG_MAN} gcc gcc-ada gcc-d gcc-go
    else
        ${PKG_MAN} gcc g++ gnat gdc gccgo
    fi
fi

# LLVM / Clang
if should_install "llvm"; then
    echo ">> Installing LLVM/Clang..."
    if [ "$OS" == "arch" ]; then
        ${PKG_MAN} clang lld llvm
    else
        ${PKG_MAN} clang lld
    fi
fi

# Repository Languages (Java, Julia, OCaml, Python, Scheme, TCC)
if should_install "repo"; then
    echo ">> Installing Repository Languages..."
    if [ "$OS" == "arch" ]; then
        ${PKG_MAN} jdk-openjdk julia ocaml python-psutil chezscheme tcc go
    else
        ${PKG_MAN} openjdk-21-jdk julia ocaml python3-psutil chezscheme tcc golang-go
    fi
fi

# C# (Mono & .NET SDK) ---
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

if should_install "nim"; then
    echo ">> Installing Nim..."
    curl https://nim-lang.org/choosenim/init.sh -sSf | sh -s -- -y
fi

if should_install "rust"; then
    echo ">> Installing Rust..."
    curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain nightly
fi

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
    if [ "$OS" == "arch" ]; then
        ${PKG_MAN} zig
    else
		ZIG_URL=$(curl -s https://ziglang.org/download/index.json | grep -oP '"tarball":\s*"\Khttps://ziglang.org/builds/zig-linux-x86_64-[^"]+' | head -n 1)
		wget -q --show-progress -c "$ZIG_URL" -O - | tar -xJ -C "$INSTALL_DIR"
    fi
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
		SWIFT_URL=https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz
		wget -q --show-progress -c "$SWIFT_URL" -O - | tar -xz -C "$INSTALL_DIR" && \
			"$INSTALL_DIR/swiftly" init --quiet-shell-followup && \
			. "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" && \
			hash -r
    fi
fi

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

if should_install "cproc"; then
    echo ">> Building cproc..."
    echo ">> Installing QBE (dependency for cproc)..."
    if [ "$OS" == "arch" ]; then
        ${PKG_MAN} qbe
    else
        # For Ubuntu, qbe is available in 22.04+
        ${PKG_MAN} qbe || {
            echo "QBE not found in repos, building from source..."
            QBE_TMP=$(mktemp -d)
            git clone --depth 1 git://c3d.libre.cc/qbe.git "$QBE_TMP"
            make -C "$QBE_TMP"
            cp "$QBE_TMP/qbe" "$BIN_DIR/"
            rm -rf "$QBE_TMP"
        }
    fi
    CPROC_TMP=$(mktemp -d)
    git clone --depth 1 https://github.com/michaelforney/cproc "$CPROC_TMP"
    pushd "$CPROC_TMP"
    ./configure --prefix="$INSTALL_DIR"
    make
    make install
    popd
    rm -rf "$CPROC_TMP"
fi

if should_install "cuik"; then
    echo ">> Building Cuik..."
    CUIK_TMP=$(mktemp -d)
    git clone --depth 1 https://github.com/RealNeGate/Cuik/ "$CUIK_TMP"
    pushd "$CUIK_TMP"
	sed -i '1i #include <ctype.h>' common/common.c
	sed -i '1i #include <ctype.h>' tb/x64/x64_gen.h
	sed -i '1i #include <stddef.h>' tb/libtb.c
	sed -i 's/static TB_Node\* make_int_node/TB_Node\* make_int_node/g' tb/new_builder.c
	find . -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's/__debugbreak/__builtin_trap/g' {} +
	CFLAGS="-D__debugbreak=__builtin_trap -include ctype.h" \
		  luajit build.lua -x64 -driver -cuik -tb
fi

# --- Finalization ---
echo "--------------------------------------------------------"
echo "✅ Requested installations complete for $OS!"
echo "--------------------------------------------------------"
echo "IMPORTANT: Ensure your PATH includes these directories:"
echo 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.nimble/bin:$PATH"'

#!/bin/bash
# mint_sec_tools.sh - Linux Mint 渗透测试/CTF 工具一键安装脚本
# 适用: Linux Mint 21.x / 22.x (基于 Ubuntu 22.04/24.04)
# 用法: sudo bash mint_sec_tools.sh

set -euo pipefail

# ==================== 颜色输出 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; }
step() { echo -e "${BLUE}[*]${NC} $1"; }
detail() { echo -e "${CYAN}   ->${NC} $1"; }

# ==================== 全局变量 ====================
FAILED_PKGS=()
SKIPPED_PKGS=()
TMP_FILES=()
WARNINGS=()

# ==================== 清理函数 ====================
cleanup() {
    local exit_code=$?
    if [[ ${#TMP_FILES[@]} -gt 0 ]]; then
        info "清理临时文件..."
        for f in "${TMP_FILES[@]}"; do
            [[ -f "$f" ]] && rm -f "$f"
            [[ -d "$f" ]] && rm -rf "$f"
        done
    fi

    if [[ $exit_code -ne 0 ]]; then
        error "脚本异常退出 (代码: $exit_code)"
        info "已完成的操作不会回滚，请检查日志"
    fi
}
trap cleanup EXIT

# ==================== 检查 root ====================
if [[ "$EUID" -ne 0 ]]; then
    error "请使用 root 权限运行: sudo $0"
    exit 1
fi

# ==================== 检测系统 ====================
detect_system() {
    step "检测系统环境..."

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO="$ID"
        VERSION_ID="$VERSION_ID"
        info "检测到系统: $NAME $VERSION_ID"
    else
        error "无法检测发行版"
        exit 1
    fi

    # 确认是 Mint
    if [[ "$DISTRO" != "linuxmint" ]]; then
        warn "当前不是 Linux Mint ($DISTRO)，脚本为 Mint 优化"
        read -p "是否继续? [y/N] " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi

    # 检测 Mint 版本对应的 Ubuntu 基础
    if [[ "$VERSION_ID" =~ ^21 ]]; then
        UBUNTU_BASE="jammy"
        info "基于 Ubuntu 22.04 LTS (Jammy)"
    elif [[ "$VERSION_ID" =~ ^22 ]]; then
        UBUNTU_BASE="noble"
        info "基于 Ubuntu 24.04 LTS (Noble)"
    else
        warn "未测试的 Mint 版本，使用通用配置"
        UBUNTU_BASE="jammy"
    fi

    # 检测架构
    ARCH=$(dpkg --print-architecture)
    info "架构: $ARCH"

    # 确定目标用户（处理 sudo 和 su 两种情况）
    TARGET_USER="${SUDO_USER:-$USER}"
    if [[ "$TARGET_USER" == "root" && -n "${SUDO_USER:-}" ]]; then
        TARGET_USER="$SUDO_USER"
    fi
    info "目标用户: $TARGET_USER"
}

# ==================== 安全安装函数 ====================
safe_apt_install() {
    local pkg="$1"
    if apt-cache show "$pkg" &>/dev/null; then
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            detail "$pkg 已安装，跳过"
        else
            detail "安装 $pkg..."
            apt install -y "$pkg" || {
                warn "$pkg 安装失败"
                FAILED_PKGS+=("$pkg")
            }
        fi
    else
        warn "仓库中找不到包: $pkg，跳过"
        SKIPPED_PKGS+=("$pkg")
    fi
}

# ==================== 批量安全安装 ====================
batch_apt_install() {
    local category="$1"
    shift
    step "安装 $category..."
    for pkg in "$@"; do
        safe_apt_install "$pkg"
    done
}

# ==================== 更新系统 ====================
update_system() {
    step "更新软件源..."
    apt update

    step "是否升级系统包? (建议，可跳过)"
    read -p "升级系统包? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        info "跳过系统升级"
    else
        apt upgrade -y || warn "系统升级失败"
    fi
}

# ==================== 基础依赖 ====================
install_base() {
    batch_apt_install "基础依赖" \
        curl wget git vim build-essential \
        python3 python3-pip python3-venv python3-dev \
        net-tools iputils-ping dnsutils \
        software-properties-common apt-transport-https \
        ca-certificates gnupg lsb-release \
        tmux screen htop tree \
        jq bat exa fd-find ripgrep

    # bat 软链接（仅创建一次）
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        if [[ ! -L /usr/local/bin/bat ]]; then
            ln -sf "$(which batcat)" /usr/local/bin/bat
            info "已创建 bat 快捷方式"
        fi
    fi
}

# ==================== 信息收集 ====================
install_recon() {
    batch_apt_install "信息收集工具" \
        nmap nmap-common \
        wireshark tshark tcpdump \
        dnsrecon dnsenum \
        theharvester \
        recon-ng \
        arp-scan \
        whois \
        netdiscover \
        masscan

    # wireshark 非 root 权限配置
    if [[ -f /usr/bin/dumpcap ]]; then
        setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap 2>/dev/null || true
        if [[ -n "$TARGET_USER" && "$TARGET_USER" != "root" ]]; then
            usermod -aG wireshark "$TARGET_USER" 2>/dev/null || true
            info "已将 $TARGET_USER 加入 wireshark 组"
        fi
    fi
}

# ==================== Web 渗透 ====================
install_web() {
    batch_apt_install "Web 渗透工具" \
        sqlmap \
        zaproxy \
        gobuster \
        nikto \
        wpscan \
        dirb \
        whatweb

    # ffuf：优先从仓库，其次源码编译
    if ! command -v ffuf &>/dev/null; then
        if apt-cache show ffuf &>/dev/null; then
            safe_apt_install "ffuf"
        else
            info "仓库无 ffuf，尝试从 GitHub 编译安装..."
            if command -v go &>/dev/null; then
                local ffuf_tmp
                ffuf_tmp=$(mktemp -d)
                TMP_FILES+=("$ffuf_tmp")
                if git clone --depth 1 https://github.com/ffuf/ffuf.git "$ffuf_tmp" 2>/dev/null; then
                    (cd "$ffuf_tmp" && go build -o /usr/local/bin/ffuf) && info "ffuf 编译安装成功" || warn "ffuf 编译失败"
                else
                    warn "ffuf 下载失败，请手动安装"
                fi
            else
                warn "Go 未安装，跳过 ffuf 源码编译（将在 Go 工具阶段安装）"
            fi
        fi
    fi

    # Burp Suite 提示
    if ! command -v burpsuite &>/dev/null; then
        warn "Burp Suite Community 不在仓库中"
        info "请手动下载: https://portswigger.net/burp/communitydownload"
        info "或使用: sudo snap install burpsuite"
    fi
}

# ==================== 无线安全 ====================
install_wireless() {
    batch_apt_install "无线安全工具" \
        aircrack-ng \
        reaver \
        mdk4 \
        kismet \
        hcxdumptool \
        hcxtools \
        pixiewps \
        bully

    # 检查无线网卡
    if ip link show 2>/dev/null | grep -qi wlan; then
        info "检测到无线网卡"
    else
        warn "未检测到无线网卡，aircrack-ng 等工具可能无法使用"
    fi
}

# ==================== 密码破解 ====================
install_password() {
    batch_apt_install "密码破解工具" \
        hashid \
        john john-data \
        hydra \
        hashcat hashcat-data \
        crunch \
        cewl \
        wordlists \
        rsmangler

    # 下载/解压 rockyou 字典
    local dict_dir="/usr/share/wordlists"
    mkdir -p "$dict_dir"

    if [[ ! -f "$dict_dir/rockyou.txt" ]]; then
        if [[ -f "$dict_dir/rockyou.txt.gz" ]]; then
            info "解压系统自带的 rockyou 字典..."
            gunzip -c "$dict_dir/rockyou.txt.gz" > "$dict_dir/rockyou.txt" && \
                info "rockyou.txt 解压完成" || warn "解压失败"
        else
            info "从网络下载 rockyou 字典..."
            curl -fsSL "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt" \
                -o "$dict_dir/rockyou.txt" && info "rockyou.txt 下载完成" || warn "rockyou.txt 下载失败"
        fi
    fi
}

# ==================== 漏洞利用框架 ====================
install_exploit() {
    step "安装 Metasploit Framework..."

    if command -v msfconsole &>/dev/null; then
        info "Metasploit 已安装"
        if command -v msfupdate &>/dev/null; then
            info "检查更新..."
            msfupdate 2>/dev/null || warn "msfupdate 失败"
        else
            info "msfupdate 不可用（可能是 apt 安装版本），跳过更新"
        fi
        return
    fi

    info "从 Rapid7 官方安装 Metasploit..."
    local msf_installer="/tmp/msfinstall"
    TMP_FILES+=("$msf_installer")

    if curl -fsSL "https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb" \
        -o "$msf_installer"; then
        chmod 755 "$msf_installer"
        "$msf_installer" || {
            error "Metasploit 安装失败"
            warn "备用方案: curl -fsSL https://apt.metasploit.com/install.sh | sudo bash"
        }
    else
        error "下载 Metasploit 安装脚本失败"
        warn "请检查网络连接或手动访问: https://docs.metasploit.com"
    fi
}

# ==================== CTF 辅助工具 ====================
install_ctf() {
    batch_apt_install "CTF 辅助工具" \
        steghide \
        binwalk \
        foremost \
        exiftool \
        libimage-exiftool-perl \
        hexedit \
        bless \
        radare2 \
        gdb gdb-multiarch \
        ltrace \
        strace \
        checksec

    # 安装 GEF (GDB Enhanced Features)
    if command -v gdb &>/dev/null; then
        if [[ ! -f "$HOME/.gdbinit-gef.py" ]]; then
            info "安装 GEF (GDB Enhanced Features)..."
            bash -c "$(curl -fsSL https://gef.blah.cat/sh)" || warn "GEF 安装失败"
        else
            detail "GEF 已安装"
        fi
    fi
}

# ==================== 网络嗅探/欺骗 ====================
install_sniff() {
    batch_apt_install "网络嗅探/欺骗工具" \
        bettercap \
        bettercap-ui \
        ettercap-common \
        ettercap-graphical \
        driftnet \
        responder \
        mitmproxy \
        dsniff
}

# ==================== 编码/密码学 ====================
install_crypto() {
    batch_apt_install "编码/密码学工具" \
        ncrack \
        fcrackzip \
        rarcrack \
        ophcrack \
        ophcrack-cli \
        hashcat-utils \
        base64 \
        xxd \
        openssl \
        gpg \
        outguess

    # medusa 可能在某些仓库不可用
    if apt-cache show medusa &>/dev/null; then
        safe_apt_install "medusa"
    else
        warn "medusa 在仓库中不可用，如需使用请手动编译安装"
    fi
}

# ==================== 逆向/二进制 ====================
install_reverse() {
    batch_apt_install "逆向工程工具" \
        apktool

    # 这些工具通常不在默认仓库
    local extra_pkgs=(ghidra dex2jar jd-gui)
    for pkg in "${extra_pkgs[@]}"; do
        if apt-cache show "$pkg" &>/dev/null; then
            safe_apt_install "$pkg"
        else
            SKIPPED_PKGS+=("$pkg")
        fi
    done

    # 清晰的 Ghidra 安装指引
    if ! command -v ghidra &>/dev/null; then
        warn "Ghidra 不在默认仓库中"
        info "请从 https://ghidra-sre.org 手动下载安装"
        info "下载后解压到 /opt/ghidra，然后创建 /usr/local/bin/ghidra 软链接即可"
    fi
}

# ==================== Python 工具 ====================
install_pip_tools() {
    step "安装 Python 渗透测试工具..."

    local venv_dir="/opt/sec-tools-venv"
    info "创建 Python 虚拟环境: $venv_dir"

    if [[ ! -d "$venv_dir" ]]; then
        python3 -m venv "$venv_dir" || {
            error "创建虚拟环境失败"
            apt install -y python3-venv
            python3 -m venv "$venv_dir"
        }
    fi

    local pip="$venv_dir/bin/pip"
    "$pip" install --upgrade pip setuptools wheel

    # 核心工具列表
    local py_pkgs=(
        requests
        beautifulsoup4
        scrapy
        paramiko
        pwntools
        ropper
        frida-tools
        pycryptodome
        flask
        django
        impacket
        bloodhound
        ldap3
        pyftpdlib
        scapy
        python-nmap
        shodan
        censys
        dnspython
        crackmapexec
    )

    for pkg in "${py_pkgs[@]}"; do
        detail "安装 Python 包: $pkg"
        "$pip" install "$pkg" || {
            warn "$pkg pip 安装失败"
            FAILED_PKGS+=("python:$pkg")
        }
    done

    # 创建全局快捷方式
    local bin_dir="$venv_dir/bin"
    for tool in pwn frida-ps frida-trace frida-discover bloodhound-python crackmapexec; do
        if [[ -f "$bin_dir/$tool" && ! -f "/usr/local/bin/$tool" ]]; then
            ln -sf "$bin_dir/$tool" "/usr/local/bin/$tool"
        fi
    done

    # 添加环境变量
    local profile_file="/etc/profile.d/sec-tools.sh"
    if [[ ! -f "$profile_file" ]]; then
        echo "export PATH=\"/opt/sec-tools-venv/bin:\$PATH\"" > "$profile_file"
        info "已添加 Python 工具到系统 PATH"
    fi
}

# ==================== Go 工具 ====================
install_go_tools() {
    step "安装 Go 语言渗透工具..."

    if ! command -v go &>/dev/null; then
        info "安装 Go 语言环境..."
        if apt install -y golang-go; then
            info "Go 已安装（仓库版本）"
        else
            warn "仓库 Go 安装失败，尝试从官网安装最新版..."

            # 动态获取最新稳定版
            local go_version
            go_version=$(curl -fsSL https://go.dev/VERSION?m=text 2>/dev/null | head -1 | sed 's/go//' || echo "1.22.3")

            if [[ -z "$go_version" || ! "$go_version" =~ ^[0-9] ]]; then
                go_version="1.22.3"
                warn "无法获取最新 Go 版本，使用 fallback: $go_version"
            fi

            local go_tar="/tmp/go${go_version}.linux-${ARCH}.tar.gz"
            TMP_FILES+=("$go_tar")

            if curl -fsSL "https://go.dev/dl/go${go_version}.linux-${ARCH}.tar.gz" -o "$go_tar"; then
                rm -rf /usr/local/go
                tar -C /usr/local -xzf "$go_tar"

                local go_profile="/etc/profile.d/go.sh"
                if [[ ! -f "$go_profile" ]]; then
                    echo 'export PATH=$PATH:/usr/local/go/bin' > "$go_profile"
                fi
                export PATH=$PATH:/usr/local/go/bin
                info "Go $go_version 安装完成"
            else
                error "Go 下载失败，跳过 Go 工具安装"
                return
            fi
        fi
    fi

    # 验证 Go 可用
    if ! command -v go &>/dev/null; then
        error "Go 不可用，跳过 Go 工具安装"
        return
    fi

    # 安装常用 Go 工具
    export GOPATH=/opt/go-tools
    export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
    mkdir -p "$GOPATH"

    local go_tools=(
        "github.com/OJ/gobuster/v3@latest"
        "github.com/ffuf/ffuf@latest"
        "github.com/projectdiscovery/httpx/cmd/httpx@latest"
        "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
        "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    )

    for tool in "${go_tools[@]}"; do
        detail "安装 Go 工具: $tool"
        go install "$tool" 2>/dev/null || {
            warn "$tool 安装失败"
            FAILED_PKGS+=("go:$tool")
        }
    done

    # 链接到 /usr/local/bin
    if [[ -d "$GOPATH/bin" ]]; then
        for bin in "$GOPATH/bin"/*; do
            [[ -f "$bin" && ! -f "/usr/local/bin/$(basename "$bin")" ]] && \
                ln -sf "$bin" "/usr/local/bin/$(basename "$bin")" 2>/dev/null || true
        done
    fi
}

# ==================== 其他实用工具 ====================
install_extra() {
    batch_apt_install "其他实用工具" \
        socat \
        netcat-traditional \
        ncat \
        rlwrap \
        expect \
        feh \
        imagemagick \
        zbar-tools \
        qrencode \
        pngcheck \
        exiv2
}

# ==================== 安装总结 ====================
print_summary() {
    echo
    info "========================================="
    info "  Linux Mint 渗透测试环境安装完成！"
    info "========================================="
    echo

    if [[ ${#FAILED_PKGS[@]} -gt 0 ]]; then
        warn "以下包安装失败:"
        for pkg in "${FAILED_PKGS[@]}"; do
            echo "  ❌ $pkg"
        done
    fi

    if [[ ${#SKIPPED_PKGS[@]} -gt 0 ]]; then
        warn "以下包仓库中不存在（已跳过）:"
        for pkg in "${SKIPPED_PKGS[@]}"; do
            echo "  ⏭️  $pkg"
        done
    fi

    echo
    info "🔧 常用工具启动命令:"
    echo "  Burp Suite Community:  需手动安装后运行 burpsuite"
    echo "  ZAP:                   zaproxy"
    echo "  Metasploit:            msfconsole"
    echo "  Wireshark:             wireshark / tshark"
    echo "  GDB + GEF:             gdb"
    echo "  Python 工具:           source /opt/sec-tools-venv/bin/activate"
    echo "  Nuclei:                nuclei -update-templates"
    echo
    info "📋 建议操作:"
    echo "  1. 执行 'source /etc/profile.d/sec-tools.sh' 或重新登录使 PATH 生效"
    echo "  2. 执行 'newgrp wireshark' 或重新登录使抓包权限生效"
    echo "  3. 手动下载 Burp Suite: https://portswigger.net/burp/communitydownload"
    echo "  4. 如需 Ghidra: https://ghidra-sre.org"
    echo "  5. 更新 Nuclei 模板: nuclei -update-templates"
    echo
    warn "⚠️  注意: 本脚本安装的工具仅供授权测试和 CTF 比赛使用！"
    info "========================================="
}

# ==================== 主程序 ====================
main() {
    info "========================================="
    info "  Linux Mint 渗透测试/CTF 环境搭建脚本"
    info "  版本: 3.0 | 最终优化版"
    info "========================================="

    detect_system
    update_system
    install_base
    install_recon
    install_web
    install_wireless
    install_password
    install_exploit
    install_ctf
    install_sniff
    install_crypto
    install_reverse
    install_pip_tools
    install_go_tools
    install_extra

    print_summary
}

# 执行主程序
main "$@"

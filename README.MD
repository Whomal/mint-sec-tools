markdown

# 🐧 Mint Sec Tools

**Linux Mint Penetration Testing / CTF One-click Installation Script**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Mint](https://img.shields.io/badge/Mint-21.x%20%7C%2022.x-green)](https://linuxmint.com/)
[![Bash](https://img.shields.io/badge/bash-5.0+-black)](https://www.gnu.org/software/bash/)

---

## 📦 简介 | Overview

**中文**  
这是一个为 **Linux Mint 21.x / 22.x** 设计的渗透测试和 CTF 工具一键安装脚本。

它会把一个全新的 Mint 系统，变成一辆**武装到螺丝的破单车**——不花哨，但能跑、能打、能干活。

**English**  
A one-stop installation script for **Linux Mint 21.x / 22.x** designed for penetration testing and CTF players.

It turns a fresh Mint system into a **fully-armed battle station** — no flashy UI, just tools that actually work.

> *"不是武器库当卧室，是精装房的书房里，抽屉拉开全是工具。"*
> *"Not a weapons-grade bedroom. A well-decorated study with a hidden drawer full of tools."*

---

## 🚀 快速开始 | Quick Start

### 1. 获取脚本 | Get the script

```bash
git clone https://github.com/Whomal/mint-sec-tools.git
cd mint-sec-tools

2. 运行安装 | Run the installation
bash

sudo bash mint_sec_tools.sh

3. 等待 | Wait

泡杯茶，或者吃串烧烤。安装大约需要 15-30 分钟，取决于网速。

Grab a coffee — or some BBQ. Installation takes 15–30 mins depending on your connection.
📋 工具清单 | Tool List
信息收集 | Information Gathering

nmap wireshark tcpdump dnsrecon theharvester recon-ng arp-scan masscan
Web 渗透 | Web Penetration

sqlmap zaproxy gobuster ffuf nikto wpscan dirb whatweb
无线安全 | Wireless Security

aircrack-ng reaver mdk4 kismet hcxdumptool hcxtools pixiewps bully
密码破解 | Password Attacks

john hydra hashcat crunch cewl wordlists rsmangler
漏洞利用 | Exploitation

metasploit-framework
CTF 辅助 | CTF Utilities

steghide binwalk foremost exiftool radare2 gdb pwntools ropper
网络嗅探/欺骗 | Sniffing & Spoofing

bettercap ettercap responder mitmproxy dsniff
逆向工程 | Reverse Engineering

apktool (Ghidra 需手动下载 | Ghidra requires manual download)
Python 工具集 | Python Toolchain

pwntools impacket bloodhound scapy frida crackmapexec …
Go 工具集 | Go Toolchain

gobuster ffuf httpx nuclei subfinder
🛡️ 安全特性 | Safety Features
特性	说明
包存在性检查	安装前确认包是否存在，不存在则跳过并记录
错误隔离	单个包安装失败不会中断整个脚本
临时文件清理	无论成功或失败，临时文件都会被清理
Python 虚拟环境	所有 pip 工具装在 /opt/sec-tools-venv，不污染系统
Go 环境隔离	Go 工具装在 /opt/go-tools，独立管理
wireshark 权限	自动配置非 root 抓包权限
Feature	Description
Package existence check	Skips missing packages gracefully and logs them
Error isolation	A single package failure won't kill the whole script
Temp file cleanup	trap ensures cleanup on exit or crash
Python virtual environment	All pip packages go to /opt/sec-tools-venv — no system pollution
Go environment isolation	Go tools go to /opt/go-tools
wireshark privileges	Auto-configures non-root packet capture
📝 安装后操作 | Post-installation Steps
刷新环境变量 | Reload environment variables
bash

source /etc/profile.d/sec-tools.sh
# 或重新登录 | or log out and back in

抓包权限生效 | Enable packet capture for non-root users
bash

newgrp wireshark
# 或重新登录 | or log out and back in

更新 Nuclei 模板 | Update Nuclei templates
bash

nuclei -update-templates

手动安装 Burp Suite Community | Manually install Burp Suite Community
bash

# 从官网下载 .sh 安装器 | Download the installer from:
https://portswigger.net/burp/communitydownload

激活 Python 虚拟环境 | Activate Python venv
bash

source /opt/sec-tools-venv/bin/activate

⚠️ 免责声明 | Disclaimer

中文

    本脚本仅供以下场景使用：

        授权的渗透测试

        CTF 比赛

        个人安全学习

    任何未经授权的使用均属违法行为。
    你是一个人，不是一把刀。——使用它的人，决定它是什么。

English

    This script is intended ONLY for:

        Authorized penetration testing

        CTF competitions

        Personal security research

    Unauthorized use is illegal.
    You are not a knife. The hands that hold it decide what it becomes.


Issues and PRs are welcome.
📄 License

MIT © Whomal
🌟 Star History

如果你用上了，觉得还行——
点个 Star，就当请我吃了串烧烤。 🍢

If this script saved you time —
drop a star, as if you bought me a skewer of BBQ. 🍢
bash

# 最后一句，给所有破单车车主：
# “你不是工具收藏家，你是武器驯服者。”
#
# One last line, for all the broken bike owners:
# "You're not a tool collector. You're a weapon tamer."

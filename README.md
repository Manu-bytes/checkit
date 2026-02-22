# checkit

![License](https://img.shields.io/badge/license-GPLv3-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)
![Bash](https://img.shields.io/badge/language-Bash-lima.svg)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macos-orange.svg)

An advanced, modular file integrity and hash verification CLI tool written in
Bash.

`checkit` abstracts the complexity of underlying cryptographic binaries
(`coreutils`, `shasum`, `b2sum`) to provide a unified, smart, and feature-rich
interface for creating and verifying file checksums. It features built-in GPG
signature integration, multiple structured output formats, and intelligent
context detection.

## ✨ Features

- **Multi-Algorithm Support:** Native support for MD5, SHA-1, SHA-224, SHA-256,
  SHA-384, SHA-512, and the BLAKE2 family (blake2b, blake2-128 to 512).
- **Smart Context Detection:** Automatically infers the correct algorithm during
  verification by analyzing hash lengths, file headers (`Content-Hash`), or
  BSD-style tags.
- **GPG Security Integration:** Sign your generated checksum lists (clearsign,
  detached, or ASCII armored) and enforce strict cryptographic verification
  (`--verify-sign`) when checking files.
- **Multiple Output Formats:** Generate checksums in standard GNU format, BSD
  tagged format, JSON, or XML.
- **Clipboard Integration:** Instantly copy generated hashes to the system
  clipboard (supports `pbcopy` for macOS, `wl-copy` for Wayland, and
  `xclip`/`xsel` for X11).
- **i18n Ready:** Native localization support adapting output messages to
  English or Spanish based on your `$LANG` environment variables.
- **Customizable UI:** Supports ASCII, Unicode/Emojis, and Nerd Fonts for
  terminal output formatting via environment variables or a configuration file.

## 📦 Requirements & Dependencies

`checkit` is designed to be highly portable and adapts to the tools available on
your system.

**Core Hashing Engines:**

- **`coreutils` (Highly Recommended):** Provides `sha*sum`, `md5sum`, and
  `b2sum`. Essential for full algorithm support, including **BLAKE2** and
  **MD5**.
  - *macOS users:* BLAKE2 and MD5 require coreutils. You can install it via
    Homebrew: `brew install coreutils` (ensure the binaries are available in
    your `PATH`).
- **`shasum` (Perl Fallback):** If `coreutils` are not found (default behavior
  on clean macOS or BSD systems), `checkit` automatically falls back to the
  native Perl `shasum` script. **Note:** This fallback *only* supports the SHA
  algorithm family.

**Optional Features:**

- **`gnupg` (GPG):** Required for all cryptographic signing and strict signature
  verification features (`--sign`, `--detach-sign`, `--verify-sign`).
- **Clipboard Utilities:** Required to use the `--copy` (`-y`) flag. `checkit`
  automatically detects and uses the appropriate tool for your display server:
  - macOS: `pbcopy` (built-in)
  - Wayland: `wl-clipboard` (`wl-copy`)
  - X11: `xclip` or `xsel`

## 🚀 Usage

`checkit` operates in three primary modes: Quick Verify, Create Mode, and Check
Mode.

### 1. Quick Verify

Instantly verify a single file against a known hash string. The algorithm is
automatically detected based on the hash length.

```Bash
checkit path/to/file.iso 9b7eb910...
```

### 2. Create Mode

Generate checksums for one or multiple files.

```Bash
# Basic SHA-256 generation
checkit file.txt

# Use BLAKE2b and copy output directly to the clipboard
checkit archive.tar.gz --algo b2 --copy

# Generate hashes for all files using all supported algorithms and format as JSON
checkit configs/* --all --format json -o checksums.json

# Creating JSON and XML structured outputs with inline GPG clearsigning.
checkit archive.tar.gz --all --format xml --detach-sign -o checksums.xml
```

### 3. Check Mode (`-c` / `--check`)

Verify multiple files against a generated checksum list.

```Bash
# Basic list verification
checkit -c CHECKSUMS

# Strict verification enforcing GPG signature validation
checkit -c RELEASE.asc --verify-sign

# Check hashes silently, ignoring missing files
checkit -c list.txt --quiet --ignore-missing
```

### 🔐 Advanced Signing and Auto-Naming

When generating detached signatures (`--detach-sign`), the `--output` (`-o`)
parameter is completely optional. `checkit` automatically generates standard
filenames based on the selected algorithm.

**Auto-generate algorithm-specific files (e.g., `SHA1SUMS` and
`SHA1SUMS.sig`):**

```Bash
checkit archlinux-2025.05.01-x86_64.iso --algo sha1 --detach-sign
```

**Auto-generate global files for multiple algorithms:** When generating hashes
for all algorithms (`--all`), it defaults to the global `CHECKSUMS` and
`CHECKSUMS.sig` naming convention.

```Bash
checkit archlinux-2025.05.01-x86_64.iso --all --detach-sign
```

**Override auto-naming with a custom filename:**

```Bash
checkit archlinux-2025.05.01-x86_64.iso --algo b2-224 --detach-sign --output HASHFILE
```

*Demonstration of automatic naming conventions versus custom output files during
detached signing.*

### 🎥 Video Examples

**Create Mode Demonstration:**
https://github.com/user-attachments/assets/a65f4f7d-2255-4cd2-8def-36aecdc18e99

**Check Mode Demonstration:**
https://github.com/user-attachments/assets/7f1db436-f7b1-48ff-8e37-74262cd883ce

## 🛠Build and Installation

For security reasons, `checkit` does not compile automatically during the
installation phase. You must build or test the standalone binary first.

1. Clone the repository and navigate to the project root.
1. Build the standalone binary:

```Bash
make build
```

3. (Recommended) Test the distributable binary before installing:

```Bash
make test-dist
```

4. Install to your system (`/usr/local/bin`):

```Bash
make install
```

### Alternative: Direct Execution (Symlink)

For development purposes or to run the tool directly from the source without
building the standalone binary, you can create a symbolic link to your system's
path:

1. Clone the repository and navigate to the project root:

```Bash
git clone https://github.com/Manu-bytes/checkit.git
cd checkit
```

2. Create a symbolic link pointing to the main script:

```Bash
sudo ln -s "$(pwd)/bin/checkit" /usr/local/bin/checkit
```

## 🧪 Testing and Development

The project utilizes `bats` for unit and integration testing, and `shellcheck`
for static analysis. The test suite is designed to validate both native
coreutils binaries and Perl (`shasum`) fallbacks.

- **Run static analysis (Shellcheck):**

```Bash
make lint
```

- **Run standard native tests:**

```Bash
make test
```

- **Run all test suites (Native and Forced Perl):**

```Bash
make test-all
```

## ⚙️ Configuration

You can customize the visual output of `checkit` by setting the UI mode. The
tool checks for preferences in the following order:

1. Environment Variable: `CHECKIT_MODE`
1. Configuration File: `~/.config/checkit/checkit.conf` (using the `MODE`
   variable)

**Available UI Modes:**

- `nerdfonts or nerd` (High detail, requires a patched font)
- `icons or unicode ` (Medium detail, uses standard emojis)
- `ascii` (Low detail, maximum compatibility - Default)

Example `~/.config/checkit/checkit.conf`:

```Bash
MODE="nerdfonts"
```

## 🛠Architecture

`checkit` is built with a strictly modular architecture to ensure
maintainability:

- `bin/checkit`: Main orchestrator.
- `lib/core/`: Parsing, formatting, and algorithm intelligence.
- `lib/adapters/`: Wrappers for external system calls (GPG, coreutils/perl
  shasum).
- `lib/cli/`: Argument parsing and localized UI rendering.
- `lib/utils/`: System-level utilities like clipboard management.

## 🤝 Contributing & Support

<div align="left">
  <h3>Ways to support:</h3>

<p>
    🌟 <b>Star this repository:</b> It helps more people find this tool.<br>
    🐞 <b>Open an issue:</b> Report bugs or suggest new features.
  </p>

<div align="center">
    <p>If this tool was useful, consider supporting its maintenance.</p>
    <table align="center" style="border: none;">
      <tr>
        <td align="center" style="border: none; padding: 20px;">
          <a href="https://tecito.app/manubytes">
            <img src=".github/assets/coffee.svg" alt="Buy Me A Tea" height="80">
            <br><i>Buy me a tea</i>
        </a>
        </td>
        <td align="center" style="border: none; padding: 20px;">
          <img src=".github/assets/EVM.svg" alt="Ethereum Virtual Machine" height="40">
          <br>
          <a href="https://optimistic.etherscan.io/address/0x5447BdD6445Ea43Fd518835cb6c1bEe0b6D8558C" target="_blank" rel="noopener noreferrer">
            <kbd>0x5447BdD6445Ea43Fd518835cb6c1bEe0b6D8558C</kbd><small>📋</small>
          </a>
          <br><small>Supports:</small>
          <br><small>ETH, BSC, Polygon, OPtimism, Arbitrum, Mantle.</small>
        </td>
      </tr>
    </table>
  </div>
</div>

______________________________________________________________________

## 📄 License

This project is licensed under the GNU GPL version 3 or later. Refer to the
[LICENSE](./LICENSE) file for details.

Copyright © 2026 **Manu-bytes**.

# Roblox Runtime (Cordial)

Este repositório é um fork do [Cordial](https://github.com/luohoa97/cordial),
um runtime Linux para executar o cliente Android oficial do Roblox. O projeto
não inclui o Roblox nem seus arquivos: você fornece o cliente, que o Cordial
verifica antes de usar.

## Requisitos

- Linux x86-64 (recomendado) com sessão gráfica Wayland. X11 também é
  suportado, mas é menos testado.
- Rust stable, Git, Clang, CMake e `pkg-config`.
- GTK 4.12 ou mais recente e libadwaita 1.5 ou mais recente.
- PipeWire e seus headers são opcionais; sem eles, o build não inclui o
  backend de áudio OpenSL ES.

### Ubuntu 24.04

```bash
sudo apt update
sudo apt install -y build-essential clang cmake pkg-config git \
  libgtk-4-dev libadwaita-1-dev libpipewire-0.3-dev zlib1g-dev \
  curl ca-certificates
```

Instale Rust stable usando [rustup](https://rustup.rs/) e carregue o ambiente
no terminal atual:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
```

## Clonar e compilar

Clone o fork com todos os submódulos necessários ao runtime:

```bash
git clone --recurse-submodules git@github.com:ErickdeSouza/Roblox-Runtime.git
cd Roblox-Runtime
cargo build --workspace --release
```

Se sua chave SSH não estiver configurada no GitHub, use HTTPS:

```bash
git clone --recurse-submodules \
  https://github.com/ErickdeSouza/Roblox-Runtime.git
```

O executável da interface fica em `target/release/cordial-shell`.

## Executar

Confira primeiro se o runtime e o sistema foram detectados corretamente:

```bash
./target/release/cordial-shell --diagnostics
```

Inicie a interface:

```bash
./target/release/cordial-shell
```

Na primeira execução, escolha **Download Roblox** para baixar uma versão
verificada. Para importar um APK pela interface, abra **Settings → Roblox →
Import from a file**. Em instalações divididas, mantenha `base.apk` e o split
de arquitetura correspondente (por exemplo, `split_config.x86_64.apk`) juntos.
O APK oficial não é distribuído neste repositório.

Para executar um APK em uma única sessão, sem importá-lo para a biblioteca:

```bash
CORDIAL_APK="/caminho/para/base.apk" \
  ./target/release/cordial-shell
```

Perfis, configurações e builds baixados ficam normalmente em
`~/.local/share/cordial/`.

## Observações

- Este é um aplicativo Linux, não um executável nativo do Windows. No Windows,
  a alternativa documentada é executá-lo pelo WSL 2/WSLg: [guia WSL](docs/windows-wsl.md).
- A aceleração gráfica e o desempenho dependem dos drivers e da configuração
  da VM. Wayland é a sessão recomendada; verifique a sessão atual com
  `echo "$XDG_SESSION_TYPE"`.
- O guia completo de instalação, formatos de pacote e limitações está em
  [docs/install.md](docs/install.md).

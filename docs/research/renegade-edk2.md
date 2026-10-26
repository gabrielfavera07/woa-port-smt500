# Research — UEFI/EDK2: como os ports funcionam e o estado do "bengal" (SM6115)

> Fontes: buscas out/2026 + ecosystem docs. Itens "a verificar" estão marcados.

## Como um port UEFI é estruturado (padrão Renegade/edk2-porting)

- Firmware **EDK2/Project Mu** compilado para a plataforma (inicialização de clocks/voltage,
  DDR, periféricos mínimos) e **empacotado como boot.img Android** ("kernel" = binário UEFI).
  O ABL do fabricante carrega e pula para EL1 — não precisa tocar em XBL/ABL assinados.
- O que o UEFI fornece ao Windows: **BlockIo** (eMMC/UFS → discos), **GOP** (framebuffer da
  tela), **USB host** (teclado/mouse durante setup), **ACPI tables** (DSDT com os nós dos
  periféricos), FAT/NTFS simples, variáveis UEFI.
- Repos: [edk2-porting/edk2-msm](https://github.com/edk2-porting/edk2-msm) (multi-SoC),
  [edk2-sdm845](https://github.com/edk2-porting/edk2-sdm845), forks por aparelho.
  Geração mais nova: **Project Mu** — [mat-777/Mu-Qcom](https://github.com/mat-777/Mu-Qcom),
  [liliumbeta/Mu-Qcom](https://github.com/liliumbeta/Mu-Qcom),
  [Project-Aloha/mu_aloha_platforms](https://github.com/Project-Aloha/mu_aloha_platforms).
- Build: GCC AARCH64 (Ubuntu/WSL), submodules edk2 + plataforma; releases saem como
  `boot-<codename>.img`. Ex.: release 2301.1 do edk2-msm com 31 aparelhos.

## Estado do bengal (SM6115/662, SM6125/665) — o que apuramos

1. **Não existe port público dedicado a `gta4l/gta4lwifi`** na org edk2-porting (busca
   out/2026: nenhum `edk2-gta4l`; LineageOS/.ethOS cobrem o aparelho no lado Android apenas).
2. **MAS um build bengal já rodou neste exato tablet** (evidência: `startup.nsh`
   "Bengal WoA: launching Windows Boot Manager..." na ESP, jun/2026, + bootmgfw 22621-era
   instalado) → existe fork community (Mu-Qcom/Aloha-based, típico para SM6xxx) **a localizar**
   (Renegade Forum/Telegram são o canal usual desses builds não-indexados).
3. Candidatos a base para rebuild (ordem): **Mu-Qcom forks com bengal/chime (SM6115
   Redmi 9T/POCO M3, mesmo die)** → **mu_aloha_platforms** → **edk2-msm** (se tiver tree bengal).
4. Port novo a partir do guia community ([porting guide](https://forum.renegade-project.tech/t/edk2-sdm845-new-device-porting-guide/417)):
   device tree da plataforma + endereços do DTB real (já temos: `device/analysis/live-dtb.txt`),
   init do painel (HX83102E/AUO — DSI init tables vêm do dtbo stock, também já dumpado),
   pinmux do touch (Synaptics TCM@0x20 I2C-1, IRQ GPIO 0x11), eMMC SDHCI.

## O que o UEFI precisa acertar ESPECÍFICAMENTE neste tablet
| Item | Dado (já extraído) |
|---|---|
| Painel DSI | `qcom,mdss_dsi_hx83102e_hlt_auo_video`, dtbo_idx=5 |
| Touch | I2C-1 (Geni/QUPI2C), addr 0x20, synaptics,tcm-i2c, irq-gpio 0x11 |
| eMMC | `4744000.sdhci` (SDHCI) |
| USB | DWC3 Qualcomm + FSA4480 switch |
| Memória | DRAM 3 GB — memory map do platform init bengal |

## Riscos específicos
- **eMMC** (não UFS): ports Mu-Qcom recentes assumem UFS às vezes; driver SDHCI/MMC precisa
  estar habilitado na build (checar na fork escolhida).
- Painel: init tables do AUO divergem por lote — usar as do próprio dtbo stock dumpado.
- Sem fastboot Samsung: build precisa ser flashável por `dd`/Odin como boot.img (é o formato
  padrão de release dos ports — ok).

## Fontes
[edk2-porting org](https://github.com/edk2-porting) · [edk2-msm](https://github.com/edk2-porting/edk2-msm) ·
[Mu-Qcom (mat-777)](https://github.com/mat-777/Mu-Qcom) · [Mu-Qcom (liliumbeta)](https://github.com/liliumbeta/Mu-Qcom) ·
[Project Aloha](https://github.com/Project-Aloha/mu_aloha_platforms) ·
[Renegade docs](https://renegade-doc.readthedocs.io) · [Forum Renegade](https://forum.renegade-project.tech) ·
[XDA](https://www.xda-developers.com/renegade-project-boot-arm64-windows-10-11-on-android-devices)

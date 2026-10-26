# DEVICE PROFILE — Samsung Galaxy Tab A7 2020 (SM-T500, `gta4lwifi`)

> Dossiê consolidado do hardware alvo do port Windows on ARM. Gerado por coleta ao vivo
> via TWRP (2026-10-24) + análise do firmware stock (T500XXS8CXG3) + Device Tree real.
> Fontes brutas: `device-collect.txt`, `../analysis/live-dtb.txt`, `../analysis/partition-table.md`.

## 1. Identidade

| Campo | Valor | Fonte |
|---|---|---|
| Modelo | SM-T500 (Galaxy Tab A7 10.4" 2020, Wi-Fi) | getprop / cmdline `androidboot.em.model` |
| Codinome | `gta4lwifi` | getprop `ro.product.device` |
| Serial | R9XNA0PCVMA | adb |
| SoC | Qualcomm **Snapdragon 662 (SM6115, plataforma "bengal")** | DT `qcom,bengal-qrd`, cmdline `soc_name` vazio mas DT confirmado |
| CPU | 8x Kryo 260: 4x "Gold" (Cortex-A73-derivado, até **2.016 GHz**) + 4x "Silver" (Cortex-A53-derivado, até **1.804 GHz**) | cpuinfo + cpufreq |
| ISA | **ARMv8.0-A** — features: `fp asimd aes pmull sha1 sha2 crc32` — **SEM LSE (atomics)**, sem asimdhp/fphp | `/proc/cpuinfo` |
| GPU | Adreno 610 | (plataforma bengal) |
| RAM | 3 GB (2,71 GB visíveis ao kernel) — `androidboot.dram_info=01,07,00,3G` | cmdline/meminfo |
| Armazenamento | **eMMC 64 GB** (~58,4 GiB; `mmcblk0`, bootdevice `4744000.sdhci`, fstab `emmc`) — **não é UFS** | /proc/partitions |
| Display | 10.4" 2000x1200, DSI video-mode, **painel AUO com controlador Himax HX83102E** (`msm_drm.dsi_display0=qcom,mdss_dsi_hx83102e_hlt_auo_video`) | cmdline |
| Kernel Android | 4.19.152-perf (bootloader T500XXS8CXG3, Android 12 stock; LineageOS 23.2 instalado) | uname/cmdline |
| Bootloader | **Desbloqueado** (`androidboot.verifiedbootstate=orange`, `warranty_bit=1`); SecureBoot Samsung ainda `secureboot=1` no chainload | cmdline |

## 2. Restrição arquitetural crítica (define o teto do projeto)

O Kryo 260 é **ARMv8.0 sem extensão LSE (atomics)**. Windows 11 **24H2+ exige ARMv8.1/LSE**
(a geração Snapdragon 835 foi cortada no 23H2). Consequência prática:

- **Teto de versão: Windows 11 22H2/23H2 — builds 22621–22623** (idêntico ao cenário SDM835).
- O emulador **Prism (24H2)** e a atualização AVX2 (dez/2025) **não se aplicam** a este chip.
- Emulação **x86 32-bit** (WOW64): suportada desde sempre no WoA — ok.
- Emulação **x64**: existe desde o Windows 11 (2021) e roda em ARMv8.0, mas **sem aceleração de
  GPU** nos ports community e com desempenho modesto em cores 2018-class.
- Consistência: os arquivos de boot achados na ESP (`bootmgfw.efi` mai/2022) são exatamente da era 22621 —
  a tentativa anterior de install já respeitava esse teto.

## 3. Mapa de hardware (para drivers Windows ARM64)

| Subsistema | Componente | Endereço/ônibus | Driver Windows (estado a auditar) |
|---|---|---|---|
| Touch | **Synaptics TCM I2C** (`synaptics,tcm-i2c`) | I2C-1 (Geni-I2C QUPI2C SE1), addr **0x20**, IRQ GPIO 0x11/flags 0x2008 | HID-over-I2C genérico via DSDT, ou driver Synaptics |
| Display | Himax HX83102E + AUO (DSI video) | mdss_dsi0 | Framebuffer simples via UEFI GOP; GPU Adreno 610 **sem driver Windows** → renderização por software |
| Wi-Fi/BT | **Qualcomm WCN3990** (`qca,wcn3990`) — combo integrado | WLAN via CNSS/MSA; BT UART | Sem driver ARM64 consumer conhecido — principal gap junto com GPU |
| Áudio | **WCD937x** codec + Bolero (rx/va macro, SoundWire), DMICs, `msm_cdc_pinctrl` | APR/Q6 | Driver community WCD (audioparser) — a auditar |
| Battery gauge | **CellWise CW2017** (`cellwise,cw2017`) | I2C-1 addr **0x63** | Driver CW2017 existe em packs community |
| Fuel/charge | Qualcomm **PM6125** + **PMI632** (spmi), `qcom,chgr`, step-chg, qg | SPMI 1c40000 | Driver PMIC community |
| NFC | NXP **nq-nci** | I2C-0 addr **0x28** | NXP NCI driver existe (Windows inbox NFP?) |
| USB | FSA4480 (switch USB-C), DWC3 QCOM, OTG | I2C-0 addr 0x42 | Driver community |
| Sensores | via IIO/ADSP (SSC) | fastrpc/adsp | Sem suporte esperado |
| eMMC | `4744000.sdhci` (SDHCI) | — | UEFI BlockIo (já funciona — Windows já chegou a instalar) |

Nós-chave no DT real: `device/analysis/live-dtb.txt` (17.457 linhas; grep por `synaptics_tcm@20`,
`cw2017-fuelgauge@63`, `wcn3990`, `qcom,nq-nci`, `wcd937x_reset_*`, `bolero-cdc`).

## 4. Layout de partições (GPT real, 83 entradas)

Tabela completa: `device/analysis/partition-table.md`. Resumo do que importa para o port:

| Partição | # | Tamanho | Conteúdo/estado |
|---|---|---|---|
| `xbl`, `xbl_config` (+bak) | 1–4 | 4 MB cada | Chainloader Qualcomm (assinado, intocável) |
| `abl` | 12 | 4 MB | Android Bootloader Samsung (assinado; carrega `boot.img`) |
| `tz`/`hyp`/`rpm`/`uefisecapp`/`devcfg` | 5–21 | — | TrustZone/RPM firmware (assinado) |
| `vbmeta`/`vbmeta_samsung` | 11/19 | 128 KB | Verificação — desativada na prática (bootloader destravado) |
| `boot` | 69 | 96 MB | Android boot v2 (kernel+ramdisk). **É aqui que o payload UEFI vai** |
| `dtbo` | 57 | 24 MB | Overlays de DT (dtbo_idx=5 em uso) |
| `super` | 73 | 5,3 GB | system/vendor/product/odm (dynamic partitions) |
| `userdata` | 80 | 27 GB | ext4, já reduzido |
| **`esp`** | **81** | **600 MB (FAT32, type ESP)** | **Já criada e populada com boot Windows ARM64** |
| `msr` | 82 | 16 MB | Reservada Microsoft (padrão x86; inócua) |
| **`win`** | **83** | **23,4 GB (NTFS, BASIC-DATA)** | **Já criada; instalação Windows pré-existente (não montável no TWRP)** |
| `logfs` | 67 | 8 MB | UEFI/ABL log store (contém logs de flash/restauração de partições) |
| `uefivarstore` | 56 | 0,5 MB | Variáveis UEFI do ABL |

## 5. Estado atual do dispositivo (2026-10-24)

1. **Bootloader destravado**; boot atual = LineageOS 23.2 (boot.img v2, kernel 18 MB); TWRP instalado (recovery).
2. **Uma instalação Windows ARM64 anterior existe** (ESP de jun/2026 com `bootmgfw.efi` 22621-era,
   BCD apontando `\Windows\system32\winload.efi`, `startup.nsh` do edk2 escrito "Bengal WoA",
   `boot.stl` = cert trust list MS 2024-25). O conteúdo da partição `win` não pôde ser inspecionado
   pelo TWRP (sem ntfs-3g) — precisa de boot no UEFI/MSC ou leitura via PC.
3. O **payload UEFI "Bengal" não está arquivado** na ESP (os `.bak29563` são bootmgr MS original).
   Onde obter/reconstruir: ver `docs/research/renegade-edk2.md` (edk2-msm/forks bengal).
4. `logfs` registra sessões de restauração das partições de bootloader (xbl, abl, tz, hyp...) —
   indício de recovery pós-experimento; chainload atual é 100% stock.

## 6. Cadeia de boot (alvo e atual)

```
[PBL/SBL (ROM+XBL assinados)] → ABL (Samsung, assinado)
    → boot.img (kernel Linux) → Android          ← estado atual (LineageOS)
    → boot.img (payload UEFI edk2-bengal) → UEFI ← estado alvo (Windows)
        startup.nsh na ESP → \EFI\Microsoft\Boot\bootmgfw.efi → winload.efi → Windows 11 ARM64 (22621)
```

- Samsung **não tem fastboot**; o payload UEFI é gravado no slot `boot` via Odin/Heimdall
  ou diretamente `dd` via TWRP (o ABL aceita boot.img não assinado com bootloader destravado,
  como comprova o LineageOS boot atual).
- Dual-boot = trocar o conteúdo de `boot` (Android kernel ↔ UEFI) + WOA Helper/TWRP script.

## 7. Riscos e limites conhecidos (honestidade técnica)

- **eMMC**: ~150–300 MB/s sequencial, IOPS baixo — boot e Windows Update serão lentos.
- **3 GB RAM**: no limite do aceitável para Win11 22H2 (mínimo oficial 4 GB; funciona com bypass,
  mas com folga pequena).
- **GPU sem driver** → renderização em software (Microsoft Basic Display Adapter): UI fluida só
  em 2D leve; vídeo/games pesados inviáveis. Esse é o maior gargalo de UX.
- **WCN3990**: Wi-Fi/BT dependem de driver community; se indisponível, alternativa = dongle USB.
- Sem Hyper-V/WSL2 (boot em EL1), sem anti-cheat kernel x86, sem atualização para 24H2.

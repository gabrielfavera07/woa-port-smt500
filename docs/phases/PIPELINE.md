# PIPELINE — Port Windows 11 ARM64 nativo (SM-T500 / gta4lwifi)

> Plano executável em fases, adaptado à realidade medida deste aparelho: partições `esp`/`msr`/`win`
> **já existem**, bootloader destravado, TWRP no recovery, cadeia Samsung sem fastboot, e teto de
> versão **22621–22623** (ARMv8.0 sem LSE). Cada fase tem critério de saída verificável ("gate").

## Visão geral

| Fase | Objetivo | Estado | Gate de saída |
|---|---|---|---|
| 0. Preservação | Backup de tudo que é único (EFS/modem/persist) | **pendente** | dumps salvos em 2 lugares |
| 1. Hardware | Mapa de drivers/acpi | **feito** (DEVICE-PROFILE.md, live-dtb) | perfil assinado |
| 2. UEFI | Obter/compilar payload edk2-bengal como boot.img | **pendente** (chave estrangeira) | UEFI boota shell na tela |
| 3. Imagem | ISO/WIM 22621 ARM64 + drivers injetados | **pendente** | apply + bcdboot ok via MSC |
| 4. Instalação | Windows aplicado na `win`, BCD com testsigning | parcial (existe install jun/26) | OOBE completa |
| 5. Drivers/Acpi | touch/bateria/áudio/wifi por DSDT+drivers | **pendente** | devmgmt sem "!" nos alvo |
| 6. Dual-boot | troca Android↔Windows segura | **pendente** | ciclo 10x sem brick |
| 7. Auditoria | estabilidade, .exe x86/x64, térmico | **pendente** | ver critérios na fase 7 |

## Fase 0 — Preservação (ANTES de qualquer flash)

Partições que NÃO podem ser regeneradas se corromperem (identidade do aparelho — sem elas o
tablet perde IMEI-less Wi-Fi calib, NRF etc. e vira papel em alguns casos):

```
TWRP terminal → dd de: efs sec_efs persist modemst1 modemst2 fsg fsc modem blklog? 
  para /external_sd ou adb pull (ver scripts/device/backup-critical.sh)
```
Confirmar backup de `boot` (Lineage) e `recovery` atuais. Guardar GPT (`device/dumps/gpt-*.bin` já ok).

## Fase 1 — Mapeamento (CONCLUÍDA)

- `device/profile/DEVICE-PROFILE.md` — dossiê completo (SoC, periféricos com endereços I2C, PMICs).
- `device/analysis/live-dtb.txt` — Device Tree real (17k linhas) = insumo para escrever o DSDT.
- `device/analysis/partition-table.md` — GPT real com 83 entradas.
- `rea-analysis/BOOT-CHAIN.md` — cadeia XBL→ABL→boot.img com evidências.

## Fase 2 — UEFI (o coração do port)

**O que é:** firmware UEFI (EDK2) empacotado como Android boot.img; o ABL carrega e o Windows
passa a ter BIOS/GOP/BlockIo/ACPI. No SM-T500 não há fastboot: gravação via Odin/Heimdall ou `dd`
TWRP no slot `boot` (mmcblk0p69).

**Rotas possíveis (em ordem de custo):**
1. **Upstream comunitário bengal** — procurar releases "boot-gta4lwifi"/"bengal" nos projects
   edk2 (docs/research/renegade-edk2.md lista os repositórios e suporte por SoC). O `startup.nsh`
   "Bengal WoA" prova que um build desses já rodou neste exato aparelho em jun/2026.
2. **Adaptar um port irmão** — sm6125/sm6115 compartilham plataforma bengal (mesmos endereços
   de periféricos no grosso); diferenças: painel (DSI init do HX83102E/AUO), touch (Synaptics
   TCM@0x20 — presente em vários ports), eMMC (não UFS → driver SDHCI no UEFI).
3. **Compilar do zero** — edk2 + plataforma bengal: semanas de engenharia; necessário se 1 e 2
   falharem (build: GCC AARCH64 + Ubuntu/WSL, ver research).

**Gate 2:** com o boot.img-UEFI gravado e reboot, aparece o shell/UEFI na TELA do tablet
(framebuffer GOP funcionando com o painel AUO/HX83102E) e o menu vê a ESP (FAT32) e a `win` (NTFS).

## Fase 3 — Imagem Windows ARM64

1. **Não usar a ISO x64** (`CCCOMA_X64FRE_PT-BR`) — arquitetura errada; serve só de referência.
2. Baixar **Windows 11 22H2 ARM64 build 22621** via **UUP Dump** (uupdump.net): edition Pro,
   pt-BR, "Download and convert to ISO" + updates. (Ou ISO ARM64 oficial da MS se ainda 22H2/23H2.)
3. Extrair `install.wim` e injetar drivers offline:
   `dism /Image:<montado> /Add-Driver /Driver:<pasta-drivers-arm64> /Recurse`
4. Drivers: packs community WOA (ver docs/research/drivers-woa.md) — Qualcomm platform, touch,
   bateria (CW2017), áudio WCD, USB.

**Gate 3:** `dism /Get-Packages` offline mostra os drivers injetados; wim apply limpo num teste.

## Fase 4 — Instalação (método MSC, sem WinPE)

1. Boot no UEFI (Fase 2) → habilitar **USB Mass Storage** (edk2-msm MSC) → eMMC aparece no PC
   como discos (ESP + WIN).
2. No PC: `diskpart` → letras p/ ESP (S:) e WIN (W:):
   - `dism /Apply-Image /ImageFile:install.wim /Index:1 /ApplyDir:W:\`
   - `dism /Image:W:\ /Add-Driver /Driver:<drivers> /Recurse`
   - `bcdboot W:\Windows /s S: /f UEFI`
   - Bypass de requisitos (RAM 3 GB < 4 GB oficial): montar offline e setar
     `HKLM\SYSTEM\Setup\LabConfig` (BypassTPMCheck/BypassRAMCheck/BypassSecureBootCheck=1),
     ou gravar `setupcomplete.cmd`.
   - `bcdedit /store S:\EFI\Microsoft\Boot\BCD /set {default} testsigning on`
     `... nointegritychecks on` (drivers community não assinados MS)
   - remover `S:\EFI\Microsoft\Boot\SiPolicy.p7b` se existir.
3. Primeira inicialização: OOBE (`bypassnro` se travar em rede — Wi-Fi ainda sem driver).

**Gate 4:** OOBE completa, chega na Área de Trabalho com touch SE o driver/HID estiver ativo.

## Fase 5 — Drivers + ACPI (a "alma" da compatibilidade)

Para cada periférico do DEVICE-PROFILE: driver Windows ARM64 + nó ACPI (DSDT) no UEFI:
- Touch Synaptics TCM (I2C-1 @0x20): nó HID I2C (GPIO 0x11 IRQ) ou driver específico;
- Bateria: CW2017 gauge + PMI632 charger (class battery);
- Áudio: WCD937x community driver;
- Wi-Fi/BT WCN3990: maior risco — sem driver ARM64 consumer; alternativas: dongle USB Wi-Fi
  com driver ARM64 inbox (Realtek/Ralink alguns) ou engenharia própria;
- Botões/volume, vibração, NFC (nq-nci), sensores (ADSP — tipicamente sem suporte).
Ciclo: editar DSDT no edk2 → rebuild → flash → validar no `devmgmt.msc` (sem "!").

**Gate 5:** touch + bateria + áudio + USB funcionando; GPU aceita como Basic Display (esperado).

## Fase 6 — Dual-boot Android ↔ Windows

- Android→Windows: app WOA Helper (Magisk) ou script TWRP que grava `boot` = UEFI e reboota;
- Windows→Android: atalho que grava boot.img Lineage de volta (via driver directo eMMC ou
  fastboot-like custom; nos ports Xiaomi usa-se o próprio UEFI/SimpleInit — aqui avaliar).
- SEMPRE manter cópias: `boot-android.img`, `boot-uefi.img`, TWRP recovery intacto (slot recovery).

**Gate 6:** 10 ciclos alternados sem intervenção de recovery.

## Fase 7 — Auditoria de qualidade (o "harsh auditor")

Critérios objetivos, lado a lado com as expectativas de um WoA real:
- Boot: tempo até desktop < 2 min (eMMC lento é o limite físico);
- `.exe`: matriz de testes — x86 (notepad++, 7-zip x86), x64 (7-zip x64, Paint.NET), ARM64 nativo;
  documentar falhas conhecidas (kernel drivers x86 NUNCA funcionam — fato do WoA, não do port);
- Estabilidade: 24 h ligado, sleep/wake, ciclo de bateria com leitura correta;
- Térmico: throttling em carga sustentada (passive cooling);
- I/O:CrystalDiskMark na `win` (eMMC) — expectativa ~150-250 MB/s seq;
- Cada bug → issue no worklog com evidência (foto/serial log — BCD.pre-serial indica que a
  tentativa anterior usava debug serial; UART 1.8V nos pads de teste é opção para logs).

## Riscos vivos (top 3)

1. **GPU sem driver** (Adreno 610) — UI via CPU; vídeo pesado/games inviáveis. Sem solução
   upstream conhecida em 2026 para a610/Windows.
2. **Wi-Fi WCN3990** — se sem driver: dongle USB (com driver ARM64) como plano B.
3. **UEFI bengal desatualizado** — o payload de jun/26 não está arquivado; refazer se a fonte
   community sumir (compilação própria via rota 3).

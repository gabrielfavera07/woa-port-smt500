# Worklog

## 2026-10-24 — Sessão 1: descoberta, mapeamento e fundação

**Contexto recebido:** objetivo = Windows nativo bootando no tablet, tudo compatível
(touch/wifi/som/bt), sem emulação de sistema. ISO Win10 x64 no workspace (arquitetura errada —
documentado). 4 subagentes de pesquisa disparados (UEFI/edk2, drivers, instalação, emulação x86).

**Feito (com evidências):**
1. Identificado o alvo pelos firmwares: SM-T500 gta4lwifi, **Snapdragon 662 (bengal)** —
   corrigido o palpite inicial de MediaTek após ver o BL (abl/xbl/tz Qualcomm).
2. Coleta ao vivo via TWRP (adb): SoC, CPU (8x Kryo 260, **ARMv8.0 sem LSE** → teto 22621),
   3 GB RAM, **eMMC 64 GB** (não UFS), mapa de 83 partições, I2C (touch Synaptics TCM@0x20,
   gauge CW2017@0x63, NFC nq-nci@0x28, FSA4480), PMICs PM6125/PMI632, painel HX83102E/AUO,
   Wi-Fi/BT WCN3990 → `device/profile/device-collect.txt`.
3. **Descoberta da tentativa anterior (jun/2026):** ESP com boot Windows ARM64 22621-era,
   BCD → winload.efi, `startup.nsh` "Bengal WoA" (payload edk2 já rodou aqui!), boot.stl
   (CTL MS 2024-25). Payload UEFI em si não está arquivado no aparelho.
4. GPT real parseado (esp 600MB/msr 16MB/win 23,4GB **já criadas**); DTB vivo dumpado
   (17.457 linhas) → insumo do DSDT futuro.
5. Firmware stock extraída (abl/xbl/tz/hyp/rpm/boot/dtbo/vbmeta/modem) + análise estrutural
   da cadeia de boot (REA iniciado; Ghidra ausente no host — parse local ELF/strings).
6. **Fase 0 executada: backup 501 MB** (efs, sec_efs, persist, modemst1/2, fsg, fsc, modem,
   param, dtbo, boot, recovery, vbmeta×2, GPT primário/secundário) com SHA256SUMS.
7. Ferramentas criadas (tools/): gpt_parse, fdt_dump, android_boot_parse, elf_parse,
   efi_strings, extract_firmware. Scripts TWRP: backup-critical, flash-uefi,
   restore-android-boot. Script PC: Apply-WindowsToTablet.ps1 + guia de ISO ARM64.
8. Docs: DEVICE-PROFILE.md, BOOT-CHAIN.md, PIPELINE.md (8 fases com gates), research docs.

**Gates:** F0 ✓ (backup) · F1 ✓ (mapeamento) · F2-F7 pendentes.

**Decisões:**
- Build alvo = 22621 ARM64 (UUP Dump), não 24H2 (sem LSE). ISO x64 descartada.
- Método de instalação = Mass Storage (UEFI MSC) + DISM no PC — sem WinPE.
- Dual-boot por troca do slot `boot` (scripts prontos), SEM fastboot (cadeia Samsung).

**Bloqueadores em aberto:**
- [ ] Obter/recompilar payload UEFI bengal (aguardando relatório do subagente edk2/Renegade;
      senão: buscar forks "bengal/sm6115/sm6125" e adaptar).
- [ ] Drivers ARM64: pack community (relatório do subagente drivers pendente).
- [ ] Conteúdo da partição `win` ainda não inspecionado (NTFS não montável no TWRP).

## 2026-10-24 — Sessão 1 (fechamento)
- Fase 0 EXECUTADA: backup 501 MB verificado (SHA256SUMS) em device/dumps/backup-critical/.
- Research docs fechados: install-pipeline.md, exe-emulation.md, renegade-edk2.md, drivers-woa.md
  (estado bengal verificado por busca direta: sem port público p/ gta4l; bases = Mu-Qcom/Aloha;
  fork "Bengal WoA" existiu e rodou neste aparelho em jun/2026 — localizar via fórum/Telegram).
- Scripts prontos: backup-critical.sh (usado), flash-uefi.sh, restore-android-boot.sh,
  Apply-WindowsToTablet.ps1, Get-ARM64-ISO.md.
- Subagentes drivers/Renegade ainda pendentes de entrega — lacunas já cobertas por busca
  direta com incertezas marcadas; relatórios enriquecerão os docs quando chegarem.
- PRÓXIMO PASSO CRÍTICO (Fase 2): obter boot-uefi.img bengal → gate: UEFI na tela do tablet.

## 2026-10-24 — Sessão 2: Fase 2 destravada (payload UEFI localizado)
- **Descoberto o upstream real do port:** Project-Silicium/**Mu-Silicium** tem
  `Platforms/Samsung/gta4lPkg` ATIVO (commits até ago/2026; contribuidor V6lhost).
  Status: display ✅, storage ✅, USB host ✅, MSC ❌ (reboot), Windows/Linux boot ❌.
- "Bengal WoA" de jun/2026 na ESP ≈ build deste projeto (hipótese forte; BCD.pre-serial
  indica debugging serial da fase Windows Boot).
- **BIT-8** (aviso do Status.md, também no S23+): não está no código — tratado como
  requisito de header Samsung da boot image; plano = comparação empírica de headers
  no flash (boot.img Lineage é aceito pelo mesmo ABL).
- **Pré-requisito Samsung documentado:** storage "Offline" no MSC quebra boot Win/Linux;
  guia oficial de fix (gdisk) arquivado em uefi/UEFI-BUILD.md.
- WSL2 Ubuntu preparado (gcc-aarch64 13.3, dtc 1.7); clone Mu-Silicium (5GB) em andamento.
- Doc novo: uefi/UEFI-BUILD.md (fonte, status, build, gates, arquitetura do repo).

## 2026-10-24 — Sessão 2 (fechamento): UEFI COMPILADO E GRAVADO
- Toolchain validada no WSL: build `Mu-gta4l.img` (5,5 MB, boot.img v1, kernel gzip
  BootShim+UEFI.FD) — 48 módulos, RELEASE_CLANGPDB, exit 0.
- Double-check do backup do boot (2 cópias, 96MiB idênticos, hash d23f32ac...).
- FLASH EXECUTADO: dd /tmp/uefi.img → /dev/block/by-name/boot, verificado (ANDROID!).
- Tablet reiniciado às ~17:2x — aguardando observação da tela (Gate 2).
- Recovery garantido se algo der errado: desligar → Vol+ + Power → TWRP →
  `dd if=/tmp/boot-before-uefi.img of=/dev/block/by-name/boot` (ou re-gravar backup do PC).
- PRÓXIMO: (a) confirmar menu UEFI na tela; (b) overlay ACPI gta4l (lime/citrus são
  templates SM6115 — Kamorta = DSDT comum com device EMMC!) para desbloquear Windows Boot;
  (c) ISO 22621 ARM64 + install.

## 2026-10-24 — Sessão 3: ACPI DO GTA4L CRIADO — PRIMEIRO FIRMWARE COM ACPI PARA TAB A7
- Overlay: Silicium-ACPI/Platforms/Samsung/gta4l/{SSDT.asl(+aml), AcpiTables.inf}
  (EMMC on / UFS0 off — inverso do lime; base Kamorta SM6115; OEM SAMSNG/GTA4L).
- dsc/fdf descomentados; build verificado EM CADEIA COMPLETA (gzip→FD→LZMA→FVMAIN):
  DSDT+APIC+FACP+GTDT+SSDT×2+GTA4L presentes no Mu-gta4l-acpi.img (5.564.416B).
- ESD 22621.6060 ARM64 Pro pt-BR validado (wimlib: Setup Media + WinRE + Pro).
- Usuário NÃO tem OTG → plano B = WinPE ramdisk na ESP + autounattend + /installfrom.
- FLASH ACPI UEFI executado 18:3x (backup: uefi/boot-uefi-v1-backup.img = UEFI v1).
- Reboot de teste em andamento — esperando bootmgfw com ACPI.

## 2026-10-24 — Sessão 4 (maratona): firmware ×5 iterações + causa-raiz unificada
- Menu UEFI alcançado (escondendo EFI/); POWER=ENTER via transplante do
  ButtonsDxe.patched do lime (menu navegável; seleção OK).
- MSC app instrumentado → ERR STARTUSB ST=6 (NOT_READY) mesmo com stack USB+PMIC
  do lime → USB-device do gta4l precisa mais (DTB/UsbConfig) — pendente, não crítico.
- DESCOBERTA DO ACERVO JUN/2026 (docs/june-2026/): o usuário já tinha portado UEFI
  (Renegade → Mu-Silicium, fork gabrielfavera07 c/ CI), ACPI próprio, memory-map
  completo e DIAGNÓSTICO DEFINITIVO do storage: falta QCPEP (CORE_PWRCTL ack,
  pwr_irq SPI 352) → solução B2 = miniport sdhci-msm (sample WDK). E o build de
  junho era Canary 29610 (não boota em ARMv8.0) — hoje já temos 22621 ARM64 pronto.
- Firmware atual no tablet: v7 (ACPI+PNP0D40+PowerEnter+USB/PMIC lime).
- PRÓXIMO: teste definitivo 22621 + B2 miniport (ver docs/ROADMAP-CONSOLIDADO.md).

## Sessão 25/out/2026 (noite) — pipeline on-device + caça à corrupção
- install.esd do conversor UUP nasceu corrompido (chunk LZMS inválido; apply morreu em 1484/8631 MiB). PC reiniciou 2x — suspeita RAM/disco.
- Conversão minimalista replicada no WSL: export profissional.esd:3 --ref=UUPs/*.esd(+.ESD!)+refs-de-cabs → install.wim LZX.
  - BUG 1: UUPs têm ESDs-base com extensão MAIÚSCULA (.ESD: Desktop-Required, Foundation, EditionPack...) — glob Linux case-sensitive não via; Windows via (por isso o conversor original funcionava).
  - BUG 2: após reboot, pacote 7zip real (9zip) sumiu do vhdx do WSL (corrupção NUL já conhecida) → todos cabs "Can't open as archive". Fix: apt --reinstall 7zip.
  - BUG 3: harness background mata wsl.exe em ~5min e converte paths mesmo com MSYS_NO_PATHCONV=1. Fix: Start-Process detachado rodando conv-wsl.cmd; logs internos em /root/out.log.
- wimlib-imagex 1.14.4 estático ARM64 (glibc) FUNCIONA no TWRP: /data/wimlib-imagex (built em /mnt/c: libxml2+ntfs-3g+wimlib, relink -static manual em .libs/libwim.a).
- TWRP tem mkfs.ntfs (/system/bin/mkfs.ntfs). Sintaxe apply UNIX: wimlib-imagex apply install.wim 1 /dev/block/by-name/win (partição deve estar mkntfs'd; sem prefixo NTFS:).
- ESP inspecionada: falsos de hoje (Microsoft/, Boot/ = MassStorage 275KB) + junho em .off (bcdboot completo 22621-era, BCD 17/jun). Plano de restore definido.
- Unattend.xml (autologon favera + pt-BR + testsigning) em C:\woa-temp\Unattend.xml.

## 25/out (madrugada 26) — B2: firmware v8 + driver portado + cadeia pronta
- **v8** (`uefi/Mu-gta4l-v8-pwrirq.img`): pwr_irq 0x160 (SPI 352) adicionado ao _CRS do
  SDC1 no Kamorta DSDT linha 44 — compilada e JÁ FLASHADA no boot do tablet.
- **Driver B2 escrito** (`driver-b2/src/`): patch-msm.py injeta no sample WDK sdhc:
  CoreBaseAddress (+0x1000), MsmAcknowledgePwrctl (status 0x240→clear 0x248 com retry→
  ctl 0x24c com BUS/IO_SUCCESS), MsmInitializeVendorBlock (mask 0x244=0xF + drain),
  MsmCompletePwrctlHandshake (poll 50ms best-effort) — hooks: SlotInitialize, ISR,
  SetVoltage (pos POWER_CONTROL), SetSignaling (pos 1.8V). INF: ACPI\QCOM24BF,
  serviço sdhcmsm StartType=0 (boot). HS200/HS400 já zerados pelo sample (sem DLL).
- Offsets v5 confirmados no sdhci-msm.c: PWRCTL 0x240/244/248/24C; HC_MODE 0x78; DLL 0x200.
- Cadeia pronta: build-driver.cmd (monta EWDK→LaunchBuildEnv→msbuild ARM64) +
  inject-driver.cmd (DISM Mount-Wim/Add-Driver ForceUnsigned/Commit + BCD testsigning)
  + deploy-b2.sh (mkntfs+apply+BCD). install-w-drv.wim (3.66GB) e BCD já no C:.
- EWDK_ni_release_svc_prod1_22621_230929-1800.iso (15.9GB, fwlink 2249942) baixando em
  E:\VIBECODING\ewdk-22621.iso (curl detached com continue-at; morreu 2x, retomou).

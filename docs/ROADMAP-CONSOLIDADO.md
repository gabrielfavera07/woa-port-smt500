# ROADMAP CONSOLIDADO — WoA no SM-T500 (sessão 2026-10-24 + acervo jun/2026)

> Fusão do que a sessão de hoje provou com o acervo de junho (docs/june-2026/).
> Próxima ação concreta no final.

## O MURO REAL (unânime nas duas eras)
O Windows ARM64 >24H2 **não roda** no Kryo 260 (ARMv8.0 sem LSE) — teto **22621–22623**.
- Junho usava Canary 29610 → kernel morria pré-`KdInitSystem` (versão errada).
- Hoje: **ESD 22621.6060 ARM64 Pro pt-BR já baixado e validado** (image-work/uup/UUPs/).

## Segundo muro (provado por engenharia em junho): STORAGE/PEP
Com build certa, o kernel carrega (bolinhas) e **trava na I/O eMMC**: falta o **QCPEP**
(ack do handshake `CORE_PWRCTL`, pwr_irq GIC SPI 352 + rails/clocks PMIC/GCC).
Solução escolhida em junho: **B2 — miniport SDHCI-MSM auto-contido** (sample WDK
`Windows-driver-samples/sd/miniport/sdhc`): manter clock GCC, ack PWRCTL (rails fixas),
forçar HS/DDR52 sem DLL/tuning. Ver docs/june-2026/DIAGNOSTICO-STORAGE-WINDOWS-PEP.md.

## O que a sessão de HOJE acrescentou (estado atual)
1. **Firmware v7 no boot** (Mu-Silicium upstream + nossos patches):
   - ACPI gta4l criado (SSDT overlay EMMC-on/UFS-off; base Kamorta) — primeira vez
     no upstream; tabelas validadas contra o DTB real (GICD/GICR/timers = match).
   - **DSDT com `_CID PNP0D40`** → liga `sdport.sys` inbox (necessário p/ B2 reconhecer).
   - **POWER = ENTER** (transplante ButtonsDxe.patched do lime — menu 100% navegável).
   - Stack USB-device + PMIC do lime transplantados (MSC ainda `ST=6 NOT_READY` —
     pendente; provavelmente DTB USB/UsbConfig do device).
   - MSC app instrumentado com auto-diagnóstico na tela (v5+).
2. **Diagnósticos fechados**: BCD de junho íntegro/GUIDs corretos; boot loop via
   watchdog; menu inalcançável por falta de Enter (resolvido); InitializeLibrary 0xC0000225
   era do bootmgfw na build errada de Windows.
3. **Instalador pronto sem MSC**: ESD 22621 + Apply-WindowsToTablet.ps1 (DISM/bcdboot/
   testsigning/LabConfig). Alternativa a MSC: **aplicar ESD num VHD no PC e dd→p83**.
4. Drivers WOA baixados (era SDM845, genérico); **storage tem que ser inbox+B2**.

## Pipeline de firmware (validada hoje, 7 iterações)
WSL2: `source /root/mu-venv/bin/activate && cd /root/Mu-Silicium && python3 build_uefi.py -d gta4l -c`
→ `Mu-gta4l.img` (~5.5MB, boot.img v1+BootShim+gzip). Flash via TWRP dd em `boot`
(NUNCA fastboot boot — bug SMMU 0x1D5, doc junho). Imagens em uefi/: v1..v7.

## PRÓXIMAS AÇÕES (ordem)
1. **[TESTE DEFINITIVO]** Instalar 22621 limpo (VHD→dd p83 + ESP by bcdboot, drivers
   off) e bootar com a v7: o kernel passa do `KdInitSystem`? Chega nas bolinhas?
   → se sim, confirmado que só falta B2. (Primeira vez no mundo com 22621+ACPI gta4l.)
2. **[B2]** Miniport SDHCI (EWDK + sample WDK; ~3 funções; assinar test-cert;
   injetar offline via DISM). É o último boss para boot completo.
3. **[MSC-ST=6]** (opcional) corrigir USB-device p/ instalação mais cômoda — ou
   manter VHD-dd (funciona sem).
4. **[DUALBOOT]** só depois do Windows provado (doc de junho tem o desenho).
5. Upstream PR: overlay gta4l ACPI + DSDT CID + botões → Project-Silicium (o
   gta4lPkg voltaria a vida com contribuição real).

## Artefatos-chave
- Firmware: `uefi/Mu-gta4l-v7-pmiclime.img` (no tablet agora)
- Windows: `image-work/uup/UUPs/professional_pt-br.esd` (+Setup/WinRE imgs 1,2)
- Backups: `device/dumps/backup-critical/` (501MB) + boot imgs em uefi/
- Acervo junho: `docs/june-2026/` (7 docs) + fork CI `gabrielfavera07/Mu-Silicium`

## 25/out (noite) — TESTE DEFINITIVO CONCLUÍDO: QCPEP WALL CONFIRMADO
Boot com 22621.6060 limpo (verify 100%, APPLY-DONE-0, ESP junho, v7): **travou no spinner
IGUAL a junho** → teoria "build errado 29610" DESCARTADA. Cadeia OK até o kernel (XBL→UEFI
v7→bootmgfw→winload→kernel desenha bolinhas→congela no init de storage). Logo "SI" no boot
= Mu-Silicium (correta; Renegade era a de junho).

### Diário da instalação (já no worklog, resumo):
install.esd do conversor nasceu corrompido → 3 ESDs-base .ESD corrompidos NO E: (SHA1) →
re-baixados p/ C:\woa-temp\uupfix (API uupdump id b90029a9-23b4-4558-9687-2142f79e5ae2,
cache-buster p/ URLs) → conversão própria export+refs duplos → install.wim LZX verify 100%
→ wimlib estático ARM64 no TWRP → mkntfs+apply 40MB/s → ESP restore → reboot.

### B2 — MINIPORT SDHCI-MSM (PRÓXIMO PASSO, blocker: espaço p/ EWDK)
- Sample WDK extraído: `driver-b2/sample-sdhc/` (sdhc.c 3465L, sdhc.h 2126L, .inx, vcxproj)
- Referência Linux: `driver-b2/refs/sdhci-msm.c` (+sdhci.h, pltfm)
- EWDK 22H2 (10.0.22621): https://go.microsoft.com/fwlink/?linkid=2249942 →
  EWDK_ni_release_svc_prod1_22621_230929-1800.iso = **15.9GB** — NÃO CABE (C: 8.6, E: 2.6;
  compact do vhdx libertaria só ~4GB — interior tem 39GB usados).
- OPÇÕES: (a) user liberar ~16GB no E:, (b) pendrive/HD USB ≥20GB p/ o ISO, (c) hack
  range-download só dos arquivos arm64 (~4GB, lento/frágil).
- Plano do port: PCI→ACPI/MMIO 0x04744000 (DSDT _CRS), vendor regs HC_REG_OFF 0x1000+,
  ack PWRCTL (SPI 352, CORE_PWRCTL_* mask+ack, BUS_SUCCESS), DLL bypass, eMMC DDR52/HS
  fixo, rails fixas (sem régua PMIC dinâmica), ADMA2 do sample.
- Injeção offline: .sys→/Windows/System32/drivers + chave Services no hive SYSTEM (chntpw
  no WSL, Start=0 boot) dentro do install.wim (update wimlib) + BCD testsigning (bcdedit
  /store na ESP via TWRP mount) → re-apply → boot.

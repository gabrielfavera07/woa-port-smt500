# WOA-Port SM-T500 — Windows 11 ARM64 nativo no Galaxy Tab A7

Port **nativo** (sem emulação de sistema) de Windows on ARM para o tablet
**Samsung Galaxy Tab A7 2020 (SM-T500 / `gta4lwifi` / Snapdragon 662 "bengal")**.

## Estado em uma linha
Hardware mapeado e documentado; backup de segurança feito; partições Windows já existem no
aparelho (tentativa jun/2026 encontrada); **faltam: payload UEFI bengal (obter/compilar),
ISO ARM64 22621 e drivers** — caminho completo documentado em `docs/phases/PIPELINE.md`.

## Ler primeiro
1. `device/profile/DEVICE-PROFILE.md` — dossiê do hardware (o que existe, endereços, limites)
2. `rea-analysis/BOOT-CHAIN.md` — como o tablet dá boot e onde o UEFI se encaixa (com evidências)
3. `docs/phases/PIPELINE.md` — as 8 fases com critérios de saída (gate) de cada uma
4. `docs/research/` — como os ports community (Renegade/edk2) funcionam + estado de drivers

## Verdades técnicas que definem este projeto
- **Teto de versão: Windows 11 22621–22623 (22H2/23H2)** — o Kryo 260 é ARMv8.0 sem LSE;
  24H2 exige ARMv8.1. (A ISO Win10 x64 que existia no workspace não serve — arquitetura errada.)
- **Samsung não tem fastboot** — UEFI vai gravado no slot `boot` via TWRP `dd`/Odin (scripts prontos).
- **GPU Adreno 610 sem driver Windows** → vídeo via Microsoft Basic Display (CPU). Fato de 2026,
  sem solução community conhecida — documentado como risco nº 1.
- Wi-Fi/BT (WCN3990), áudio (WCD937x), touch (Synaptics TCM) dependem de drivers/DSDT do port.

## Estrutura
```
device/       dumps (backup crítico 501MB), firmware stock extraída, análise (GPT/DTB), profile
docs/         research (relatórios com fontes) + phases (PIPELINE.md)
scripts/      device (TWRP: backup/flash/dual-boot) + image (PC: DISM/bcdboot PowerShell)
tools/        parsers: GPT, FDT(DTB), boot.img, ELF, strings — python puro, sem dependências
rea-analysis/ análise da cadeia de boot com evidência
drivers/      (a preencher) drivers ARM64 por subsistema + fontes
uefi/         workspace do payload edk2-bengal (fase 2)
```

## Comandos rápidos (tablet no TWRP)
```bash
adb shell sh /tmp/backup-critical.sh            # Fase 0 (JÁ EXECUTADO 2026-10-24)
adb push scripts/device/flash-uefi.sh /tmp/     # quando houver boot-uefi.img (fase 2)
adb shell sh /tmp/flash-uefi.sh /external_sd/boot-uefi.img
adb shell sh /tmp/restore-android-boot.sh       # volta ao LineageOS
```

## Regras de segurança do projeto
1. Nunca gravar em `efs/sec_efs/persist/modemst*` (backup existe — nem tocar).
2. Sempre salvar `boot` atual antes de gravar UEFI (script já faz).
3. Mudança de partição só depois de `fixgpt` + verificação no TWRP.
4. Toda alteração registrada em `worklog.md` com resultado do gate.

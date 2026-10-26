# Como obter a ISO certa (ARM64 22621) — e por que a ISO atual não serve

## A ISO que você tem
`OFICIAL_OS_TO_REA/OS_PERSONAL_COMPUTER.iso` = **Windows 10 x64 PT-BR** (`CCCOMA_X64FRE_PT-BR_DV9`).
x64 não dá boot em CPU ARM sob nenhuma circunstância. Ela fica de referência apenas.

## O que baixar
**Windows 11 22H2 ARM64, build 22621.x** — via [UUP Dump](https://uupdump.net):

1. `Latest builds` → filtrar `22621` (ou "Windows 11 22H2") → escolher build **arm64**;
2. Edition: **Pro**; Language: **Português (Brasil)**;
3. Download type: **Download and convert to ISO** ✓ Include updates;
4. Baixar o ZIP, extrair, rodar `uup-download-windows.cmd` (baixa ~4-5 GB e monta a ISO).

> Por que 22621 e não 24H2: o Kryo 260 do Snapdragon 662 é ARMv8.0 **sem LSE atomics**;
> Windows 11 24H2 exige ARMv8.1+ (fonte: corte oficial do SDM835 no 23H2→24H2). Detalhes em
> `docs/research/`. Builds 22621–22623 são o teto definitivo deste hardware.

Alternativa: se a Microsoft ainda publicar ISO ARM64 22H2/23H2 em
<https://www.microsoft.com/Software-download/windows11arm64>, ela também serve (é a mesma base).

## Depois de obter
- Extrair `sources/install.wim` (7-Zip abre ISO);
- Verificar índices/edições: `dism /Get-WimInfo /WimFile:install.wim`;
- Seguir `scripts/image/Apply-WindowsToTablet.ps1` (modo Mass Storage).

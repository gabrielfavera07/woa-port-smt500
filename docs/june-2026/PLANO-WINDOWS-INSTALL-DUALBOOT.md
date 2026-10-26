# PLANO — Instalação Windows 11 ARM64 (dualboot) no SM-T500 via UEFI Renegade

> **Regra de ouro (pedido do usuário):** estudar, planejar e VERIFICAR tudo antes de executar.
> Nenhum passo destrutivo sem passar pelos portões de verificação (§7). Certeza absoluta primeiro.
> Status: **PLANO — nada executado ainda.**

## 0. Estado atual (tudo staged ✅)
- UEFI Renegade boota até o Shell (world-first) — branch `diag-paint`, artefato direto da CI.
- ACPI completo na firmware: MADT(GIC)/FADT/GTDT/DSDT + **SSDT-sdhc (SDC0 eMMC)** — build verde.
- `install.wim` Win11 ARM64 (4.0GB, build 29610) em `E:\tmp\woa-iso\pkg2\ISOFOLDER\sources\install.wim`.
- Backups: boot+vbmeta do Lineage/Droidspaces em `e:\tmp\bengal-edk2-port\RESTORE-droidspaces\`.
- Stock firmware (Odin) em `_stock/` (BL/AP/CP/CSC) — recuperação total possível.

## 1. Decisão de arquitetura: FASEAR (single-boot primeiro) ⭐
**Dualboot é o objetivo, mas NÃO o primeiro passo.** Análise do mecanismo de dualboot do Renegade
(`tools/BootShim/BootShim.Dualboot.S`): a `boot.img` precisa conter **[BootShim + kernel Android +
UEFI juntos]**, e um **flag em RAM (0x17FE00000, magic "RA")** setado por um tool "simple-init"
decide qual boota. Isso exige o tool **nos dois OSes** (Android E Windows) + a boot.img combinada.
→ **Muita complexidade pra validar de uma vez.**

**Plano faseado (de-risca):**
- **FASE A — Windows single-boot:** UEFI fica em `boot` (como hoje), Windows na eMMC. Prova que o
  Windows BOOTA (o teste real do nosso storage ACPI). Lineage fica temporariamente não-bootável
  mas **100% restaurável** (backup pronto). Risco controlado.
- **FASE B — Dualboot:** só DEPOIS do Windows provado, montar a boot.img combinada + simple-init.

> Justificativa: a maior incerteza é "o storage inbox funciona?" (BSOD ou não). Não faz sentido
> investir na complexidade do dualboot antes de saber se o Windows sequer boota. Faseando, cada
> risco é isolado.

## 2. Layout de partições (eMMC) — A VERIFICAR (§7.1) antes de mexer
A eMMC tem 80 partições (GPT). Mapa de nomes conhecido (de `ls /dev/block/by-name`). **Tamanhos
exatos só lendo a GPT viva** (`sgdisk -p /dev/block/mmcblk0`) — portão §7.1.

**Partições CRÍTICAS (NUNCA tocar — quebram o boot do SoC):**
`xbl`(p1), `xbl_config`(p2), `tz`(p5), `rpm`(p6), `hyp`(p7), `keymaster`(p8), `cmnlib`(p9/10),
`abl`(p12), `devcfg`(p18), `vbmeta`(p11), `vbmeta_samsung`(p19), `uefisecapp`(p17), `modem`(p36),
`dsp`(p32), `boot`(p69 - nossa UEFI), `recovery`(p70 - lifeline de restore).

**Espaço pro Windows:** a única partição grande é `userdata`(p80, a última, ~26GB). Plano:
**encolher userdata** e carved 3 partições Windows no espaço liberado:
- **ESP** (EFI System, FAT32) — 300 MB
- **MSR** (Microsoft Reserved) — 16 MB
- **Windows** (NTFS) — ~18-20 GB (resto pro userdata encolhido do Lineage)

⚠️ **Encolher userdata DESTRÓI os dados do Android, incluindo o Droidspaces tunado.** → Portão
§7.2: backup do Droidspaces ANTES. (userdata é criptografado; backup = a partição inteira via dd,
ou aceitar a perda do container e refazer depois.)

## 3. Processo de instalação offline (sem USB/OTG)
Como NÃO temos OTG, o install é offline (preparado no PC, gravado por `dd` via Android root):

**3a. Preparar imagens de partição no PC (Windows x64, tem DISM):**
1. `ESP.img` (FAT32, 300MB): criar FS FAT32 vazio.
2. `Windows.img` (NTFS, ~18GB): criar FS NTFS vazio, montar.
3. `DISM /Apply-Image /ImageFile:install.wim /Index:1 /ApplyDir:<Windows.img montada>`.
4. `bcdboot <Windows>\Windows /s <ESP montada> /f UEFI /l pt-br` → cria o Windows Boot Manager
   (`\EFI\Microsoft\Boot\bootmgfw.efi` + BCD) na ESP.
5. (drivers) `DISM /Image:<Windows> /Add-Driver /Driver:<pasta> /Recurse` — storage já está no
   ACPI/firmware (não precisa .sys aqui no PATH 1 inbox); injetar só se PATH 2 (miniport).

**3b. Gravar na eMMC (via Android root, adb dd):**
- `dd if=ESP.img of=/dev/block/by-name/<part_esp>` etc. — DEPOIS de reparticionar a GPT.

> NOTA crítica de DISM: o ApplyDir não pode ser uma imagem solta — precisa de partição/volume
> montado. No Windows host: criar VHDX, particionar, aplicar, depois `dd` o conteúdo. Detalhar no §7.4.

## 4. Boot do Windows (Fase A)
- UEFI em `boot` → BDS (MdeModulePkg BdsDxe, padrão) → procura boot entries / `\EFI\BOOT\bootaa64.efi`
  ou `\EFI\Microsoft\Boot\bootmgfw.efi` na ESP → **Windows Boot Manager** → BCD → partição Windows.
- O Windows lê o ACPI da nossa firmware: MADT(GIC 0x0f200000)+GTDT(timer)+FADT+DSDT+**SSDT-sdhc(eMMC)**.
- Driver de storage: **inbox sdport.sys/sdhc** casa no `PNP0D40` do SDC0 → enxerga a eMMC.

## 5. Drivers — o que Windows precisa pra bootar (mínimo)
- **Boot-crítico:** ACPI plataforma (✓ temos) + **storage** (✓ SDC0/inbox PATH 1).
- **PEP (Power Engine Plugin):** Qualcomm-específico, NÃO existe pro Bengal. **Windows boota SEM
  PEP** (sem gerência de energia/sleep, mas boota). Não é boot-crítico.
- **Clock/GPIO:** se o storage inbox for auto-suficiente (configura o próprio clock via SDHCI std),
  não precisa pro boot. A confirmar on-device.
- **Display:** GOP do SimpleFbDxe (✓ a UEFI já mostra imagem) → Windows usa BasicDisplay no FB.
- Resto (Adreno/WiFi/audio/touch) = pós-boot, não existem → "Windows utilizável".

## 6. Riscos e recuperação (mapeado)
| Risco | Mitigação / Recuperação |
|---|---|
| GPT corrompida ao reparticionar | Odin re-particiona (stock) + reflash; recovery(p70) intacta |
| Perda do Droidspaces (userdata) | Backup §7.2 antes; ou aceitar e refazer |
| BSOD INACCESSIBLE_BOOT_DEVICE | storage inbox falhou → PATH 2: miniport portado do sdhci-msm.c |
| Windows não acha boot | revisar BCD/ESP; bootaa64.efi fallback |
| Brick do boot | recovery(p70) → adb → restaurar boot Lineage (backup pronto) |
| eMMC pequena demais p/ Windows | §7.1 confirma; se não couber, single-boot dedicado (sem Lineage) |

## 7. PORTÕES DE VERIFICAÇÃO (antes de QUALQUER passo destrutivo)
**7.1 — Ler a GPT viva (NÃO-destrutivo):** aparelho em Lineage/recovery → adb → `sgdisk -p
/dev/block/mmcblk0` (ou parted). Confirmar: tamanho total da eMMC, tamanho/offset de userdata,
último setor, espaço real. **SEM isso, nenhum cálculo de partição é confiável.**

**7.2 — Backup do que será destruído:** decidir Droidspaces (dd da userdata p/ PC se couber, ou
aceitar perda). Confirmar backups boot/vbmeta/recovery + stock Odin prontos.

**7.3 — Matemática das partições:** com os números do 7.1, calcular EXATO: novo tamanho da
userdata, offsets/sizes da ESP+MSR+Windows, alinhamento (1MB), sem sobrepor nada. Revisar 2x.

**7.4 — Validar o WIM no PC:** `DISM /Get-ImageInfo /ImageFile:install.wim` (precisa admin);
testar o apply num VHDX pequeno antes de mexer na eMMC.

**7.5 — Ensaio do reparticionamento:** montar os comandos sgdisk/parted exatos, revisar, e só
então executar — com a recovery como rede de segurança.

## 8. Sequência de execução (só após TODOS os portões §7)
1. (Fase A) Backup §7.2 → reparticionar eMMC (encolhe userdata, cria ESP/MSR/Windows) via adb.
2. Preparar ESP.img+Windows.img no PC (DISM apply + bcdboot).
3. `dd` ESP/Windows nas partições novas.
4. Reboot → UEFI → BDS → Windows Boot Manager → **ver se boota / qual BSOD**.
5. Iterar: se INACCESSIBLE_BOOT_DEVICE → PATH 2 (miniport). Se bootar → 🎉 + Fase B (dualboot).

## 9. PRÓXIMO PASSO (não-destrutivo)
**Portão §7.1:** trazer o aparelho pra Lineage/recovery e ler a GPT viva. É o único jeito de ter
os números exatos, e é 100% seguro (só leitura). Com eles, faço a matemática das partições (§7.3)
e revisamos juntos ANTES de qualquer escrita.

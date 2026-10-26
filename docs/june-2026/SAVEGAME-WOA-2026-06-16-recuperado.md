# SAVE GAME — Windows 11 ARM nativo no Galaxy Tab A7 SM-T500
**Consolidado em 2026-06-16 a partir das 2 conversas do Claude Code (VSCode).**
Fontes: `7f85dfe7-*.jsonl` (86MB, "Enable native W11 ARM", desde 09/jun) + `1e26467a-*.jsonl` (5.9MB, "Reviver UEFI do Mu", 15-16/jun).
Este doc é o estado mais atual — mais novo que os CHECKPOINT/BIBLE de 13/jun.

---

## 1. Objetivo
Windows 11 ARM **bare-metal** (sem emulação/VM) no **Samsung Galaxy Tab A7 SM-T500**.
- SoC: **Snapdragon 662 / SM6115**, plataforma **"bengal"**, codename do device **gta4l** (gta4lwifi).
- Porte de UEFI via **Mu-Silicium** (edk2 / Renegade / Project-Silicium).

## 2. Pipeline (montada e testada de ponta a ponta)
1. **Build UEFI na nuvem:** repo `gabrielfavera07/Mu-Silicium`, workflow **`build-gta4l.yml`** (`gh workflow run build-gta4l.yml -R gabrielfavera07/Mu-Silicium`). GH CLI autenticado (conta gabrielfavera07, escopo `workflow`) → todo o build é dirigível por CLI.
   - Plataforma: `Platforms/Samsung/gta4lPkg/`.
   - ACPI: `Platforms/Samsung/gta4lPkg/AcpiTables/` → APIC.aml (MADT), FACP.aml (FADT), GTDT.aml, DSDT.aml. (PPTT.aml removido — era inválido, 14 bytes.)
   - Console DEBUG vai **pra TELA** via `FrameBufferSerialPortLib` → build DEBUG mostra o log de boot na tela do tablet (cores = estágios).
2. **Boot.img híbrido:** script Python (struct/zlib/gzip/hashlib) embute a UEFI do Mu como payload **gzip** (`gzip.compress(..., compresslevel=9, mtime=0)`) → gera `hybrid-mu-acpi.img` (~7.6MB). Dir: `e:/tmp/bengal-edk2-port/`.
3. **Flash (IMPORTANTE: flashar, NÃO `fastboot boot`):**
   `adb push hybrid.img /tmp/ma.img` → `adb shell 'dd if=/tmp/ma.img of=/dev/block/by-name/boot bs=4M; sync'`.
   ⚠️ Boot efêmero (`fastboot boot`) dispara o bug de handoff **SMMU 0x1D5** — sempre gravar na partição `boot`.

## 3. DIAGNÓSTICO FECHADO — por que falta só o Windows 23H2
Por eliminação rigorosa, a UEFI já está **funcionalmente idêntica a um device que comprovadamente boota Windows nesse chip** (referências lime/caprip, SM6115):
- **Mapa de memória CORRETO:** todas as 19 regiões `/reserved-memory` do DTB (hyp_region, xbl_aop, sec_apps, smem, modem→gpu PIL, cont_splash/disp, dfps, removed_region, ss_plog/ramoops/sec_debug) estão reservadas no `PlatformMemoryMapLib.c`. Nenhuma região protegida pelo TZ marcada como RAM usável.
- **ACPI alinhada ao lime:** MADT/APIC, FADT, GTDT, DSDT.
- O kernel **ainda morre antes do `GetVariable`** (pré-`KdInitSystem`).

**Conclusão:** o único delta restante é a **versão do Windows**.
- Nosso build é **Canary 29610 — novo demais**. Ports SM6115 documentam que **24H2+ NÃO boota**; precisa **23H2 ou mais antigo**.
- Entry do gta4l no Project-Silicium: **"BIT-8 Version is Required on this Device!"** → usar imagem ARM64 **23H2-ou-mais-antiga**, casando **BIT-8**.
- **Killer secundário casado:** `KernelErrataPatcherLib` imprime **"Failed to Auto-Detect Windows Semester!"** → não reconhece o winload do 29610 → não aplica `PatchOsLoaderArm64TransferToKernel` (patch do handoff p/ errata Qualcomm). Um winload **23H2 retail** é reconhecido E tem PDB no symbol server (o do 29610 Insider não existe).

**Pista histórica:** numa sessão anterior o kernel JÁ CHEGOU NAS BOLINHAS girando (vivo, travou só no storage). A morte precoce atual é uma **REGRESSÃO** — suspeito #1 = instalação do Windows degradada pelas muitas re-gravações da p83 → reforça **reinstalar limpo com 23H2**.

## 4. Debug com kd (KDNET) — o que aprendemos
- `kd.exe`: `C:\Program Files\WindowsApps\Microsoft.WinDbg_1.2603.20001.0_x64__8wekyb3d8bbwe\amd64\kd.exe`
- Comando: `& $kd -k net:port=50005,key=1.2.3.4 -b -cf <script.txt>`
- Symbols: `.sympath srv*e:\symcache*https://msdl.microsoft.com/download/symbols`
- **kd CONECTOU e SEGUROU o winload** (break em EL1, controle total — inédito). MAS:
  - O boot debugger **desconecta no handoff** ("Shutdown occurred", 3× confirmado). O kernel pré-`KdInitSystem` é **invisível via KDNET** (limitação da arquitetura de debug da MS, não nossa).
  - Sem PDB do winload 29610 → `OslArchTransferToKernel` "Couldn't resolve" (só exports). Outro motivo p/ ir de 23H2.

## 5. Plano de deploy (partições do device)
- **ESP → p81**, **Windows → p83** (`mmcblk0p83`, ~23975MB / ~24GB). Scratch → **p80**.
- **BCD/ESP do device já está correto:** `hypervisorlaunchtype off` + GUIDs certos. Estratégia de menor risco: **manter ESP/BCD do device** e só **sobrescrever o conteúdo do Windows na p83** (dd só troca conteúdo; GUID da p83 não muda → BCD continua apontando certo).
- **VBS-off:** BCD `hypervisorlaunchtype off` (já aplicado). Se não bastar, registry offline em `HKLM\System\CurrentControlSet\Control\DeviceGuard` (`EnableVirtualizationBasedSecurity=0`, `RequirePlatformSecurityFeatures`, `Locked`) + cenário `SystemGuard` (Secure Launch). Motivo: winload tenta Secure Launch EL1→EL2 num device sem flag devcfg de fábrica-Windows → falha e mata o boot.
  - **Obstáculo:** essas chaves estão no hive SYSTEM na p83 (NTFS), e o **recovery do Lineage não monta NTFS** (já falhou; tentar `ntfs3`).
- **Método de deploy que FALHOU (não repetir):** `adb push 19GB → /dev/block/by-name/userdata` clobberou o symlink (virou arquivo no tmpfs/RAM de 3GB → "No space left"). Bloco real intacto. Caminho bom: extração on-device `dd skip=632 count=18479` de p80 → p83.

## 6. ESTADO ATUAL EXATO (onde a sessão executora parou — 16/jun ~02:4x)
**Tarefa:** montar a imagem **Windows 23H2** num VHD no PC (`e:\tmp\woa-iso\winimg.vhd`, 18.7GB fixo) → DISM aplica 23H2 → bcdboot → VBS-off → deploy na p83 → boot → probe.

**Bloqueio sendo resolvido AGORA:** criação do VHD via diskpart falhava.
- `New-VHD` falha → **Hyper-V não instalado** (por isso usa diskpart).
- `Start-Process diskpart -Verb RunAs -RedirectStandardOutput` = inválido (RunAs incompatível com Redirect). **Fix usado:** wrapper `.ps1` elevado com `diskpart /s script.txt | Out-File out.txt`.
- Causa raiz do diskpart: **2 VDisks fantasma** apontando p/ winimg.vhd (de tentativas falhas) + **letras S:/W: ocupadas** ("A letra de unidade S: não está livre"). `Restart-Service vds` não liberou as letras.
- **Próxima ação (em andamento):** reescrever o script de criação usando letras livres **Y:/Z:** em vez de S:/W:, limpar fantasmas, criar VHD, aplicar 23H2, bcdboot.

## 7. Próximos passos (ordenados)
1. ✅ Criar VHD 23H2 com letras Y:/Z: (destravar o diskpart). Origem da imagem: **23H2 ARM64 via UUP dump** (~4-5GB) — único trabalho novo de download.
2. DISM `Apply-Image` da 23H2 no VHD → `bcdboot` → garantir VBS/hypervisor off.
3. Deploy: sobrescrever só o conteúdo da **p83** (manter ESP/BCD do device).
4. Flashar a UEFI corrigida na `boot` (não `fastboot boot`).
5. Reiniciar → **probe** (cores na tela / bolinhas do Windows). kd na 50005 opcional.
6. Critério de vitória: **logo do Windows + bolinhas girando** = handoff cruzado + kernel vivo.

## 7b. DEPLOY EXECUTADO — receita confirmada (16/jun ~23:5x → 00:xx)
VHD 23H2 ficou pronto (Y:/Z:, DISM index 1 = Pro de `install-23h2.wim`, bcdboot UEFI). VBS-off aplicado offline no hive SYSTEM do VHD: `OFFV\ControlSet001\Control\DeviceGuard` → `EnableVirtualizationBasedSecurity=0`, `Locked=0`, cenário `SystemGuard=0`. Layout GPT do VHD: MSR 15MB, ESP 16MB(600MB), MSR 616MB(16MB), **Windows 632MB / 18503MB**.

Sequência de deploy (tablet no recovery, "adb on"):
1. UEFI corrigida → `dd if=hybrid-mu-acpi.img of=/dev/block/by-name/boot bs=4M` (boot = p69).
2. vbmeta flags=2 → `dd if=vbmeta-hybrid.img of=/dev/block/by-name/vbmeta` (p11).
3. Staging: `mke2fs -t ext4 -F /dev/block/mmcblk0p80` → mount `/stage` (26GB) → `adb push winimg.vhd /stage/win.vhd` (~20GB).
4. Gravar Windows na p83: `dd if=/stage/win.vhd bs=1M skip=632 count=18503 of=/dev/block/by-name/win conv=fsync` (win = p83) → `umount /stage; sync`.
5. Reboot → **probe**.
**Segurança confirmada:** só toca boot/vbmeta/p80/p83 — nada de xbl/abl/sbl/pgpt. Download mode + Odin intactos.

## 8. Becos sem saída (NÃO repetir)
- Build Windows **24H2+/Canary 29610**: não boota nesse SoC. Só 23H2-ou-mais-antigo + BIT-8.
- `fastboot boot` efêmero: dispara SMMU 0x1D5. Sempre flashar a `boot`.
- `adb push` direto pra `by-name/userdata`: clobbera symlink, enche RAM. Usar dd on-device.
- Debugar o kernel pré-KdInitSystem por KDNET: impossível (boot debugger sai no handoff).
- Mapa de memória / ACPI: já exaustivamente corretos — não é aí.
- conv1 (86MB) trava em erros de Usage Policy ("cyber content") ao ler `Winload.c` do KernelErrataPatcher. Por isso a conv2 foi aberta. (É WoA legítimo de aparelho próprio.)

## 9. Caminhos e artefatos
- Working dirs PC: `e:\tmp\Mu-Silicium`, `e:\tmp\woa-iso`, `e:\tmp\bengal-edk2-port`, `e:\symcache`.
- Docs do projeto: `E:\VIBECODING\WIN SAMSUMG A7 TAB\` (CHECKPOINT-UEFI-BOOT-2026-06-13.md, WOA-PORTING-BIBLE-SMT500.md, PLANO-WINDOWS-INSTALL-DUALBOOT.md, PROBLEMA-UEFI-BENGAL.md, DIAGNOSTICO-STORAGE-WINDOWS-PEP.md, scripts fix-bcd*.ps1, inject-driver.ps1).
- Stock firmware: `SM-T500_3_20240719063530_..._fac.zip` (rede de segurança, sempre recuperável via Odin/Download mode).
- Transcripts originais: `C:\Users\Favera\.claude\projects\e--VIBECODING-WIN-SAMSUMG-A7-TAB\`.
- Digests legíveis: `C:\tmp\conv1_enable.txt`, `C:\tmp\conv2_reviver.txt`, `C:\tmp\conv1_narrative.txt` (regerar com `C:\tmp\extract_claude.py`).

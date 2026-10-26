# CHECKPOINT — Primeiro boot edk2-msm/Renegade num SM6115 "Bengal" (SM-T500) — 2026-06-13

> Marco histórico: a UEFI edk2 **bootou** no Galaxy Tab A7 (SM-T500, SM6115 Bengal) pela
> primeira vez no mundo — do PrePi até a fase DXE/BDS, com console na tela. Duas sessões
> anteriores travaram em "splash mudo". Este documento registra COMO foi destravado, pra
> reprodução em qualquer device irmão.

## TL;DR da virada
A causa raiz de 20+ boots falhos **não era** AVB, EL, PrePi, mapa de memória nem display.
Era o **empacotamento do boot.img — especificamente o DTB**. O ABL da Samsung exige o DTB
multi-board genuíno pra **selecionar e lançar** o kernel. Nosso fdt único de 0.8MB não casava
→ o ABL aceitava a assinatura mas **nunca executava** nosso código (silenciosamente).

## A cadeia de diagnóstico (o que provou cada coisa)

### 1. Provar se o código roda (independente de display)
- BootShim de diagnóstico que, como 1ª instrução, **reseta via PSHOLD `0x0440b000`** (+ pinta
  `cont_splash 0x5c000000`). Resultado inicial: **splash estático** = código não roda.

### 2. Isolar AVB vs formato
- Peguei o kernel Lineage **genuíno** (que boota) e **re-assinei com a NOSSA pipeline avbtool**
  (testkey_rsa4096, mesmos params do CI). **Bootou** → **nossa pipeline AVB está CORRETA**.
  Logo o bug é o **formato do boot.img**, não o AVB.
- Pipeline AVB local (Windows): precisa `--salt` fixo (não há `/dev/urandom`):
  ```
  avbtool add_hash_footer --image X --partition_name boot --partition_size 100663296 \
    --rollback_index 1 --algorithm SHA256_RSA4096 --key testkey_rsa4096.pem --salt <64hex>
  # relayout: AVBf nos últimos 64 bytes da partição de 96MB
  avbtool make_vbmeta_image --output vbmeta.img --algorithm SHA256_RSA4096 \
    --key testkey_rsa4096.pem --include_descriptors_from_image X \
    --rollback_index 1 --flags 2 --padding_size 65536
  ```
  pubkey sha1 = `2597c218aae470a130f61162feaae70afd97f011` (bate com o device).

### 3. Isolar qual parte do container
- Comparação cirúrgica (genuíno que boota vs nosso que não): iguais em header v2 / page 4096 /
  name `SRPTC24A006` / addrs. **Diferiam**: ramdisk (2.4MB vs 1 byte), cmdline (presente vs
  vazia), **DTB (4.46MB multi-board vs 0.82MB fdt único)**.
- **Teste híbrido decisivo:** boot.img = **container genuíno (ramdisk+dtb+cmdline) + NOSSO kernel
  UEFI**. Flash → **TELA VERMELHA + BOOTLOOP** = nosso kernel RODOU. Provado: o ABL lança nosso
  kernel quando o **DTB é o genuíno**. (E o display ESTÁ ligado no handoff.)

## A SOLUÇÃO (empacotamento)
Empacotar o boot.img UEFI com **DTB + ramdisk + cmdline genuínos** (do boot do Lineage), em vez
do fdt único. Método atual (manual, funciona): `hybrid_build.py` injeta nosso kernel no container
genuíno; depois assina com a pipeline AVB acima. (TODO: integrar no build/mkbootimg pra artefato
direto.)

## Os dois fixes de boot que destravaram a UEFI
1. **DTB/container genuíno** (acima) → ABL passa a lançar o kernel.
2. **Mem pool**: `PcdUefiMemPoolSize 0x0E000000 → 0x0D800000` (sm6225.dsc). O pool ia até
   `0x71900000`, invadindo a região **SS PLOG reservada** da Samsung (`0x71100000+`), e o `Pi.c`
   põe a stack do DXE no topo do pool → stack em memória reservada → **DxeCore travava**.
   Encolhido pra terminar em `0x71100000` (dentro da DXE Heap cacheável). → DxeCore passa.

## Estado alcançado (console real na tela)
```
Renegade Project edk2-msm (AArch64)   Firmware d4fb3c1
UEFI Memory Base=0x63900000 ... Configure MMU In/Out ... PlatformPeim
DecompressFirstFv ... Loading DxeCore @0x5DAF8000  (passou com o fix #2)
-> cascata DXE: DevicePathDxe, CapsuleRuntimeDxe, HiiDatabase, FontDxe, BdsDxe, AdcDxe...
-> TRAVA em "Loading driver ... I2C.efi"
```

## Fase atual: bring-up DXE
Os drivers DXE são **binários pré-compilados do Khaje** (`Platform/EFI_Binaries/Drivers/sm6225/`).
Khaje≈Bengal mas não idêntico → binários que tocam HW podem travar. **I2C.efi trava** (entry no
QUP). Fix: comentado em `dxe.fdf.inc` + `Apriori.fdf.inc`. Estratégia até o Shell: desabilitar/
ajustar os que travam, um a um (próximos candidatos: SPMI, Pmic, Sdcc...).

## Pipeline de build/flash (reproduzível)
- Build: GitHub Actions `build-gta4l.yml` (branch `diag-paint`), `gh workflow run`. Assina AVB sozinho.
- Hybrid: `hybrid_build_*.py` (kernel do artefato + container de `iso-test/boot-iso.img`) → avbtool sign.
- Flash: **adb dd com root** (vbmeta É gravável no Lineage rooteado — não precisa Odin/download mode):
  `dd if=boot of=/dev/block/by-name/boot bs=1M` + `dd if=vbmeta of=/dev/block/by-name/vbmeta`.
  Pelo Lineage rodando OU pela recovery (`/tmp`). Recovery: Power+VolUp.
- **Restore garantido:** `e:\tmp\bengal-edk2-port\RESTORE-droidspaces\boot-CURRENT.img` +
  `vbmeta-CURRENT.img` (boot do Lineage+Droidspaces tunado). Recovery → adb dd → reboot.

## 🏆 RESULTADO FINAL DA SESSÃO: UEFI SHELL ALCANÇADO
Após o fix do mem pool, a UEFI travava em drivers DXE que são **binários pré-compilados do
Khaje** (`Platform/EFI_Binaries/Drivers/sm6225/`). Khaje≈Bengal mas binários que tocam HW travam.
Desabilitados (comentados em `dxe.fdf.inc` + `Apriori.fdf.inc`): **I2CDxe** (1º a travar), depois
o lote periférico **AdcDxe, UsbPwrCtrlDxe, QcomChargerDxe, ChargerExDxe, TsensDxe, DDRInfoDxe,
UsbfnDwc3Dxe, UsbConfigDxe, UsbMsdDxe, UsbDeviceDxe**. Mantidos e funcionando: SPMI, PmicDxe,
**SdccDxe (eMMC)**, UFSDxe, TLMMDxe, FontDxe, Reset, PIL, Clock, etc.
→ UEFI seguiu: SimpleFbDxe (GOP) → console → BDS → **boot menu** → **UEFI SHELL**. 🎉
**Primeira UEFI edk2 completa num SM6115 Bengal do mundo.**

## ✅ CONSOLIDAÇÃO (port self-contained)
O DTB genuíno (4.46MB, com `qcom,board-id` que o ABL precisa) foi **integrado ao build**:
`Platform/Samsung/sm6225/FdtBlob_compat/gta4l.dtb` substituído pelo genuíno + `--cmdline` no
`gta4l.sh.inc`. **Build verde → a CI agora cospe um boot.img bootável DIRETO** (dtb_size 4461825),
sem precisar do hybrid manual. PENDENTE: 1 flash de confirmação do artefato direto (não testado em
boot ainda — o hybrid é a garantia até lá; única diferença é ramdisk 1 byte vs 2.4MB, que não deve
importar pro ABL).

## 🪟 FASE 4 — Windows ARM (próxima sessão)
1. Reativar **USB host** (UsbBusDxe/UsbKbDxe + XHCI) p/ teclado + pendrive instalador; confirmar GOP + eMMC(Sdcc).
2. Do Shell, bootar **instalador WoA** (Win11 ARM64 UUP→WIM) por USB-OTG.
3. Particionar eMMC (preservar partições Qualcomm) + aplicar WIM + injetar driver pack
   (ACPI gta4l JÁ EXISTE em `Platform/Samsung/sm6225/AcpiTables/gta4l/` + drivers Qualcomm comuns).
4. Bootar Windows: display(FB) + storage(eMMC) + USB.
Caveat honesto: sem driver Win p/ Adreno610/Venus/câmera/áudio → alvo = "Windows utilizável".

## Arquivos-chave
- Repo: `e:\tmp\bengal-edk2-port\edk2-msm` (branch `diag-paint`) + github gabrielfavera07/edk2-msm.
- Ferramentas: `e:\tmp\bengal-edk2-port\` → `hybrid_build*.py`, `cmp_boot.py`, `iso-test/` (avbtool, testkey, relayout).
- Fixes no repo: `Platform/Qualcomm/sm6225/sm6225.dsc` (mem pool), `dxe.fdf.inc`+`Apriori.fdf.inc` (I2C off).

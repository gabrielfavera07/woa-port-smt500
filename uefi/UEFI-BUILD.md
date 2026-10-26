# Fase 2 — Build do UEFI (Mu-Silicium / gta4l)

> Descoberta-chave (2026-10-24): o port para ESTE tablet existe e é mantido —
> **`Platforms/Samsung/gta4lPkg`** no repositório **Project-Silicium/Mu-Silicium**
> (antes Robotix22/MU-Qcom; o fork `pornoname/MU-sm8450` de 2023 também tinha SM6115Pkg
> para o device "lime"). Contribuidor do gta4l: **V6lhost** (que também mantém
> `linux` mainline WIP e `gta4l-dts` — úteis para referência de hardware).

## Status oficial do gta4l (Status.md do Mu-Silicium, out/2026)

| Feature | Estado |
|---|---|
| Display | ✅ |
| Armazenamento interno | ✅ |
| Side buttons | ⚠️ só volume |
| USB Host | ✅ |
| USB Device | ❌ |
| USB PD | ✅ |
| **Mass Storage** | ❌ (reboota) |
| SD Card | ❌ |
| **Windows Boot** | ❌ |
| **Linux Boot** | ❌ |
| State | Inactive |

⚠️ Aviso oficial: **"`BIT-8` Version is Required on this Device!"** (também no Galaxy S23+).
"BIT-8" não aparece em código/config do repo — hipótese forte: requisito do header
**Samsung da boot image** validado pelo ABL. Resolver empiricamente no flash:
comparar o header (primeiros KB) do boot.img do Lineage (aceito pelo ABL deste
aparelho) com o `Mu-gta4l.img` gerado e replicar os campos Samsung se preciso.
A tentativa de jun/2026 na ESP ("Bengal WoA") era quase certamente um build deste
projeto em debug (há `BCD.pre-serial` — debugging serial).

## Pré-requisito Samsung descoberto (dos guias oficiais)
Samsung marca o armazenamento como **"Offline"** no modo Mass Storage, o que QUEBRA
boot de Windows/Linux. Guia oficial de correção ("Modifying your UFS"):
`Guides/Vendors/Samsung/Modding-UFS` no repo Project-Silicium/Guides:
Disk Management → Online → gdisk recovery (`r` → `c` → `w`) → guia "Fixing UFS LUNs".
**No nosso caso o MSC reboota (❌ acima) — o caminho alternativo é WinPE/instalação
por partição (Dism++/apply por recovery), ou consertar o MSC no código.**

## Build (WSL2 Ubuntu — já preparado neste PC)

```bash
# toolchain já instalado: gcc-aarch64-linux-gnu 13.3, dtc 1.7, python 3.12, pip, ccache
cd ~/Mu-Silicium
./setup_env.sh -p apt                 # deps restantes do projeto
python3 -m pip install -r pip-requirements.txt
python3 build_uefi.py -d gta4l -m 8    # -m 8 = sufixo BIT-8 no nome (Mu-gta4l-8.img)
# saída: Mu-gta4l-8.img (boot.img v1: kernel=BootShim+UEFI.FD gzip + dtb anexado)
```

Pipeline interno: UEFI.FD (base 0x5FC00000 — mesma região do XBL!) + **BootShim**
(cabecalho de kernel Linux que o ABL aceita) + DTB do device → mkbootimg v1.

## Depois do build
1. Validar o img: `tools/android_boot_parse.py uefi/Mu-gta4l-8.img`
2. Comparar header Samsung vs boot.img Lineage (BIT-8) — ajustar se necessário
3. Flash: `scripts/device/flash-uefi.sh` (backup automático do boot Android)
4. **GATE FASE 2:** menu UEFI visível NA TELA do tablet; ESP visível no menu
5. Debug: builds `-r DEBUG` + serial UART (o BCD.pre-serial anterior indica que essa
   era a ferramenta de debug da tentativa passada)

## Arquitetura do repo Mu-Silicium (referência rápida)
```
Platforms/Samsung/gta4lPkg   # plataforma do nosso tablet (dsc/fdf/dec/DeviceBuild.py)
Resources/Configs/gta4l.toml # FD base 0x5FC00000 size 0x300000, bootimg v1, gzip, append_dtb
Resources/DTBs/gta4l.dtb|.dts# DTB usado pelo BootShim
Silicium-ACPI/               # tabelas ACPI por plataforma (inclui Samsung/gta4l)
BootShim/                    # shim "kernel Linux" que carrega o UEFI.FD
build_uefi.py                # orquestrador (stuart/edk2-toolext por baixo)
Common/Mu*, Mu_Basecore      # Project Mu + edk2 base (submódulos)
```

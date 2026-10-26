# Cadeia de Boot — Análise estrutural (firmware stock T500XXS8CXG3)

> Evidências: `device/firmware/*.elf|*.mbn` (extraídos do BL tar.md5 oficial), parses com
> `tools/elf_parse.py` / `tools/android_boot_parse.py` / `tools/efi_strings.py`, dumps ao vivo
> do TWRP (`device/dumps/`), e logs em `logfs`. Análise com REA MCP iniciada; provedores
> profundos (Ghidra/IDA) ausentes no host — registrado em "Limites".

## 1. Cadeia de inicialização do SM-T500 (plataforma Qualcomm bengal/SM6115)

```
ROM PBL (immutable)
  └─ XBL.elf  — ELF64 EXEC AArch64, entry 0x00c225908, 17 PH LOAD
                regiões: 0x0c11_9000–0x0c35_0000 (OCIMEM/SBL), 0x45e0_0000+ (RPM-ish), 0x5fc0_0000 (eMMC boot?)
                carrega e autentica o ABL (assinaturas Samsung/Qualcomm obrigatórias)
  └─ xbl_config.elf — ELF pequeno (43 KB), config do chainloader
  └─ ABL.elf — ELF32 EXEC ARM, entry 0x9fa0_0000 (endereço de load clássico do ABL)
       identidade: "T500XXS8CXG3", "SM-T500_EUR_XX_QKEY4", certificados "Samsung Root CA" /
       "Samsung Attestation CA" embutidos (Samsung KNOX attestation).
       Funções (evidência em logfs + particionamento):
         • carrega boot.img (slot 'boot', mmcblk0p69, 96 MB) — formato Android boot v2
           (kernel+ramdisk+dtb; confirmado nos parses de boot.img stock e LineageOS)
         • injeta androidboot.* no cmdline (capturado ao vivo)
         • gravou/restaurou partições de bootloader em sessões de download
           (logfs: "FlashBootPartition : xbl/abl/tz/hyp/rpm/... partition restore success")
         • UEFI variables → partição dedicada 'uefivarstore' + 'uefisecapp' (QSEE)
  └─ TrustZone: tz.mbn (4 MB, EL3), hyp.mbn (1 MB), rpm.mbn, devcfg, qupfw — todos assinados
```

## 2. Consequências para o port Windows

1. **XBL/ABL são inalteráveis** (assinados, verificação em ROM). O ponto de entrada explorável
   é o **slot `boot`**: com bootloader destravado (`verifiedbootstate=orange`, `warranty_bit=1`),
   o ABL carrega qualquer boot.img v2 — como já prova o LineageOS boot atual.
2. **Não existe fastboot neste aparelho** (cadeia Samsung). Métodos de flash:
   Odin (Windows) / Heimdall (cross) para o slot `boot`, ou `dd` direto via TWRP.
3. **Modelo do payload UEFI** (idêntico ao Renegade/edk2-msm): pacote o firmware edk2-bengal
   como boot.img v2 — "kernel" = binário UEFI; ABL carrega e salta para EL1. Evidência de que
   esse modelo já rodou aqui: `startup.nsh` "Bengal WoA" na ESP (executado pelo shell do edk2
   BDS) e bootmgfw.efi 22621-era já instalado.
4. **SecureBoot**: chainload Samsung verifica só até o ABL; o UEFI edk2 não implementa
   SecureBoot MS → Windows roda com `testsigning on` (BCD) + bypass de requisitos no setup
   (LabConfig) — prática padrão dos ports.
5. Boot em **EL1** (sem EL2) → sem Hyper-V/WSL2/WHPX dentro do Windows portado.

## 3. Evidências por artefato

| Artefato | Fatos | Ferramenta |
|---|---|---|
| `device/firmware/xbl.elf` | ELF64 EXEC AArch64, entry 0xc225908, PHs em 0x0c11_9000/0x45e0_0000/0x5fc0_0000 | elf_parse.py |
| `device/firmware/abl.elf` | ELF32 EXEC ARM, entry 0x9fa00000; strings: T500XXS8CXG3, SM-T500_EUR_XX_QKEY4, Samsung Root/Attestation CA | elf_parse.py + efi_strings.py |
| `device/firmware/boot.img` (stock) | Android boot v2: kernel 15.782.068 B @0x8000, ramdisk 803.687 B, dtb 2 B, page 4096, nome SRPTD23A008 | android_boot_parse.py |
| `CUSTOM_ROM_lineage/boot.img` | boot v2: kernel 18.040.415 B, ramdisk 1.492.837 B, nome SRPTC24A006 | android_boot_parse.py |
| `device/dumps/logfs.bin` | log UEFI/ABL "FlashBootPartition: xbl/xbl_config/rpm/tz/hyp/abl/devcfg/cmnlib/keymaster/apdp/vbmeta/uefisecapp/secdata ... restore success" | efi_strings.py |
| `device/dumps/esp/startup.nsh` | script de shell edk2: lança `\EFI\Microsoft\Boot\bootmgfw.efi` procurando fs0..fs25 | cat |
| `device/dumps/esp/BCD` | aponta `\Windows\system32\winload.efi`, descrição "Windows 11" | efi_strings.py |
| `device/dumps/esp/bootaa64.efi.bak29563` | bootmgr MS assinado (bootmgfw.pdb, certs MicCorKEKCA2011, Production PCA 2011) — original do meio de instalação | efi_strings.py |
| cmdline ao vivo | `androidboot.dtbo_idx=5`, painel `hx83102e_hlt_auo_video`, `secureboot=1`, `warranty_bit=1`, `verifiedbootstate=orange` | TWRP |

## 4. Limites desta análise (honestidade)

- REA MCP abriu o alvo (SHA-256 `09e14c6d…7560e6`) mas **Ghidra/IDA não estão instalados no
  host** → sem decompilação/pseudocódigo do ABL/XBL nesta rodada. Para aprofundar (ex.: achar
  o handler de boot.img do ABL, rotinas de rollback/Knox), instalar Ghidra 12.1.x e definir
  `GHIDRA_INSTALL_DIR`; o REA retoma de onde parou.
- `win` (NTFS) e o conteúdo do `super` não foram inspecionados pelo TWRP (sem ntfs-3g / super
  precisa lpunpack). Rota futura: boot do UEFI em modo Mass Storage → leitura pelo PC.
- O payload UEFI "Bengal WoA" usado em jun/2026 **não foi localizado** no dispositivo — obter
  upstream (edk2-msm/forks bengal) ou rebuildar; ver docs de research.

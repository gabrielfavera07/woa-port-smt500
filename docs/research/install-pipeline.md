# Research — Pipeline de instalação WoA (Renegade/edk2-porting, 2022–2026)

> Consolidado de pesquisa web com fontes (subagente, out/2026). Adaptado ao SM-T500 onde difere.

## Duas gerações de método
- **Clássica (SDM845, arquivada):** partições via `parted` no TWRP (ESP FAT32 + `pe` FAT32 +
  `win` NTFS), boot de WinPE pelo menu do UEFI, aplicação por **Dism++** GUI (grava boot files).
- **Atual (nabu/Pad 5, SM8150+):** UEFI em modo **USB Mass Storage (MSC)** → eMMC/UFS vira disco
  no PC → `dism /Apply-Image` + `bcdboot` + drivers offline pelo PC. É o método que adotamos.

## Particionamento (referência; no SM-T500 JÁ ESTÁ FEITO)
```
umount userdata; sgdisk --resize-table 64 /dev/block/sda; parted /dev/block/sda
  rm <userdata#>; mkpart userdata ext4 <ini> <fim>; mkpart esp fat32 ...; mkpart win ntfs ...
  set <esp#> esp on; quit
mkfs.fat -F32 -s1 ...; mkfs.ntfs -f ...; fixgpt   # fixgpt OBRIGATÓRIO (risco de brick)
```
- **Observação real:** os guides community **não criam partição MSR**; a que existe no seu
  tablet (16 MB) veio de layout estilo x86 — inócua, mantida.
- ESP típica: 0,3–1 GB (a sua: 600 MB, ok). Backup das partições de modem (fsc/fsg/modemst1/2)
  antes de mexer é regra nos guides de devices com cellular — **já feito aqui** (Fase 0).

## Flash/boot do UEFI
- Xiaomi: `fastboot boot uefi.img` (temporário) ou `fastboot flash boot` (persistente, com
  backup do boot Android para dual-boot).
- **SM-T500: sem fastboot** → equivalente é `dd` no slot boot via TWRP
  (`scripts/device/flash-uefi.sh`) ou Odin/Heimdall.
- Releases por SoC: github.com/edk2-porting/edk2-msm (assets `boot-<codename>.img`),
  edk2-sdm845, e repos por dispositivo (ex.: erdilS/Port-Windows-11-Xiaomi-Pad-5).

## Instalação (PC, modo MSC)
```
diskpart            # letras p/ ESP e WIN
dism /Apply-Image /ImageFile:install.wim|esd /Index:N /ApplyDir:W:\
bcdboot W:\Windows /s S: /f UEFI
dism /Image:W:\ /Add-Driver /Driver:<pasta> /Recurse     # packs WOA-Drivers
```
Pós-install no BCD da ESP:
```
bcdedit /store S:\EFI\Microsoft\Boot\BCD /set {default} testsigning on
bcdedit /store ... nointegritychecks on
del S:\EFI\Microsoft\Boot\SiPolicy.p7b    # senão NÃO BOOTA (caso nabu; checar aqui também)
```
Instaladores automatizados: **WoN Deployer** (nabu), WOA-Deployer (Lumia). "Windroid installer"
não existe como ferramenta desse ecossistema (nomes iguais são launchers/QEMU no Android).

## Dual-boot
1. **SimpleInit** (menu no próprio UEFI; config em `simpleinit.static.uefi.cfg` na partição
   `logfs` — este tablet TEM logfs 8 MB, compatível);
2. fastboot boot one-shot (não aplicável — Samsung);
3. Troca do slot boot por app/script — **nosso método** (WOA Helper no Android / script TWRP;
   regra: refazer o backup do boot Android após cada atualização de ROM).

## Aquisição de imagem ARM64
- **UUP Dump** (uupdump.net): build → ARM64 → edição → idioma → ISO com updates (recomendado
  pelos guides). MS também publica ISO ARM64 de Win11 em microsoft.com/software-download.
- **Nosso alvo: build 22621 ARM64** (teto do ARMv8.0 sem LSE — mesma regra que cortou o
  SDM835 no 23H2→24H2).

## Fontes principais
- [Renegade install (oficial)](https://renegade-project.tech/en/install) ·
  [Guide clássico](https://github.com/edk2-porting/renegade-project.org/blob/master/en/windows/Installation-guide.md) ·
  [edk2-msm](https://github.com/edk2-porting/edk2-msm) ·
  [WOA-Drivers](https://github.com/edk2-porting/WOA-Drivers) ·
  [multiboot/SimpleInit](https://github.com/edk2-porting/renegade-project.org/blob/master/en/multiboot.md) ·
  [nabu guides (erdilS)](https://github.com/erdilS/Port-Windows-11-Xiaomi-Pad-5) ·
  [UUP Dump](https://uupdump.net) ·
  [DISM](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism-image-management-command-line-options-s14) ·
  [TESTSIGNING](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/the-testsigning-boot-configuration-option)

# PROJETO: Windows ARM (UEFI/Renegade) no Galaxy Tab A7 SM-T500 — REGISTRO COMPLETO

> **"Lembre de tudo."** Este é o registro mestre da jornada inteira. Tudo que descobrimos,
> fizemos, onde paramos, e como retomar. Atualizado: 2026-06-12.

---

## 🎯 OBJETIVO
Rodar **Windows 11 ARM** no **Samsung Galaxy Tab A7 Wi-Fi (SM-T500)** via o **Renegade
Project / edk2-msm** (UEFI aberto para Snapdragon). Inspiração: o vídeo do Renegade no
Redmi Note 9 (transcrição em `transcricao_video.txt` nesta pasta).

**Device:** SM-T500 · codename `gta4l` · SoC **SM6115 "Bengal"** (Snapdragon 662) · Adreno 610 · 3GB RAM · tela 1200x2000.

---

## 📍 ONDE PARAMOS (estado atual)

**Conquistamos o IMPOSSÍVEL-no-papel, e batemos num muro de hardware:**
- ✅ Primeiro firmware UEFI do mundo pro Snapdragon **Bengal** — compila, e o bootloader Samsung **aceita** a imagem.
- ✅ Deciframos a cadeia de Verified Boot (AVB) inteira da Samsung.
- 🧱 **Muro:** depois de aplicar a solução AVB correta, o tablet fica no splash. Os diagnósticos visuais (paint/PSHOLD/USB) **não conseguem dizer** se o UEFI roda (mas trava invisível) ou não roda. **Precisamos de console SERIAL** pra ver — e isso precisa de um **jig UART de hardware**.

**Estado físico do tablet:** boot = nosso UEFI (não boota Android). vbmeta = nosso custom.
Recovery LineageOS intacto. **PENDENTE: restaurar o Android** (escolha do usuário quando quiser).

---

## 🗂️ ARQUIVOS E LOCALIZAÇÕES

**Repo GitHub (tudo público):** https://github.com/gabrielfavera07/edk2-msm/tree/gta4l
- Device package: `Platform/Samsung/sm6225/gta4l.{dsc,fdf.inc,sh.inc}` + `FdtBlob_compat/gta4l.dtb` + `Library/gta4l/PlatformMemoryMapLib/`
- Config: `configs/devices/gta4l.conf`
- CI: `.github/workflows/build-gta4l.yml` (tem toggle `--uart`)
- **Guia reproduzível (12 capítulos):** `Platform/Samsung/sm6225/PORTING-JOURNEY.md`

**Local `E:\tmp\bengal-edk2-port\`:**
- `edk2-msm/` — clone do repo (fork)
- `boot-gta4l-UART-ODIN.tar` — **build --uart PRONTO** (flashar no jig)
- `vbmeta-gta4l-ODIN.tar` — vbmeta custom (já flashado)
- `vbmeta-ORIGINAL-restore-ODIN.tar` — restaura vbmeta original (md5 2e1aa0df)
- `recovery.img` (103MB), `vbmeta.img`, `vbmeta_samsung.img`, `dtbo.img`, `device.avbpubkey`, `xbl.img`, `uefiplat-smt500.cfg`, `bengal-smt500.dtb` — dumps de referência
- `Thor-Windows.exe` — não funciona (sem USB no Windows)

**Ferramentas:** Odin3 v3.13 (instalado, driver Samsung ok). adb em `/c/platform-tools/`.

---

## 🔑 ACHADOS TÉCNICOS-CHAVE (pra reproduzir)

### 1. Khaje (SM6225) == Bengal (SM6115) — silício irmão
O edk2-msm tem o SoC `sm6225` (Khaje). Cruzei o memory map dele com `/proc/iomem` do
device: **idênticos** (GCC 0x01400000, USB2/EUD 0x01610000, GPU_CC 0x05990000, DISP_CC
0x05F00000, USB30 0x04E00000, TSENS 0x04410000...). Por isso o port virou "device
package fino" em vez de "SoC do zero". Devices-molde: `Xiaomi/sm6225/spes` e `fog`.

### 2. Empacotamento boot.img que o ABL Samsung aceita
O genérico (v1 + dtb anexado ao gzip) é REJEITADO pela Samsung. O correto (descoberto
comparando com a partição recovery):
- **header v2** + DTB em **seção dedicada** (`mkbootimg --dtb`)
- kernel = **gzip LIMPO** (sem dtb anexado — o anexo vira lixo pós-EOF que trava o inflate do ABL)
- geometria stock: kernel 0x8000, ramdisk 0x20000000, tags 0x1e00000, page 4096
- board name `SRPTC24A006`
- header ARM64 do BootShim com **image_size != 0** (0x800000), text_offset 0x80000, flags 0xa

### 3. A cadeia AVB (Verified Boot) da Samsung — o segundo muro
- O ABL Samsung **verifica o boot criptograficamente MESMO desbloqueado** (provado: mudar 16 bytes do kernel real da recovery → rejeitado).
- A chave de confiança é a **AOSP testkey_rsa4096** (pública!). Match exato sha1: `2597c218aae470a130f61162feaae70afd97f011` entre a pubkey do device e a testkey AOSP.
- vbmeta (p11) tem flag VERIFICATION_DISABLED (0x3) MAS a Samsung **não honra** isso pro boot/recovery.
- **vbmeta é write-protected** (eMMC) — só **download mode (Odin)** grava.
- **Solução (aplicada):** `avbtool add_hash_footer` no boot (testkey, rollback 1) + `avbtool make_vbmeta_image --include_descriptors_from_image boot --key testkey --flags 2` → flashar via Odin AP.

### 4. O muro do serial (onde estamos)
Mesmo com tudo acima, splash. Diagnósticos cegos inconclusivos. **EUD fusado de fábrica
(NDA).** Caminho serial: **UART via USB-C com resistor 619kΩ no pino CC** (Samsung roteia
ttyMSM0 0x4a90000 115200 pros pinos D+/D-). Montar "Samsung UART jig": breakout USB-C +
619kΩ CC↔GND + FTDI 3.3V em D+/D-/GND.

---

## 🚀 PRÓXIMOS PASSOS (quando retomar)

**1. Conseguir o jig UART 619kΩ** (hardware — ~R$30 DIY ou jig pronto).

**2. Ler o serial:**
- Flashar `boot-gta4l-UART-ODIN.tar` no Odin (AP)
- PuTTY/terminal serial 115200 8N1 no jig
- Reiniciar → ler o log do **ABL + PrePi ao vivo**
- Descobrir: o ABL lança nosso kernel? Onde o PrePi morre? → bring-up COM VISÃO

**3. Pesquisa paralela (sem hardware):**
- Comunidade Renegade (Discord/Telegram): "sm6225 UEFI boota? gotchas Samsung Bengal? UART no Tab A7?"
- Confirmar se o UEFI do spes/fog (mesmo SoC) realmente boota

**4. Quando o UEFI subir → Fase 4 (Windows):** seguir o `transcricao_video.txt` (particionar, aplicar ESD do Windows, drivers, EFI boot, dualboot M3K helper). Referência de stack completa: github.com/n00b69/woa-polaris (sdm845, SoC diferente, mas mostra a estrutura).

---

## 🔧 COMO RESTAURAR O ANDROID (quando quiser)
- **Opção A (stock):** baixar firmware SM-T500 no samfw.com (grátis, ~4GB), flashar BL+AP+CP+CSC no Odin. Restaura 100% de fábrica.
- **Opção B (Lineage):** flashar `vbmeta-ORIGINAL-restore-ODIN.tar` no Odin AP + baixar zip LineageOS do Tab A7 + `adb sideload` pelo recovery.

---

## 🧠 PENDÊNCIAS
- [ ] Restaurar Android do tablet (decisão do usuário)
- [ ] Conseguir jig UART 619kΩ → ler serial → Fase 3
- [ ] Revogar o GitHub PAT antigo (`ghp_...`) quando fechar o projeto (pedido de segurança do usuário)

---

## 📞 COMO RETOMAR ESTA SESSÃO
Diga ao Claude: **"vamos continuar o UEFI do Tab A7"** — a memória do projeto persiste
(`edk2-bengal-woa-port.md`). Todo o contexto, repo, arquivos e próximos passos estão aqui
e na memória. Nada se perdeu.

*Documentado por Claude (Opus 4.8) — a jornada completa, incluindo os 20+ boots e cada beco sem saída, está em PORTING-JOURNEY.md no GitHub.*

# Bíblia do Port: Renegade UEFI + Windows ARM no Samsung Galaxy Tab A7 (SM-T500 / SM6115 Bengal)

> **Objetivo:** instalar Renegade (edk2-msm) → **Windows ARM funcionando com drivers** no SM-T500.
> **Fonte dos dados:** extração direta do kernel vivo (LineageOS) via SSH — device-tree, cmdline,
> socinfo, reserved-memory. Artefatos brutos em `_woa-research/`.
> **Repo do port:** `e:/tmp/bengal-edk2-port/edk2-msm` (local) + `github.com/gabrielfavera07/edk2-msm` (branch `gta4l`).
> **Data da extração:** 2026-06-13. Kernel `4.19.325`, Android 13 (`BP4A.251205.006`).

---

## 0. Veredito honesto antes de tudo
"Windows ARM **100%**" no sentido literal (tudo funcionando) **não é alcançável** neste SoC, e a
razão é simples: **não existem drivers Windows para o Adreno 610, câmera, Venus, DSP, sensores e
áudio do Bengal.** Ninguém os escreveu — e escrever do zero é trabalho de equipe da Qualcomm.

O que **é** alcançável e seria inédito no mundo:
- **Windows ARM que BOOTA, INSTALA e RODA** com **display (framebuffer), armazenamento (eMMC),
  USB (teclado/mouse)** e ambiente desktop funcional.
- **WiFi (WCN3990)** como esticada provável (há driver WoA em SoCs irmãos).
- Tudo gráfico roda em **software/básico** (sem aceleração GPU — igual a qualquer WoA sem driver Adreno).

Então "100%" vira **"Windows ARM utilizável"**. Com isso claro, segue a planta completa.

---

## 1. Identidade do SoC e cadeia de boot (de socinfo + cmdline)

| Campo | Valor |
|---|---|
| machine | **BENGAL** | 
| soc_id | **444** (SM6115) |
| chip_name interno | SM_KAMORTA_H (família 0x6a) |
| nproduct_id | 0x41c |
| Modelo | SM-T500 (`gta4lwifixx`) |
| RAM | 3 GB (`dram_info=01,07,00,3G`) |
| **Storage** | **eMMC via SDHCI** — `androidboot.bootdevice=4744000.sdhci`, `fstab_suffix=emmc` |
| Bootloader | T500XXS8CXG3, `verifiedbootstate=orange` (destravado), `secureboot=1` |
| Painel | `mdss_dsi_hx83102e_hlt_auo_video` (Himax hx83102e, AUO, modo vídeo) |
| Console serial | `ttyMSM0,115200n8` / `earlycon=msm_geni_serial,0x4a90000` |
| RPMB fuse | `rpmbfuseblown=1` |
| PMIC | model 0x1002D, die 0x10001 |
| Firmware (XBL) | `BOOT.XF.4.1-00316-KAMORTALAZ-1`, TZ `TZ.XF.5.1-654142-4` |

**Cadeia:** PBL → **XBL** (BOOT.XF.4.1) → **QHEE (hipervisor, EL2)** → **ABL (aboot)** → HLOS (EL1).
A presença do `hyp_region` (§3) confirma o QHEE. **→ A UEFI é entregue em EL1, sob o hipervisor.**

---

## 2. 🔑 A causa raiz provável do boot travado (PrePi morre cedo)

O edk2-msm/PrePi genérico assume que recebe controle em **EL2** (faz setup de MMU/exception
vectors pra EL2). Mas no Bengal o **QHEE ocupa o EL2** e entrega a UEFI em **EL1**. Ao tentar
acessar registradores EL2 (ex: `VBAR_EL2`, `SCTLR_EL2`), a CPU toma uma exceção, e como os
vetores ainda não estão montados → **hang silencioso no splash**. Isso explica TODOS os sintomas
(sem tela, sem USB, sem reboot) sem precisar de bug em mais nada.

**Teste binário (estratégia validada)** — inserir no topo do BootShim/PrePi:
```asm
mrs x0, CurrentEL
lsr x0, x0, #2          // EL atual
cmp x0, #2
b.eq el2_ok             // se EL2: segue normal
// se EL1 (esperado aqui): dispara PSHOLD pra PROVAR que rodamos
ldr x1, =0x0440b000     // PSHOLD real (confirmado no DT + iomem)
mov w2, #0
str w2, [x1]            // write 0 -> reset
1: b 1b
el2_ok:
```
Se o tablet **reiniciar** → confirmamos: rodamos **e** estamos em EL1 (→ corrigir PrePi pra
suportar entrada EL1, como fazem os ports de devices com QHEE). Se **congelar** → nem rodamos
(problema de formato/handoff do ABL). **Esse teste quebra o ovo-e-galinha sem hardware.**

---

## 3. Mapa de memória (pra PlatformMemoryMapLib da UEFI)

**RAM física (3 bancos, base 0x40000000):**
| Base | Tamanho | |
|---|---|---|
| `0x40000000` | 0x3e580000 | ~997 MB |
| `0x80000000` | 0x20000000 | 512 MB |
| `0xa0000000` | 0x60000000 | 1536 MB |

**Regiões reservadas que a UEFI PRECISA respeitar (carve-out):**
| Região | Endereço | Tamanho | Nota WoA |
|---|---|---|---|
| **hyp_region** | `0x45700000` | 6 MB | **QHEE (hipervisor EL2)** — NÃO tocar |
| xbl_aop_region | `0x45e00000` | 1.25 MB | XBL/AOP |
| smem_region | `0x46000000` | 2 MB | shared memory |
| modem_region | `0x4ab00000` | 105 MB | MPSS (modem fw) |
| pil_video/adsp/cdsp | 0x51400000+ | — | PIL subsistemas |
| **cont_splash_region** | **`0x5c000000`** | **15 MB** | **FRAMEBUFFER (GOP/Windows BootFB)** |
| dfps_data_region | `0x5cf00000` | 1 MB | |
| removed_region | `0x60000000` | 57 MB | secure |
| qseecom | `0x61800000` | — | TZ app |
| **sec_debug_region** | `0x71400000` | 8 MB | RAMdump Samsung |
| ramoops | `0x71300000` | 1 MB | pstore |
| ss_plog | `0x71100000` | 2 MB | Samsung plog |
| sec_log | `0x71600000` | 2 MB | log (do cmdline) |

> O framebuffer em `0x5c000000` (15MB, 1200×2000×4 ≈ 9.6MB cabe) é a chave do display no Windows:
> a UEFI expõe um **GOP** apontando pra cá, e o Windows usa o driver **BasicDisplay/BootVid** — sem
> precisar de driver DSI real. É assim que todo WoA sem GPU mostra imagem.

---

## 4. 🗺️ Mapa COMPLETO de periféricos → ACPI + driver Windows

Legenda de **disponibilidade de driver Windows**:
✅ existe/reusável (de SoC irmão WoA: SDM660/670/SM6125/sm6225) · 🟡 talvez portável · ❌ inexistente.

### 4.1 Núcleo da plataforma (BOOT-CRÍTICO — sem isto o Windows nem sobe)
| Função | Compatible | Endereço | ACPI | Driver Win |
|---|---|---|---|---|
| Interrupt ctrl | `arm,gic-v3` | `0x0f200000` | **MADT** | ✅ nativo |
| Timer arquitet. | `arm,armv8-timer` + `timer@f120000` | mem `0x0f120000` | **GTDT** | ✅ nativo |
| Clocks (GCC) | `qcom,bengal-gcc` | `0x01400000` | DSDT _CRS | ✅ qcom clock (port) |
| GPIO/pinmux (TLMM) | `qcom,bengal-pinctrl` | `0x00400000` | DSDT (GPIO) | ✅ qcgpio (port) |
| PMIC arbiter | `qcom,spmi-pmic-arb` | `0x01c40000` | DSDT | ✅ qcspmi (port) |
| Power engine | (rpm) `qcom,rpmcc-bengal` / `qcom,rpm-smd` | `0x045f0000` | DSDT (PEP) | 🟡 qcpep (adaptar) |
| APCS/CPU clk | `qcom,bengal-apcs-hmss-global` | `0x0f111000` | — | 🟡 |
| cpufreq | `qcom,cpufreq-hw` | `0x0f521000` | _CPC | 🟡 |
| Watchdog | `qcom,msm-watchdog` | `0x0f017000` | WDRT | ✅ |
| SMMU (apps) | `qcom,qsmmu-v500` | `0x0c600000` | IORT | 🟡 |
| PSHOLD (reset) | `qcom,pshold` | **`0x0440b000`** | DSDT (reset) | ✅ |

### 4.2 I/O essencial pra INSTALAR e usar
| Função | Compatible | Endereço | Driver Win |
|---|---|---|---|
| **eMMC (storage)** | `qcom,sdhci-msm-v5` (+CQE) | **`0x04744000`** | ✅ **sdhci/UFS WoA** ← make-or-break |
| SD card slot | `qcom,sdhci-msm-v5` | `0x04784000` | ✅ |
| UFS (não usado) | `qcom,ufshc` | `0x04804000` | (T500 usa eMMC) |
| **USB3 (dwc3)** | `qcom,dwc-usb3-msm` | **`0x04e00000`** | ✅ dwc3 WoA + HID |
| USB HS PHY | `qcom,qusb2phy` | `0x01613000` | ✅ |
| USB SS PHY | `qcom,usb-ssphy-qmp` | `0x01615000` | ✅ |
| **EUD (debug serial USB)** | `qcom,msm-eud` (status=ok) | `0x01610000` (+check `0x03e50018`) | — (debug) |
| UART console | `qcom,msm-geni-console` | `0x04a90000` | ✅ serial |
| UART HS | `qcom,msm-geni-serial-hs` | `0x04a8c000` | ✅ |
| QUPv3 wrapper | `qcom,qupv3-geni-se` | `0x04ac0000` | ✅ qcser/qci2c/qcspi |
| I2C (touch/codec) | `qcom,i2c-geni` | `0x04a84000`, `0x04a88000` | 🟡 |
| SPI (touch) | `qcom,spi-geni` | `0x04a80000` | 🟡 |

### 4.3 Display / GPU / Vídeo
| Função | Compatible | Endereço | Driver Win |
|---|---|---|---|
| Framebuffer (cont_splash) | — | `0x5c000000` | ✅ **GOP→BasicDisplay** |
| MDSS/SDE | `qcom,sde-kms` | `0x05e00000` | ❌ (sem driver display real) |
| DSI ctrl | `qcom,dsi-ctrl-hw-v2.4` | `0x05e94000` | ❌ |
| DSI PHY 14nm | `qcom,dsi-phy-v2.0` | `0x05e94400` | ❌ |
| dispcc | `qcom,bengal-dispcc` | `0x05f00000` | ❌ |
| **GPU Adreno 610** | `qcom,kgsl-3d0` | `0x05900000` | ❌ **sem driver WoA — só software** |
| gpucc | `qcom,bengal-gpucc` | `0x05990000` | ❌ |
| Video (Venus) | `qcom,msm-vidc` `bengal-vidc` | `0x05a00000` | ❌ |

### 4.4 Conectividade / Áudio / Sensores (pós-instalação, maioria ❌)
| Função | Compatible | Endereço/Bus | Driver Win |
|---|---|---|---|
| WiFi/BT | `qcom,icnss` + `qca,wcn3990` | `0x0c800000` | 🟡 **WCN3990 (esticada)** |
| NFC | `qcom,nq-nci` (NXP) | i2c@4a84000 @0x28 | ❌ |
| Touch (opções) | `synaptics,tcm-i2c` (i2c@4a88000@0x20) / `himax,hxcommon`,`novatek`,`focaltech` (spi@4a80000) | — | ❌ (usar mouse USB) |
| Áudio codec | `qcom,wsa881x` + `foursemi,fs18xx` (amp) | i2c@4a84000 | ❌ |
| USB-C audio switch | `qcom,fsa4480-i2c` | i2c@4a84000 @0x42 | ❌ |
| Fuel gauge | `cellwise,cw2017` | i2c@4a88000 @0x63 | ❌ |
| Fingerprint | `fpc,fpc1020` | — | ❌ |
| Câmera (TFE/CCI/CSI) | `qcom,tfe530`,`qcom,cci` | 0x05c1b000+ | ❌ |
| Crypto/RNG | `qcom,qcedev`,`qcom,msm-rng` | `0x01b20000`,`0x01b53000` | 🟡 |
| Modem | (MPSS presente, mas **T500 é Wi-Fi only**) | `0x06080000` | n/a |

---

## 5. As DUAS muralhas (em ordem de ataque)

### Muralha A — BOOT (observabilidade) → §2
A UEFI não chega à Shell. **Causa #1 suspeita: handoff em EL1 (QHEE).** Plano:
1. Build de diagnóstico com o teste `CurrentEL` + PSHOLD `0x0440b000` (prova execução + EL).
2. Se EL1 confirmado: portar PrePi pra **entrar em EL1** (referência: ports de devices Qualcomm com QHEE — a maioria dos Snapdragon recentes). Setup de `VBAR_EL1`/`SCTLR_EL1` em vez de EL2.
3. Plano B de observabilidade (se #1 não bastar): **RAMdump por EDL** com marcador de progresso
   gravado em RAM (ex: em `0x5c000000`, o cont_splash, que persiste), ou **acordar o EUD**
   (`status=ok` no DT → serial pela USB-C, zero-bancada).

### Muralha B — DRIVERS (pós-boot)
Ordem de prioridade pra um Windows **utilizável**:
1. **ACPI mínimo**: MADT (GIC `0x0f200000`) + GTDT (timer) + DSDT com GCC/TLMM/SPMI/PSHOLD.
2. **GOP framebuffer** `0x5c000000` → display no Windows (BasicDisplay).
3. **Storage eMMC** `0x04744000` (driver sdhci WoA) → instalar Windows.
4. **USB** `0x04e00000` + phys → teclado/mouse na instalação.
5. **Clocks/GPIO/PMIC/PEP** (pacote Qualcomm WoA comum) → estabilidade.
6. Esticadas: **WiFi WCN3990**, depois o resto (quase tudo ❌).

**De onde vêm os drivers:** o pacote comum Qualcomm WoA (qcpep, qcgpio, qcspmi, qcserial, dwc3,
storage) é **compartilhado entre gerações** — pegamos dos ports SDM660/SM6125/`sm6225`(fog/spes)
e ajustamos os endereços/ACPI pro Bengal. O que é **específico do Bengal e não existe**
(Adreno 610, Venus, câmera, áudio) fica de fora — daí o "utilizável", não "100%".

---

## 6. Plano de instalação (quando a UEFI bootar)
1. UEFI na partição `boot` (via Odin, cadeia AVB já dominada).
2. UEFI expõe USB + storage → bootar **WoA installer** (UUP→WIM Windows 11 ARM64) de um pendrive USB-OTG.
3. Particionar a eMMC (ESP + MSR + Windows) preservando partições Qualcomm (`xbl`,`tz`,`hyp`,`modem`,…).
4. Aplicar WIM + injetar **driver pack** (ACPI + qcom common) via `DISM /Add-Driver`.
5. Boot do Windows: display(FB) + storage + USB + teclado/mouse. WiFi se o WCN3990 colar.

---

## 7. Próximo passo concreto
**Atacar a Muralha A** com a build de diagnóstico EL1/PSHOLD (§2). É o único passo que destrava
todo o resto e não precisa comprar nada. Repo local pronto em `e:/tmp/bengal-edk2-port/edk2-msm`
(BootShim em `tools/BootShim/BootShim.S`).

---

## Apêndice — endereços de ouro (decorar)
```
RAM base ............ 0x40000000 (3 bancos, 3GB)
Framebuffer ......... 0x5c000000 (15MB) cont_splash
hyp (QHEE/EL2) ...... 0x45700000  <- causa do EL1 handoff
PSHOLD (reset) ...... 0x0440b000
IMEM ................ 0x0c125000 (diag_dload@c8, restart_reason@65c, upload_cause@66c)
EUD (serial USB) .... 0x01610000 (check 0x03e50018) status=ok
UART console ........ 0x04a90000 (GENI)
eMMC (SDHCI) ........ 0x04744000  <- storage do Windows
USB3 (dwc3) ......... 0x04e00000  (phy 0x01613000 / 0x01615000)
GIC v3 .............. 0x0f200000  -> MADT
GCC (clocks) ........ 0x01400000
TLMM (GPIO) ......... 0x00400000
SPMI (PMIC) ......... 0x01c40000
GPU Adreno610 (KGSL)  0x05900000  (sem driver Win)
DSI hx83102e ........ 0x05e94000  (sem driver Win; usar FB)
WiFi/BT WCN3990 ..... 0x0c800000 (icnss)
```

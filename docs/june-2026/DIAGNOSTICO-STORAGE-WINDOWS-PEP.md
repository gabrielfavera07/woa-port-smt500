# DIAGNÓSTICO DEFINITIVO — por que o Windows trava nas bolinhas (storage)

> Data: 2026-06-13. Marco: **causa-raiz encontrada com prova**. Não é "falta driver" — é **falta PEP**.

## O que acontece
Windows ARM64 boota: UEFI → bootmgr → winload (lê kernel via Block I/O da UEFI/SdccDxe, OK) →
kernel carrega (bolinhas girando) → **trava ~40min**. Não é BSOD imediato → o storage ACPI
carregou, mas a **I/O da eMMC nunca completa**.

## Causa-raiz (provada por 2 fontes)
O storage Qualcomm no Windows tem **TRÊS camadas**, e nós só temos a primeira:

1. ✅ **I/O SDHCI padrão** — `sdport.sys` inbox dirige os registradores SDHCI std. (o controlador
   `qcom,sdhci-msm-v5` é quase-padrão nessa parte).
2. ❌ **QCPEP (Power Engine Plugin)** — driver Qualcomm que **liga as rails do PMIC** (LDO/SMPS),
   **vota os clocks do GCC** (gcc_sdcc1_apps/ahb_clk) e faz o **handshake PWRCTL**
   (`CORE_PWRCTL`: o controlador pede via IRQ pra alguém ligar energia/voltagem do cartão e
   ESPERA o ack — sem ack, **trava**). **Bengal não tem PEP → é o nosso buraco.**
3. ⚠️ **Descrição ACPI correta** — HID Qualcomm + tabelas `_DSD` de power/clock, não o `PNP0D40`
   genérico que usei.

### Prova 1 — `sdhci-msm.c` (Linux, drivers/mmc/host/sdhci-msm.c)
`CORE_PWRCTL_*` / `CORE_PWRCTL_BUS_ON` / `CORE_PWRCTL_IO_HIGH`: o HW levanta uma IRQ de power
(**pwr_irq**, no Bengal = GIC SPI 352) pedindo ao driver pra comutar a rail e dar ack em
`CORE_PWRCTL_CTL`. O sdport inbox **não conhece pwr_irq** nem CORE_PWRCTL → o controlador
fica esperando o ack pra sempre → hang.

### Prova 2 — DSDT da Lumia 950 (WOA-Project/Lumia950XLPkg, AcpiTables/8994)
```asl
Device (SDC1) {
    Name (_HID, "QCOM24BF")            // HID Qualcomm — NÃO é PNP0D40
    Name (_CID, "ACPIQCOM24BF")
    ... _CRS: Memory32Fixed(0xF9824900) + 1 Interrupt(0x9B) ...
    Device (EMMC) { _ADR = 0x08 }
}
```
E um `_DSD` enorme só pro power/clock, consumido pelo **QCpep8994.sys**:
`PMICVREGVOTE` (PPP_RESOURCE_ID_LDO20_A, SMPS4_A) + `CLOCK` (gcc_sdcc1_apps_clk/ahb_clk) +
`PSTATE`/`DSTATE`/`TLMMPORT`. **É o PEP que liga o storage; o sdport só faz o I/O depois.**

→ No MSM8994 NÃO há `.sys` de storage no pacote de drivers (é inbox), mas HÁ o **QCpep8994.sys**.
   O storage só funciona porque o PEP existe.

## O que está errado no nosso SSDT-sdhc.asl atual
- HID = `PNP0D40` (genérico) — deveria ser um HID Qualcomm (ou casar o que o PEP/driver espera).
- Declara só **1 interrupt** (a main, SPI 348). Falta a **pwr_irq (SPI 352)**.
- **Não tem `_DSD` de power/clock** → nenhum PEP pra ligar rails/clocks.

## Caminhos pra resolver (ambos = projeto de driver-dev)
- **B1 — Portar um PEP pro Bengal (QcPep):** o jeito "certo" Qualcomm. Precisa do mapa de rails
  do PMIC do Bengal (PM6125) + endereços dos clocks do GCC (sdcc1), escrito como PEP dirigido por
  ACPI `_DSD`. Substancial.
- **B2 — Miniport sdhci-msm sdport auto-contido:** um miniport que ele mesmo (a) mantém o clock
  do GCC ligado (a UEFI/SdccDxe já liga — só não derrubar), (b) **dá ack no PWRCTL** tratando a
  pwr_irq (SPI 352) — como as rails da eMMC são fixas-ligadas, o ack é trivial (lê status, escreve
  "success"), (c) força modo baixo (HS/DDR52) pra **não precisar de DLL/tuning**. Lógica limitada,
  baseável no sample WDK `Windows-driver-samples/sd/miniport/sdhc`. **Menor que portar PEP.**

### Ambos precisam do ambiente:
- Liberar espaço (E:\Windows velho ~31GB) — elevado.
- **EWDK** (Enterprise WDK, ISO standalone ~7GB, compilador+WDK sem instalar Visual Studio).
- Test-signing offline: BCD `testsigning on` + `nointegritychecks` + assinar o driver com cert
  de teste próprio (cenário unlocked, ok).
- Injetar: `DISM /Add-Driver` na p83 (ou rebuildar a VHD).
- Iterar: build → assina → injeta → flasha → boota → observa.

## Recomendação
**B2 (miniport auto-contido)** — escopo menor e mais determinístico que portar um PEP inteiro
(que exigiria o mapa completo de PMIC+GCC do Bengal). O miniport precisa só de 3 coisas bem
definidas (clock-on, ack PWRCTL com rail fixa, forçar modo baixo).

## Estado preservado
eMMC: disk GUID 98101b32-...; Windows na p83 (LBA 73039872, NTFS 18GB); ESP p81 (LBA 71778304,
BCD com disk-GUID corrigido). winimg.vhd + esp_patched.img em e:/tmp/woa-iso/. SSDT-sdhc.asl
(a corrigir) na firmware UEFI. Lineage restaurado e bootando.

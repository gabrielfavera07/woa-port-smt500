# Research — Drivers Windows ARM64 para o hardware do SM-T500

> Estado por subsistema, com nível de confiança. Itens "(a verificar)" dependem do pack
> community (a escolher junto com a fork UEFI da Fase 2).

## Fonte principal de drivers
[edk2-porting/WOA-Drivers](https://github.com/edk2-porting/WOA-Drivers) — drivers Qualcomm para
os ports (plataforma, bateria, USB, botões, áudio em parte). Injeção offline via
`dism /Image:X /Add-Driver /Recurse`. Referência de status do que um port maduro entrega:
[status OnePlus 6 (SDM845)](https://github.com/WoA-OnePlus-6-Series/WoA-on-OnePlus6-Series/blob/main/guide/status.md).

## Estado esperado por periférico (mapa do DEVICE-PROFILE)

| Subsistema | Hardware | Expectativa | Confiança |
|---|---|---|---|
| Display | Himax HX83102E/AUO via UEFI GOP | Funciona como **Microsoft Basic Display** (sem GPU) | alta |
| GPU | Adreno 610 | **Sem driver Windows** — render por CPU (risco nº 1 do projeto) | alta (sem solução community p/ a610 em 2026) |
| Touch | Synaptics TCM I2C @0x20 | HID-over-I2C via nó DSDT, ou driver community; **crítico para UX tablet** | média (a verificar no pack) |
| Bateria | CW2017 gauge + PMI632 charger | Driver CW2017 existe em packs community | média-alta |
| Botões | power/vol (PMIC PON) | Community driver padrão | alta |
| USB | DWC3 + FSA4480 | Community driver | média-alta |
| Áudio | WCD937x + Bolero (ADSP) | Driver community existe p/ WCD93xx em SDM845/SM8150; 937x **a verificar** | média |
| Wi-Fi/BT | WCN3990 | Sem driver ARM64 consumer; ports irmãos (SDM845/WCN399x) têm wifi parcial/**a verificar**; plano B = dongle USB com driver inbox ARM64 | baixa-média |
| NFC | NXP nq-nci | Driver NXP NCI (Proximity) existe em packs | média |
| Sensores | ADSP/SSC | Tipicamente sem suporte nos ports | baixa |
| Câmera | — | Sem suporte | — (fora de escopo) |
| Vibração | motor (PMIC) | Community | média |

## O papel do ACPI/DSDT (é aqui que o DTB vira ouro)
O Windows não lê Device Tree: o UEFI expõe um **DSDT** onde cada periférico vira um nó ACPI
(_HID I2C\*, GPIO IRQs, recursos). O dump real (`device/analysis/live-dtb.txt`) dá:
endereços/ônibus/interrupts de touch (I2C-1, 0x20, GPIO 0x11 flags 0x2008), gauge (0x63),
NFC (0x28), PMICs — insumo direto para escrever os .asl do port. Ciclo: editar DSDT na
fork UEFI → rebuild → flash → `devmgmt.msc` sem "!".
Ferramentas: iasl (ACPI) para compilar/decompilar; dtc se precisar reprocessar DTB.

## Ordem de ataque recomendada (Fase 5)
1. display (GOP) — vem de graça com UEFI bom
2. touch — sem ele o tablet não é usável como tablet
3. bateria/gerenciamento de energia (evitar shutdown sujo)
4. USB host (dongles)
5. áudio
6. Wi-Fi/BT (ou plano B dongle USB no item 4)

## Notas honestas
- Mesmo ports maduros (SDM845) têm GPU "no x64 acceleration" e lista de pendências — o
  mesmo padrão se aplicará aqui; o diferencial do tablet é o touch, que precisa ser impecável.
- Drivers kernel x86/x64 de terceiros NUNCA funcionam (emulação é user-mode) — qualquer
  periférico exigirá driver ARM64 nativo.

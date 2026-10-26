# Problema em aberto: primeiro boot edk2-msm/Renegade num SoC SM6115 "Bengal"

> **Status:** travado por falta de observabilidade (não por falta de tentativas).
> **Aparelho:** Samsung Galaxy Tab A7 Wi-Fi (SM-T500, codinome `gta4l`/`gta4lwifi`).
> **Objetivo final:** bootar UEFI (edk2-msm/Renegade) até a Shell → destravar Windows ARM e
> Linux UEFI mainline nativos no tablet. Seria o **primeiro boot público de edk2-msm num
> Bengal/SM6115**.
> **Documento companheiro:** `PEDIDO-AJUDA-COMUNIDADE.md` (versão curta, em inglês, pra postar).

---

## 1. Hardware (o que estamos atacando)

| Item | Valor |
|---|---|
| Modelo | Samsung Galaxy Tab A7 Wi-Fi **SM-T500** (`gta4l` / `gta4lwifi`) |
| SoC | **SM6115 "Bengal"** = Snapdragon 662 |
| CPU | 8× Kryo 260 (4× A73 + 4× A53), ARMv8-A |
| GPU | **Adreno 610 (A610)** — Turnip/Vulkan 1.3 funciona (provado no Droidspaces) |
| DSP | Hexagon 686 (parado, não usado) |
| RAM | 3 GB |
| Tela | 1200×2000, painel DSI **hx83102e** |
| Modem | **nenhum** (variante só Wi-Fi) |
| Partições | **A-only** (não A/B) |
| Bootloader | **destravado** (OEM unlock, orange state) |
| OS atual | LineageOS 23.2 + Magisk (restaurado e funcional) |
| EDL / Download | Acessível (dominamos Odin + EDL) |

**SoC irmão:** `sm6225` ("Khaje") é a mesma plataforma Bengal. Cruzamos `/proc/iomem` contra o
`PlatformMemoryMapLib` do pacote `sm6225` do edk2-msm: **bases de registradores idênticas**.
Por isso construímos em cima do pacote `sm6225` — é o parente mais próximo que existe.

---

## 2. A cadeia de boot — onde a UEFI se encaixa

```
┌─────┐   ┌───────────────┐   ┌──────────────────┐   ┌───────────────┐
│ PBL │ → │  XBL / ABL    │ → │   nossa boot.img │ → │  kernel / OS  │
│ ROM │   │ (Samsung,     │   │  (UEFI disfarçada│   │  (Lineage,    │
│     │   │  ASSINADO)    │   │   de kernel)     │   │   ou Windows) │
└─────┘   └───────────────┘   └──────────────────┘   └───────────────┘
```

O ABL da Samsung espera carregar um **kernel Linux ARM64**. Para enganá-lo, empacotamos a UEFI
com um **BootShim** — um cabeçalho ARM64 falso que finge ser kernel. O fluxo *pretendido*:

```
ABL  →  BootShim  →  PrePi  →  DXE  →  BDS  →  Shell UEFI / boot do Windows
                      ▲
                      └── PrimeirA coisa "de verdade" da UEFI:
                          monta memória, liga MMU, prepara o ambiente.
```

- **PrePi** é o early-init. Se ele não sobe, **nada** depois existe.
- **Display** e **USB** só inicializam lá no DXE/BDS — bem **depois** de onde travamos.

---

## 3. O que JÁ construímos e resolvemos ✅

### 3.1 Pacote de device `gta4l` (no SoC `sm6225`)
- Mapa de memória específico de 3 GB, derivado de `/sys/firmware/fdt` + `uefiplat.cfg` do XBL.
- Framebuffer PCD = **`0x5C000000`** (confirmado = `cont_splash` do kernel vivo).
- Pacote WoA completo: **DSDT / MADT / FADT / GTDT + ButtonsDxe**, adaptado do device `fog`.
- Repo + jornada de 12 capítulos:
  **github.com/gabrielfavera07/edk2-msm** (branch `gta4l`),
  `Platform/Samsung/sm6225/PORTING-JOURNEY.md`.

### 3.2 Empacotamento da boot.img (espelhado na recovery do próprio device, que **boota**)
- header **v2**, DTB na seção dtb do v2, **gzip único e limpo** (sem dtb anexado), page **4096**.
- Geometria: kernel `0x8000` / ramdisk `0x20000000` / tags `0x1e00000`, board `SRPTC24A006`.
- **BootShim** (cabeçalho ARM64): `text_offset 0x80000`, `image_size 0x800000`, `flags 0xa`.

### 3.3 A cadeia AVB (isto deu o maior trabalho — e foi VENCIDA)
- O ABL da Samsung **verifica o boot criptograficamente mesmo destravado** (mudamos 16 bytes da
  recovery genuína → **rejeitada**).
- A chave AVB do device é a **AOSP `testkey_rsa4096`**
  (sha1 `2597c218aae470a130f61162feaae70afd97f011` — **match exato**).
- A partição `vbmeta` tem flag `VERIFICATION_DISABLED`, mas a **Samsung NÃO a honra** pro boot.
- **Resolvido:** assinamos o footer do boot com a testkey + regeramos a partição `vbmeta` com o
  hash descriptor do nosso boot (assinado com testkey), gravado via **Odin** (`vbmeta` é
  write-protected em eMMC).

> 👉 Conclusão da §3: **o ABL aceita e carrega a nossa imagem.** A barreira de assinatura está
> totalmente derrubada. O problema **não** é mais AVB.

---

## 4. O SINTOMA exato

Depois de tudo na §3, ao bootar:

- ⛔ **Trava no splash da Samsung**, indefinidamente.
- ⛔ **Nada na tela** — nenhum texto, nenhum log de debug, mesmo em build DEBUG.
- ⛔ **Nenhum dispositivo USB novo** enumera no PC → **nunca chegou ao BDS** (onde o USB sobe).
- ⛔ **Não reinicia, não dá pânico visível** — só congela.

Ou seja: morre **em algum ponto entre o ABL entregar o controle e a primeira coisa capaz de
gerar saída visível**. Quase certamente cedo — dentro do **PrePi**, ou até antes, no BootShim.

---

## 5. O PROBLEMA CENTRAL: cegueira total 🌑

Debugar firmware exige **uma** janela de observação. Temos três candidatas e **as três estão
fechadas neste instante do boot**:

| Janela | Por que está fechada |
|---|---|
| **Tela** | A `FrameBufferSerialPortLib` escreve o log direto no framebuffer no endereço PCD `0x5C000000`. Se nesse instante do handoff o scanout do display **não estiver** nesse endereço, escrevemos num lugar que ninguém mostra → splash continua mudo. |
| **USB** | Só sobe no BDS, **depois** de onde travamos. Nunca chega lá. |
| **Serial (UART)** | É o caminho clássico de debug de firmware… e é exatamente o que **não está fisicamente acessível** neste aparelho (UART em `ttyMSM0 @ 0x4a90000`, mas sem pinos expostos confirmados). |

> **O muro é um ovo-e-galinha:** pra consertar o PrePi preciso ver onde ele falha; pra ver onde
> falha preciso de saída; a saída mais confiável (serial) é justamente a que não está ligada.
> **Firmware sem feedback é impossível de depurar por tentativa-e-erro** — e já testamos
> dezenas de variações (§7), todas com o **mesmo splash mudo**.

---

## 6. As duas hipóteses que NÃO conseguimos distinguir

Sem nenhum bit de saída, não dá pra saber em qual mundo estamos:

- **Hipótese A — nosso código nem executa.**
  O ABL carrega a imagem mas, por algum detalhe de formato/geometria, salta pro lugar errado e
  nada nosso roda. O splash congelado seria o **ABL parado**, não a UEFI.

- **Hipótese B — nosso código executa e morre na hora.**
  O PrePi roda, mas a Samsung entrega o controle num **estado que ele não espera**:
  - nível de exceção errado (**EL1** vs **EL2**),
  - **MMU já ligada** quando o PrePi assume desligada,
  - **cache sujo**,
  - **framebuffer noutro endereço** que não `0x5C000000`.

  Aí ele toma uma exceção na primeira instrução crítica e fica em **loop morto**.

**Teste decisivo que tentamos:** pôr no começo do BootShim um **reboot forçado via PSHOLD**.
Se o aparelho reiniciasse → provaria "código executa" (Hipótese B). **Não reiniciou** — mas é
**inconclusivo**, porque pode ser que (a) o código realmente não roda, OU (b) o endereço do
PSHOLD que usamos está errado e o reset não dispara. **Serial resolveria isso em segundos.**

**Agravante honesto:** a base `sm6225`/Khaje do edk2-msm é **ela mesma WIP** — **não há
boot-to-shell confirmado em NENHUM Bengal/SM6225 publicamente** (`fog` aparece só como
"Testing", `spes` idem). Logo, podemos estar brigando com **dois** problemas simultâneos:
**bugs do nosso port** *e* **buracos do upstream**.

---

## 7. O que JÁ foi descartado (tudo sem mudança — mesmo splash mudo)

- Mapa de memória **4 GB vs 3 GB**; **FD_BASE alto (`0xCE000000`) vs baixo (`0x58000000`)**.
- Build **DEBUG** (`FrameBufferSerialPortLib`, log on-screen) **vs RELEASE** — sem texto em nenhum.
- Geometria da boot.img; gzip limpo; BootShim `code0` = **branch vs adr**; padding do image size.
- AVB: **sem assinatura vs self-key vs footer testkey-signed**; partição `vbmeta` customizada.
- Adição do **FV completo de ACPI + ButtonsDxe** (espelhando o `fog`).
- **Pinturas de framebuffer + probes de reboot PSHOLD** no BootShim: nada visível.
- **Nenhum** dispositivo USB novo enumera (confirma que não alcança BDS/USB).

---

## 8. A SOLUÇÃO buscada: abrir QUALQUER janela de observação

Não procuramos "o patch mágico". Procuramos **um único bit de feedback** que transforme isto de
"chute no escuro" em engenharia normal. Três caminhos, em ordem de **viabilidade sem comprar nada**:

### 8.1 ⭐ RAMdump via EDL + marcador de progresso (MAIS FACTÍVEL)
Ideia: a UEFI escreve um **byte de progresso** num endereço fixo e conhecido da RAM a cada
etapa (`0x01` ao entrar no BootShim, `0x02` ao entrar no PrePi, `0x03` após montar a memória, …),
**trava de propósito**, e então lemos a DDR inteira pelo **modo EDL** (que já dominamos).
Comparando o último marcador presente, descobrimos **exatamente até onde** o boot chegou.
- ✅ **Não precisa de hardware nenhum** além do EDL.
- ✅ Resolve direto a ambiguidade A vs B da §6.
- ⚠️ Trabalhoso: exige escolher um endereço de RAM que sobreviva ao dump e validar o caminho EDL→dump (sahara/firehose ou o PIL ramdump).

### 8.2 EUD (Embedded USB Debugger)
Hardware **dentro do Snapdragon** que expõe um console serial **pela própria USB-C**, sem solda.
Se ligado, plugamos o cabo e lemos os logs do PrePi.
- ⚠️ Costuma vir com **fusível desabilitado** em varejo Samsung — precisa confirmar nos registradores se dá pra acordar.

### 8.3 UART via jig 619 kΩ
A USB-C pode ser **comutada pra modo UART** colocando uma resistência específica (≈619 kΩ) no
pino CC/ID. Os pinos de dados viram TX/RX e ligamos um adaptador USB-serial.
- ⚠️ Não sabemos o valor exato nem o pinout **deste** modelo; a UART pode estar roteada a um
  test-point interno em vez do conector.
- ⚠️ Requer jig + adaptador USB-serial (hardware).

---

## 9. Perguntas em aberto pra comunidade

1. Alguém já **bootou edk2-msm/Renegade num Bengal (SM6115/SM6225)** até a Shell? `sm6225`
   (`spes`/`fog`) **realmente** chega à shell, ou é WIP?
2. Em Snapdragon Samsung, há razão conhecida pra o **PrePi morrer antes de qualquer saída** da
   `FrameBufferSerialPortLib`? Algo do handoff do ABL (EL, MMU, estado do `cont_splash`) que
   quebra o PrePi genérico?
3. **Serial no SM-T500/Bengal:** o **EUD** é usável (parece fusível-off)? A **UART**
   (`ttyMSM0 @ 0x4a90000`) é alcançável via jig 619 kΩ na USB-C? Pinout confirmado?
4. Alguma **PCD/Library específica** que o pacote `sm6225` precisa, que `fog`/`spes` setam e
   estamos esquecendo?

---

## 10. Próximo passo recomendado

Atacar **§8.1 (RAMdump + marcador de progresso via EDL)** primeiro — é o único que **não exige
comprar nada** e responde diretamente "meu código executa?" (Hipótese A vs B). Plano:

1. Instrumentar BootShim/PrePi pra gravar um byte incremental num endereço de RAM reservado.
2. Forçar hang logo após cada marcador (build dedicada de diagnóstico).
3. Entrar em EDL, capturar o RAMdump, ler o endereço do marcador.
4. O último valor presente = a etapa mais distante alcançada → daí o debug vira dirigido.

> Quando **qualquer** janela abrir, o port deixa de ser adivinhação e vira trabalho de
> engenharia comum. Esse é o destravamento que procuramos.

---

## Apêndice — referências do projeto
- Repo + jornada: `github.com/gabrielfavera07/edk2-msm` (branch `gta4l`),
  `Platform/Samsung/sm6225/PORTING-JOURNEY.md` (12 capítulos).
- `PEDIDO-AJUDA-COMUNIDADE.md` — versão curta em inglês pra Discord/Telegram do Renegade ou XDA.
- `PROJETO-UEFI-TAB-A7-COMPLETO.md` — decifração completa do AVB/Odin/boot.img.
- edk2-msm/Renegade: pacotes `Silicon/Qualcomm/sm6225`, devices `fog`/`spes` (referência Bengal).

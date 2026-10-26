# Research — Execução de .exe no Windows on ARM (x86/x64/Prism)

> Consolidado de pesquisa web com fontes (subagente, out/2026). Impacto direto no objetivo
> "rodar qualquer .exe igual num PC".

## Resumo para o SM-T500 (regra prática)

| Tipo de binário | Roda? | Como | Observação |
|---|---|---|---|
| ARM64 nativo | ✅ nativo | — | apps modernos (Chrome, Office, VS Code, Zoom…) |
| x86 32-bit | ✅ | WOW64/emulação embutida (desde Win10 ARM) | nível Surface, só mais lento |
| x64 64-bit | ⚠️ | emulação x64 (Win11 2021+; **Prism exige 24H2 — NÃO temos**) | no 22621 usa o emulador antigo; sem aceleração de GPU no port |
| Drivers kernel x86/x64 | ❌ nunca | emulação é user-mode apenas | fato em todo WoA, inclusive Surface |
| Jogos com anti-cheat kernel | ❌/⚠️ | só com driver anti-cheat ARM64 | per-game |

- A ISO/versão alvo **22621** mantém x86 + x64 (emulador clássico, ~60–80% do nativo em
  cargas comuns; JIT pesado sofre mais).
- **Prism (24H2, +10–20%, AVX2 em dez/2025)** fica fora do alcance: exige ARMv8.1/LSE —
  o Kryo 260 não tem (fonte: corte do SDM835 no 24H2, regra oficial MS).
- Hyper-V/WSL2: indisponível (boot em EL1) — igual a todos os ports Renegade.
- Referências de apps: worksonwoa.com, windowsonarm.org, armrepo.ver.lt.

## Fatos-chave com fonte
- WOW64/redirecionamento igual ao x64: [MS Learn — emulação no Arm](https://learn.microsoft.com/en-us/windows/arm/apps-on-arm-x86-emulation)
- x64 desde Win11 out/2021 (Arm64X p/ DLLs do sistema): idem + [Windows Central](https://www.windowscentral.com/microsoft-states-x64-emulation-only-available-windows-11-arm-pcs)
- Prism no 24H2, tuning Snapdragon X, disponível a "todos os WoA suportados": [MS Learn](https://learn.microsoft.com/en-us/windows/arm/apps-on-arm-x86-emulation)
- **24H2 exige ARMv8.1 (fim do SD835)**: [OSNews](https://www.osnews.com/story/139585/first-generation-windows-on-arm-pcs-will-not-be-able-to-run-windows-11-24h2)
- Drivers kernel não emulados: [MS FAQ](https://support.microsoft.com/en-us/windows/experience/platform-variants/windows-arm-based-pcs-faq)
- Anti-cheat ARM64 (BattlEye/EAC/Denuvo 2024–25) per-game: [DirectX blog](https://devblogs.microsoft.com/directx/step-forward-for-gaming-on-arm-devices-2024), [Tom's Hardware](https://www.tomshardware.com/video-games/pc-gaming/epic-games-adds-easy-anti-cheat-for-arm-devices-feature-unlocks-support-for-windows-linux-and-switch-2)
- ARM32 UWP removido no 24H2 (irrelevante aqui): [Neowin](https://www.neowin.net/news/microsoft-removes-arm32-uwp-app-support-from-windows-11)
- Boot em EL1 sem hypervisor (ports): [Renegade docs](https://renegade-doc.readthedocs.io/en/latest/edk2/Overview.html)
- "No x64 acceleration" de GPU em port SDM845: [status OnePlus 6](https://github.com/WoA-OnePlus-6-Series/WoA-on-OnePlus6-Series/blob/main/guide/status.md)

## Expectativa realista de desempenho neste tablet
Kryo 260 (4x2.0 GHz A73-class + 4x1.8 GHz A53-class), 3 GB, eMMC:
- Apps ARM64: fluidos para tarefas leaves/médias (browser com abas moderadas, Office, PDF, vídeo 1080p por hw? — sem driver GPU, vídeo por CPU: 1080p ok, 4K não).
- x86 apps: utilizável com paciência; primeira execução mais lenta (JIT warm-up).
- x64 apps: executam, mas sem GPU accel no render — evitar IDEs/games pesados.
- Comparação honesta: **não** espere paridade com Surface; espere um "netbook ARM de 2018 com tela linda e 18h de bateria".

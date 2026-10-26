import shutil, os, sys

SRC = "sample-sdhc"
DST = "src"
if os.path.exists(DST):
    shutil.rmtree(DST)
shutil.copytree(SRC, DST)

def patch_file(path, edits):
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        t = f.read()
    for old, new, count in edits:
        n = t.count(old)
        if n != count:
            print("ERRO anchor (%d!=%d): %r em %s" % (n, count, old[:60], path))
            sys.exit(1)
        t = t.replace(old, new)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(t)

# ---------- sdhc.h : campo CoreBaseAddress na extensao ----------
patch_file(os.path.join(DST, "sdhc.h"), [
    ("    PSD_HOST_CONTROLLER_REGISTERS BaseAddressDebug;\n",
     "    PSD_HOST_CONTROLLER_REGISTERS BaseAddressDebug;\n\n"
     "    //\n    // Qualcomm SDCC vendor (CORE_*) register space: 0x1000 acima dos\n"
     "    // registradores padrao (DTB gta4l: hc_mem 0x4744000/0x1000 + core 0x4745000).\n"
     "    //\n\n    PVOID CoreBaseAddress;\n", 1),
])

# ---------- sdhc.c ----------
HELPERS = r'''
//-----------------------------------------------------------------------------
// Qualcomm SDHCI-MSM (SDCC5, compatible "qcom,sdhci-msm-v5") vendor support.
//
// O bloco CORE_* fica 0x1000 acima dos registradores SDHCI padrao; o ACPI
// publica uma unica regiao de 0x2000 no SDC1 (_CRS) cobrindo ambos. O
// handshake de energia (PWRCTL, GIC SPI 352) precisa de ack por software:
// sem ele o controlador nao conclui as sequencias de POWER_CONTROL e o
// kernel do Windows congela no boot (QCPEP wall).
//-----------------------------------------------------------------------------

#define MSM_CORE_REG_OFFSET         0x1000
#define MSM_CORE_HC_MODE            0x078
#define MSM_CORE_DLL_CONFIG         0x200
#define MSM_CORE_PWRCTL_STATUS      0x240
#define MSM_CORE_PWRCTL_MASK        0x244
#define MSM_CORE_PWRCTL_CLEAR       0x248
#define MSM_CORE_PWRCTL_CTL         0x24C

#define MSM_PWRCTL_BUS_OFF          (1 << 0)
#define MSM_PWRCTL_BUS_ON           (1 << 1)
#define MSM_PWRCTL_IO_LOW           (1 << 2)
#define MSM_PWRCTL_IO_HIGH          (1 << 3)
#define MSM_PWRCTL_INT_MASK         0x0000000F
#define MSM_PWRCTL_BUS_SUCCESS      (1 << 0)
#define MSM_PWRCTL_IO_SUCCESS       (1 << 2)

FORCEINLINE
ULONG
MsmReadCoreUlong(
    _In_ PSDHC_EXTENSION SdhcExtension,
    _In_ ULONG Offset
    )
{
    return READ_REGISTER_ULONG(
        (PULONG)((PUCHAR)SdhcExtension->CoreBaseAddress + Offset));
}

FORCEINLINE
VOID
MsmWriteCoreUlong(
    _In_ PSDHC_EXTENSION SdhcExtension,
    _In_ ULONG Offset,
    _In_ ULONG Value
    )
{
    WRITE_REGISTER_ULONG(
        (PULONG)((PUCHAR)SdhcExtension->CoreBaseAddress + Offset), Value);
}

//
// Executa a sequencia de ack do PWRCTL contra eventos pendentes.
// Retorna o conjunto de eventos reconhecidos (0 = nada pendente).
//

ULONG
MsmAcknowledgePwrctl(
    _In_ PSDHC_EXTENSION SdhcExtension
    )
{
    ULONG Status;
    ULONG Ack;
    ULONG Retry;

    Status = MsmReadCoreUlong(SdhcExtension, MSM_CORE_PWRCTL_STATUS) &
             MSM_PWRCTL_INT_MASK;

    if (Status == 0) {
        return 0;
    }

    //
    // Limpa os eventos (o primeiro pulso de clear pode se perder).
    //

    for (Retry = 0; Retry < 10; Retry++) {
        MsmWriteCoreUlong(SdhcExtension, MSM_CORE_PWRCTL_CLEAR, Status);
        if ((MsmReadCoreUlong(SdhcExtension, MSM_CORE_PWRCTL_STATUS) &
             MSM_PWRCTL_INT_MASK) == 0) {
            break;
        }
        KeStallExecutionProcessor(10);
    }

    //
    // Informa sucesso. Os rails ficam sempre ligados por plataforma
    // (UEFI nao os desliga), logo nao ha regulator para programar.
    //

    Ack = 0;
    if (Status & (MSM_PWRCTL_BUS_ON | MSM_PWRCTL_BUS_OFF)) {
        Ack |= MSM_PWRCTL_BUS_SUCCESS;
    }
    if (Status & (MSM_PWRCTL_IO_HIGH | MSM_PWRCTL_IO_LOW)) {
        Ack |= MSM_PWRCTL_IO_SUCCESS;
    }

    MsmWriteCoreUlong(SdhcExtension, MSM_CORE_PWRCTL_CTL, Ack);
    return Status;
}

//
// Sobe o bloco vendor: desmascara as fontes de pwr-irq e drena eventos
// antigos deixados pelo firmware.
//

VOID
MsmInitializeVendorBlock(
    _In_ PSDHC_EXTENSION SdhcExtension
    )
{
    MsmWriteCoreUlong(SdhcExtension, MSM_CORE_PWRCTL_MASK, MSM_PWRCTL_INT_MASK);
    MsmAcknowledgePwrctl(SdhcExtension);
}

//
// Espera (polling) o handshake PWRCTL concluir apos uma mudanca de energia
// feita via POWER_CONTROL padrao. Best-effort: em timeout segue adiante
// para nao travar o bring-up.
//

VOID
MsmCompletePwrctlHandshake(
    _In_ PSDHC_EXTENSION SdhcExtension
    )
{
    ULONG Retry;

    for (Retry = 0; Retry < 50; Retry++) {
        if (MsmAcknowledgePwrctl(SdhcExtension) != 0) {
            return;
        }
        SdPortWait(1000);
    }
}

'''

edits = []

# 1. Helpers antes da definicao de SdhcSlotInitialize
edits.append((
    "NTSTATUS\nSdhcSlotInitialize(\n",
    HELPERS + "NTSTATUS\nSdhcSlotInitialize(\n", 1))

# 2. Init: base do bloco vendor + bring-up do vendor block
edits.append((
    "    SdhcExtension->BaseAddressDebug = \n"
    "        (PSD_HOST_CONTROLLER_REGISTERS) VirtualBase;\n",
    "    SdhcExtension->BaseAddressDebug = \n"
    "        (PSD_HOST_CONTROLLER_REGISTERS) VirtualBase;\n\n"
    "    //\n    // Qualcomm: o bloco vendor CORE_* vive 0x1000 acima. A regiao\n"
    "    // mapeada precisa cobrir 0x2000 (hc + core).\n"
    "    //\n\n"
    "    SdhcExtension->CoreBaseAddress =\n"
    "        (PUCHAR)VirtualBase + MSM_CORE_REG_OFFSET;\n"
    "    MsmInitializeVendorBlock(SdhcExtension);\n", 1))

# 3. ISR: ack do pwrctl antes do caminho padrao
edits.append((
    "    SdhcExtension = (PSDHC_EXTENSION) PrivateExtension;\n"
    "    *Events = (ULONG) SdhcGetInterruptStatus(SdhcExtension);\n",
    "    SdhcExtension = (PSDHC_EXTENSION) PrivateExtension;\n\n"
    "    //\n    // Qualcomm: drena/ack o PWRCTL primeiro (pwr_irq pode ser a\n"
    "    // linha que disparou este ISR).\n    //\n\n"
    "    MsmAcknowledgePwrctl(SdhcExtension);\n"
    "    *Events = (ULONG) SdhcGetInterruptStatus(SdhcExtension);\n", 1))

# 4. SetVoltage: handshake apos POWER_CONTROL final
edits.append((
    "    Retries = 100;\n"
    "    Mask = SDHC_PC_VOLTAGE_MASK | SDHC_PC_BUS_POWER;\n",
    "    Retries = 100;\n"
    "    Mask = SDHC_PC_VOLTAGE_MASK | SDHC_PC_BUS_POWER;\n"
    "    MsmCompletePwrctlHandshake(SdhcExtension);\n", 1))

# 5. SetSignaling: handshake no final (troca 1.8V tambem gera pwr_irq)
edits.append((
    "    if (DatLines != SDHC_PS_DAT_3_0) {\n"
    "        return STATUS_UNSUCCESSFUL;\n"
    "    }\n\n"
    "    return STATUS_SUCCESS;\n}\n",
    "    if (DatLines != SDHC_PS_DAT_3_0) {\n"
    "        return STATUS_UNSUCCESSFUL;\n"
    "    }\n\n"
    "    MsmCompletePwrctlHandshake(SdhcExtension);\n"
    "    return STATUS_SUCCESS;\n}\n", 1))

patch_file(os.path.join(DST, "sdhc.c"), edits)

# ---------- sdhc.inx : nosso device ----------
INF = r'''; sdhc.inf - Miniport SDHCI Qualcomm (SDCC5/sdhci-msm-v5) p/ Galaxy Tab A7 SM-T500
; Port B2 do projeto woa-port-smt500. Base: sample WDK sd/miniport/sdhc.

[Version]
Signature="$Windows NT$"
Class=SDHost
ClassGUID={a0a588a4-c46f-4b37-b7ea-c82fe89870c6}
Provider=%ProviderString%
DriverVer=10/25/2026,1.0.0.0
CatalogFile=sdhc.cat
PnpLockdown=1

[DestinationDirs]
DefaultDestDir = 12

[SourceDisksNames]
1 = Disk

[SourceDisksFiles]
sdhc.sys = 1

[Manufacturer]
%Gta4l% = Gta4l,NTarm64.10.0

[Gta4l.NTarm64.10.0]
%SdhcMsm.DeviceDesc% = SDHCMSM_Install, ACPI\QCOM24BF
%SdhcMsm.DeviceDesc% = SDHCMSM_Install, ACPI\ACPIQCOM24BF

[SDHCMSM_Install]
CopyFiles = SDHCMSM_Files

[SDHCMSM_Files]
sdhc.sys

[SDHCMSM_Install.Services]
AddService = sdhcmsm, 0x00000002, SDHCMSM_Service_Install

[SDHCMSM_Service_Install]
DisplayName    = %SdhcMsm.SvcDesc%
ServiceType    = 1               ; SERVICE_KERNEL_DRIVER
StartType      = 0               ; SERVICE_BOOT_START
ErrorControl   = 1               ; SERVICE_ERROR_NORMAL
ServiceBinary  = %12%\sdhc.sys

[Strings]
ProviderString      = "woa-port-smt500"
Gta4l               = "Samsung Galaxy Tab A7 SM-T500 (gta4l)"
SdhcMsm.DeviceDesc  = "Qualcomm SDCC5 SD Host Controller (SDHCI-MSM)"
SdhcMsm.SvcDesc     = "Qualcomm SDCC5 SD Host Controller Miniport"
'''
with open(os.path.join(DST, "sdhc.inx"), "w", encoding="ascii", newline="\n") as f:
    f.write(INF)

print("PATCH-OK")

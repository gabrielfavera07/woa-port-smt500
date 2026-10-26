/** @file
  PwrCtlQuiesceDxe - quiesce do bloco PWRCTL do SDHCI-MSM (SDC1) no
  ExitBootServices.

  O BlockIo do UEFI usa o eMMC e pode deixar um evento pendente no bloco
  PWRCTL (CORE_PWRCTL_STATUS) com a linha pwr_irq (GIC SPI 352) asserted.
  O kernel do Windows, ao habilitar o GIC, recebe essa interrupcao level
  sem nenhum driver conectado ainda: re-assert em loop = interrupt storm
  e o boot congela nas bolinhas.

  Este modulo registra callback de ExitBootServices que mascarra os eventos
  de energia e drena qualquer pendencia, entregando o SoC ao kernel com a
  linha desassertada.

  Copyright (c) 2026 woa-port-smt500 (projeto B2).
**/

#include <Uefi.h>
#include <Library/BaseLib.h>
#include <Library/IoLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiDriverEntryPoint.h>

//
// SDHCI-MSM v5 (SDCC5) do gta4l/bengal: CORE_* sao offsets da base HC.
// hc_mem 0x04744000 (DTB gta4l), PWRCTL em +0x240..0x24C.
//

#define SDHC1_HC_BASE            0x04744000u

#define MSM_CORE_PWRCTL_STATUS   (SDHC1_HC_BASE + 0x240)
#define MSM_CORE_PWRCTL_MASK     (SDHC1_HC_BASE + 0x244)
#define MSM_CORE_PWRCTL_CLEAR    (SDHC1_HC_BASE + 0x248)
#define MSM_CORE_PWRCTL_CTL      (SDHC1_HC_BASE + 0x24C)

#define MSM_PWRCTL_INT_MASK      0x0000000Fu
#define MSM_PWRCTL_SUCCESS       0x00000005u   // BUS_SUCCESS | IO_SUCCESS

STATIC EFI_EVENT  mExitBootServicesEvent = NULL;

STATIC
VOID
EFIAPI
OnExitBootServices (
  IN EFI_EVENT  Event,
  IN VOID       *Context
  )
{
  UINT32  Status;
  UINTN   Retry;

  //
  // 1. Mascara todos os eventos de energia: nada novo assertion a linha.
  //

  MmioWrite32 (MSM_CORE_PWRCTL_MASK, 0);

  //
  // 2. Drena pendencias (clear + ack success), com retry como no
  //    sdhci_msm_handle_pwr_irq do Linux (o primeiro clear pode perder).
  //

  for (Retry = 0; Retry < 10; Retry++) {
    Status = MmioRead32 (MSM_CORE_PWRCTL_STATUS) & MSM_PWRCTL_INT_MASK;
    if (Status == 0) {
      break;
    }

    MmioWrite32 (MSM_CORE_PWRCTL_CLEAR, Status);
    MmioWrite32 (MSM_CORE_PWRCTL_CTL, MSM_PWRCTL_SUCCESS);
  }
}

EFI_STATUS
EFIAPI
PwrCtlQuiesceEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  return gBS->CreateEventEx (
                EVT_NOTIFY_SIGNAL,
                TPL_CALLBACK,
                OnExitBootServices,
                NULL,
                &gEfiEventExitBootServicesGuid,
                &mExitBootServicesEvent
                );
}

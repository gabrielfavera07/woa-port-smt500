@echo -off
echo Bengal WoA: launching Windows Boot Manager...
echo Trying current FS...
\EFI\Microsoft\Boot\bootmgfw.efi
echo Searching all FS...
for %x run (0 25)
  if exist fs%x:\EFI\Microsoft\Boot\bootmgfw.efi then
    echo Found on fs%x - launching
    fs%x:\EFI\Microsoft\Boot\bootmgfw.efi
  endif
endfor
echo Windows Boot Manager NOT found on any FS.

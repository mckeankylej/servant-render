{ compiler ? "ghc", test ? "true" }:
with (import ./../.. { inherit compiler test; });
let drv = overrides.common;
in
if reflex-platform.nixpkgs.lib.inNixShell then
  reflex-platform.workOn overrides drv
else
  drv
$! DIFFUTILS$STARTUP.COM - system startup for GNU diffutils on OpenVMS
$!
$! Installed by PCSI into SYS$STARTUP.  Defines the system logical name
$! DIFFUTILS$ROOT, pointing at the installed [DIFFUTILS] directory.  To run it at every
$! boot, add this line to SYS$MANAGER:SYSTARTUP_VMS.COM:
$!
$!     $ @SYS$STARTUP:DIFFUTILS$STARTUP.COM
$!
$! P1 = "INSTALL": also print the post-installation tasks (PCSI runs it so).
$! P1 = "REMOVE":  deassign DIFFUTILS$ROOT instead (PCSI runs it so at removal).
$!
$! Users then define the commands with
$!     $ @DIFFUTILS$ROOT:[000000]DIFFUTILS$SETUP.COM
$!
$ set noon
$ mode = f$edit(p1, "UPCASE")
$ if mode .eqs. "REMOVE"
$ then
$   if f$trnlnm("DIFFUTILS$ROOT", "LNM$SYSTEM_TABLE") .nes. "" then -
        deassign/system/executive_mode DIFFUTILS$ROOT
$   exit 1
$ endif
$!
$! This procedure sits in <destination>[SYS$STARTUP]; the product is in
$! <destination>[DIFFUTILS].  Rooted logicals need the physical form:
$! DKA0:[SYS0.SYSCOMMON.SYS$STARTUP] -> DKA0:[SYS0.SYSCOMMON.DIFFUTILS.]
$ proc = f$environment("PROCEDURE")
$ dev = f$parse(proc,,,"DEVICE","NO_CONCEAL")
$ dir = f$edit(f$parse(proc,,,"DIRECTORY","NO_CONCEAL"), "UPCASE") - "]["
$ root = dir - "SYS$STARTUP]" + "DIFFUTILS.]"
$ if root .eqs. dir + "DIFFUTILS.]"
$ then
$   write sys$error "DIFFUTILS$STARTUP: expected to be in a [SYS$STARTUP] directory, not ''dir'"
$   exit 44
$ endif
$ root = root - ".000000"
$ define/system/executive_mode/translation_attributes=concealed DIFFUTILS$ROOT 'dev''root'
$ if f$search("DIFFUTILS$ROOT:[BIN]DIFF.EXE") .eqs. ""
$ then
$   write sys$error "DIFFUTILS$STARTUP: DIFF.EXE not found under ''dev'''root'"
$   exit 44
$ endif
$ if mode .nes. "INSTALL" then exit 1
$ say = "write sys$output"
$ say ""
$ say "    Post-installation tasks for GNU diffutils"
$ say ""
$ say "    At system startup: to define DIFFUTILS$ROOT at every boot, add this line to"
$ say "    SYS$MANAGER:SYSTARTUP_VMS.COM:"
$ say "    $ @SYS$STARTUP:DIFFUTILS$STARTUP.COM"
$ say "    For each user: to define gdiff, cmp, diff3 and sdiff, add this line to"
$ say "    LOGIN.COM (with the parameter DIFF it also defines diff, which then"
$ say "    replaces DCL's DIFF abbreviation of DIFFERENCES):"
$ say "    $ @DIFFUTILS$ROOT:[000000]DIFFUTILS$SETUP.COM"
$ say ""
$ say "    PRODUCT REMOVE DIFFUTILS removes the product and deassigns DIFFUTILS$ROOT."
$ say ""
$ exit 1

$! DIFFUTILS$SETUP.COM - define the GNU diffutils commands for a user
$!
$! Add to LOGIN.COM (or SYS$MANAGER:SYLOGIN.COM for everyone):
$!     $ @DIFFUTILS$ROOT:[000000]DIFFUTILS$SETUP.COM [DIFF]
$!
$! Defines gdiff, cmp, diff3 and sdiff.  DIFF in DCL abbreviates the
$! DIFFERENCES command, so diff is defined only when P1 is DIFF; it then
$! replaces DCL's DIFF abbreviation for this user (DIFFERENCES in full still
$! runs the VMS command).
$!
$! Upper-case options need SET PROCESS/PARSE_STYLE=EXTENDED, or double
$! quotes, because traditional DCL parsing changes their case; batch jobs
$! use the traditional style.
$!
$ if f$trnlnm("DIFFUTILS$ROOT") .eqs. ""
$ then
$   write sys$error "DIFFUTILS$SETUP: DIFFUTILS$ROOT is not defined; run DIFFUTILS$STARTUP.COM first"
$   exit 44
$ endif
$ gdiff :== $DIFFUTILS$ROOT:[BIN]DIFF.EXE
$ cmp   :== $DIFFUTILS$ROOT:[BIN]CMP.EXE
$ diff3 :== $DIFFUTILS$ROOT:[BIN]DIFF3.EXE
$ sdiff :== $DIFFUTILS$ROOT:[BIN]SDIFF.EXE
$ if f$edit(p1, "UPCASE") .eqs. "DIFF" then diff :== $DIFFUTILS$ROOT:[BIN]DIFF.EXE
$ exit 1

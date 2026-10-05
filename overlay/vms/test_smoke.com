$! TEST_SMOKE.COM - smoke test for the built diffutils ([.BIN_<arch>]*.EXE)
$!
$! Usage:  @[.VMS]TEST_SMOKE [bin-directory]
$! P1: where CMP, DIFF, DIFF3 and SDIFF.EXE are (default [.BIN_<arch>]; the
$!     install check passes DIFFUTILS$ROOT:[BIN]).  diff3 and sdiff are given
$!     that DIFF.EXE with --diff-program.
$!
$ set noon
$ saved_default = f$environment("DEFAULT")
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ bin = f$parse("[.BIN_''arch']",,,"DEVICE") + f$parse("[.BIN_''arch']",,,"DIRECTORY")
$ if p1 .nes. "" then bin = p1
$ write sys$output "SMOKE: testing ", bin
$ cmp   = "$" + bin + "CMP.EXE"
$ diff  = "$" + bin + "DIFF.EXE"
$ diff3 = "$" + bin + "DIFF3.EXE"
$ sdiff = "$" + bin + "SDIFF.EXE"
$ diffprog = "--diff-program=" + bin + "DIFF.EXE"
$ pass = 0
$ fail = 0
$ if f$search("SMOKE.DIR") .eqs. "" then create/directory [.SMOKE]
$ set default [.SMOKE]
$ set process/parse_style=extended
$! b.txt changes line 2 of a.txt, c.txt line 5: diff3 can merge both.
$ create a.txt
alpha
beta
gamma
delta
epsilon
zeta
$ create b.txt
alpha
BETA
gamma
delta
epsilon
zeta
$ create c.txt
alpha
beta
gamma
delta
EPSILON
zeta
$ copy/nolog a.txt a2.txt
$!
$! 1. version
$ define/user sys$output out.txt
$ diff --version
$ search/nooutput out.txt "diff (GNU diffutils) 3"
$ sev = $severity
$ name = "version"
$ gosub check_success
$!
$! 2. identical files: success, no output
$ define/user sys$output out.txt
$ diff a.txt a2.txt
$ sev = $severity
$ if sev .eq. 1 .and. f$file_attributes("out.txt", "EOF") .ne. 0 then sev = 2
$ name = "identical files: success"
$ gosub check_success
$!
$! 3. different files: a warning (exit 1), and the differences
$ define/user sys$output out.txt
$ diff a.txt b.txt
$ sev = $severity
$ if sev .eq. 0
$ then
$   search/nooutput/exact out.txt "< beta"
$   sev = $severity
$   if sev .eq. 1
$   then
$     search/nooutput/exact out.txt "> BETA"
$     sev = $severity
$   endif
$ else
$   sev = 2
$ endif
$ name = "different files: warning severity and the differences"
$ gosub check_success
$!
$! 4. unified diff
$ define/user sys$output out.txt
$ diff "-u" a.txt b.txt
$ search/nooutput/exact out.txt "@@ -1,5 +1,5 @@"
$ sev = $severity
$ if sev .eq. 1
$ then
$   search/nooutput/exact out.txt "+BETA"
$   sev = $severity
$ endif
$ name = "unified diff (-u)"
$ gosub check_success
$!
$! 5. cmp: first difference, warning severity
$ define/user sys$output out.txt
$ cmp a.txt b.txt
$ sev = $severity
$ if sev .eq. 0
$ then
$   search/nooutput out.txt "differ: char 7, line 2"
$   sev = $severity
$ else
$   sev = 2
$ endif
$ name = "cmp reports the first difference"
$ gosub check_success
$!
$! 6. diff3 (runs diff in a subprocess)
$ define/user sys$output out.txt
$ diff3 'diffprog' b.txt a.txt c.txt
$ sev = $severity
$ if sev .eq. 1 .or. sev .eq. 0
$ then
$   search/nooutput/exact out.txt "===="
$   sev = $severity
$ endif
$ name = "diff3 compares three files"
$ gosub check_success
$!
$! 7. diff3 -m merges the two changes
$ define/user sys$output out.txt
$ diff3 'diffprog' "-m" b.txt a.txt c.txt
$ sev = $severity
$ if sev .eq. 1
$ then
$   search/nooutput/exact out.txt "BETA"
$   sev = $severity
$   if sev .eq. 1
$   then
$     search/nooutput/exact out.txt "EPSILON"
$     sev = $severity
$   endif
$ endif
$ name = "diff3 -m merges non-conflicting changes"
$ gosub check_success
$!
$! 8. sdiff side by side (runs diff in a subprocess)
$ define/user sys$output out.txt
$ sdiff 'diffprog' "-w" 40 a.txt b.txt
$ sev = $severity
$ if sev .eq. 0
$ then
$   search/nooutput out.txt "beta","|","BETA"/match=and
$   sev = $severity
$ else
$   sev = 2
$ endif
$ name = "sdiff side by side"
$ gosub check_success
$!
$! 9. a subprocess leaves a redirected SYS$OUTPUT alone (no extra version)
$ define/user sys$output red.txt
$ diff3 'diffprog' b.txt a.txt c.txt
$ sev = 1
$ if f$search("red.txt;-1") .nes. "" then sev = 2
$ name = "diff3 with SYS$OUTPUT redirected: no extra version"
$ gosub check_success
$!
$! 10. directories (-r)
$ create/directory [.D1]
$ create/directory [.D2]
$ copy/nolog a.txt [.D1]f.txt
$ copy/nolog b.txt [.D2]f.txt
$ copy/nolog a.txt [.D1]only1.txt
$ define/user sys$output out.txt
$ diff "-r" d1 d2
$ sev = $severity
$ if sev .eq. 0
$ then
$   search/nooutput out.txt "Only in d1: only1.txt"
$   sev = $severity
$ else
$   sev = 2
$ endif
$ name = "diff -r on directories"
$ gosub check_success
$!
$! 11. a missing file is trouble: error severity
$ define/user sys$error nla0:
$ diff a.txt nonexistent.txt
$ sev = $severity
$ name = "missing file gives an error status"
$ gosub check_failure
$!
$ write sys$output "SMOKE: ''pass' passed, ''fail' failed"
$ delete/nolog [.D1]*.*;*,[.D2]*.*;*
$ set file/protection=o:rwed D1.DIR,D2.DIR
$ delete/nolog *.*;*
$ set default [-]
$ set file/protection=o:rwed SMOKE.DIR
$ delete/nolog SMOKE.DIR;
$ set default 'saved_default'
$ if fail .eq. 0 then exit 1
$ exit 44
$!
$check_success:
$ if sev .eq. 1
$ then
$   pass = pass + 1
$   write sys$output "PASS: ", name
$ else
$   fail = fail + 1
$   write sys$output "FAIL: ", name, " (severity ", sev, ")"
$   if f$search("out.txt") .nes. ""
$   then
$     write sys$output "   output was:"
$     type out.txt;0
$   endif
$ endif
$ return
$!
$check_failure:
$ if sev .eq. 2 .or. sev .eq. 4
$ then
$   pass = pass + 1
$   write sys$output "PASS: ", name
$ else
$   fail = fail + 1
$   write sys$output "FAIL: ", name, " (severity ", sev, ", expected an error)"
$ endif
$ return

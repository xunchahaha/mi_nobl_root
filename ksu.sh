#!/bin/sh
/system/bin/service call miui.mqsas.IMQSNative 21 i32 1 s16 "sh" i32 1 s16 "/data/local/tmp/ksu_step1.sh" s16 "/data/local/tmp/ksu_result.txt" i32 60 >nul 2>&1
/system/bin/service call miui.mqsas.IMQSNative 21 i32 1 s16 "sh" i32 1 s16 "/data/local/tmp/ksu_step2.sh" s16 "/data/local/tmp/ksu_result.txt" i32 60 >nul 2>&1
/system/bin/cat /storage/emulated/0/ksu_result.txt 2>nul | findstr "ALL_DONE" >nul 2>&1 || echo "ksu loaded, loading lspd"
sleep 3
/system/bin/service call miui.mqsas.IMQSNative 21 i32 1 s16 '/system/bin/sh' i32 1 s16 '/data/local/tmp/fix_lspd.sh' s16 '/data/local/tmp/lspd_fix_out.txt' i32 180

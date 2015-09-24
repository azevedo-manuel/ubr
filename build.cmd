@echo off

if "%1" == "" goto ERROR

goto MAIN

:ERROR

Echo You need to introduce a release number (example: '%0 0.6')

goto DONE 

:MAIN

set buildoptions=-c
set buildfile=ubr.exe
set sourcefile=ubr.pl
set bundlefile=ubr-v%1.zip
set includefiles=%buildfile% Readme.md doc
set sevenzipfile="c:\Program Files\7-Zip\7z.exe"
set sevenzipopts=a -r -y

if not exist %sevenzipfile% (
	echo 7 ZIP not found. Install it in:
	echo '%sevenzipfile%'
	goto DONE
)

echo Release: v%1

call pp %buildoptions% -o %buildfile% %sourcefile%

if exist %buildfile% (
	echo Creating package %bundlefile%
	%sevenzipfile% %sevenzipopts% %bundlefile% %includefiles%
) else (
	echo Package file creation failed!
)

if exist %bundlefile% (
	echo Package creation complete. Cleaning temp files
	del %buildfile%
) else (
	echo ZIP file %bundlefile% not created
)
:DONE
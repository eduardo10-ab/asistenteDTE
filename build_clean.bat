@echo off
REM Script para compilar con Java 21 estable
setlocal

set "JAVA_HOME=C:\Users\eduaf\.vscode\extensions\redhat.java-1.54.0-win32-x64\jre\21.0.10-win32-x86_64"

if not exist "%JAVA_HOME%\bin\java.exe" (
	echo ERROR: No se encontro java.exe en %JAVA_HOME%
	exit /b 1
)

set "PATH=%JAVA_HOME%\bin;%PATH%"

cd /d "c:\Users\eduaf\StudioProjects\app_factura"

echo Iniciando Flutter build...
flutter build apk --debug

pause

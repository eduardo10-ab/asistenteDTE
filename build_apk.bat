@echo off
setlocal enabledelayedexpansion

REM Establecer JAVA_HOME a Java 21 LTS estable
set "JAVA_HOME=C:\Users\eduaf\.vscode\extensions\redhat.java-1.54.0-win32-x64\jre\21.0.10-win32-x86_64"

if not exist "%JAVA_HOME%\bin\java.exe" (
	echo ERROR: No se encontro java.exe en %JAVA_HOME%
	exit /b 1
)

REM Verificar que JAVA_HOME está configurado
echo JAVA_HOME=%JAVA_HOME%

REM Verificar que java está disponible
"%JAVA_HOME%\bin\java.exe" -version

REM Cambiar a directorio del proyecto
cd /d "c:\Users\eduaf\StudioProjects\app_factura"

REM Ejecutar flutter build
echo.
echo Generando APK DEBUG...
echo.
call flutter build apk --debug

echo.
echo APK generado. Ubicación: build\app\outputs\flutter-apk\app-debug.apk
pause

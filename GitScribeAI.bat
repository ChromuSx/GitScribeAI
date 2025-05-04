@echo off
setlocal EnableDelayedExpansion

REM Determine the directory where the script is located
set "SCRIPT_DIR=%~dp0"
set "CONFIG_FILE=%SCRIPT_DIR%gitscribeai_config.ini"

REM Set default parameters
set MODEL=gpt-4o
set LANGUAGE=english
set COMMIT_DIRECTLY=false
set OPENAI_API_KEY=

REM Load settings from config file if it exists
if exist "%CONFIG_FILE%" (
    echo Loading configuration from %CONFIG_FILE%...
    call :load_config
) else (
    echo Configuration file not found. Using default settings.
    echo To create a configuration file, run "%~nx0 --create-config"
)

REM Parse command line parameters (these override the configuration)
:parse_args
if "%~1"=="" goto end_parse_args
if "%~1"=="--model" set MODEL=%~2& shift & shift & goto parse_args
if "%~1"=="--lang" set LANGUAGE=%~2& shift & shift & goto parse_args
if "%~1"=="--commit" set COMMIT_DIRECTLY=true& shift & goto parse_args
if "%~1"=="--help" goto show_help
if "%~1"=="--create-config" goto create_config
shift
goto parse_args
:end_parse_args

REM Check if git is available
git --version > nul 2>&1
if %ERRORLEVEL% NEQ 0 (
   echo Error: Git not found. Make sure git is installed and in your PATH.
   exit /b 1
)

REM API key management (priority: 1. Environment variable 2. Config file)
if "!OPENAI_API_KEY!"=="" (
   if defined OPENAI_API_KEY (
      echo Using API key from environment variables
   ) else (
      echo Error: OpenAI API key not found.
      echo You can configure it in two ways:
      echo 1. Set it in the %CONFIG_FILE% file
      echo 2. Define the OPENAI_API_KEY environment variable
      exit /b 1
   )
)

echo.
echo Getting staged file diff...
REM Create a unique temporary folder
set TEMP_DIR=%TEMP%\gitscribeai_%RANDOM%
mkdir %TEMP_DIR% 2>nul

REM Save the diff to a temporary file
git diff --staged > "%TEMP_DIR%\git_diff_temp.txt"

REM Check if there are changes
for %%A in ("%TEMP_DIR%\git_diff_temp.txt") do set size=%%~zA
if %size% EQU 0 (
    echo.
    echo No staged changes found.
    rd /s /q %TEMP_DIR% 2>nul
    exit /b 0
)

echo.
echo Preparing API request...

REM Set the prompt based on the selected language
if "%LANGUAGE%"=="english" (
   set "prompt=Analyze the following Git diff and generate a concise and descriptive commit message in English, following conventional commit conventions (type: description). Reply ONLY with the commit message, without further explanations:"
) else if "%LANGUAGE%"=="italian" (
   set "prompt=Analizza il seguente diff di Git e genera un messaggio di commit conciso e descrittivo in italiano, seguendo le convenzioni di commit convenzionali (tipo: descrizione). Rispondi SOLO con il messaggio di commit, senza ulteriori spiegazioni:"
) else (
   echo Unsupported language: %LANGUAGE%
   echo Using English as default language.
   set "prompt=Analyze the following Git diff and generate a concise and descriptive commit message in English, following conventional commit conventions (type: description). Reply ONLY with the commit message, without further explanations:"
)

echo.
echo Calling OpenAI API...

REM Create a single-line PowerShell command with correct escaping
powershell -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; try { $diff = Get-Content -Raw '%TEMP_DIR%\git_diff_temp.txt' -Encoding UTF8; $prompt = '%prompt%'; $fullContent = $prompt + [Environment]::NewLine + [Environment]::NewLine + $diff; $requestBody = @{ model = '%MODEL%'; messages = @( @{ role = 'user'; content = $fullContent } ) }; $client = New-Object System.Net.WebClient; $client.Headers.Add('Content-Type', 'application/json'); $client.Headers.Add('Authorization', 'Bearer %OPENAI_API_KEY%'); $jsonBody = ConvertTo-Json -InputObject $requestBody -Depth 10 -Compress; $responseBytes = $client.UploadData('https://api.openai.com/v1/chat/completions', 'POST', [System.Text.Encoding]::UTF8.GetBytes($jsonBody)); $responseBody = [System.Text.Encoding]::UTF8.GetString($responseBytes); $response = $responseBody | ConvertFrom-Json; if ($response.choices -and $response.choices.Count -gt 0) { $message = $response.choices[0].message.content.Trim(); Write-Output $message; } else { throw 'Invalid response format'; } } catch { Write-Error \"ERROR: $_\"; exit 1; }" > "%TEMP_DIR%\clean_message.txt" 2> "%TEMP_DIR%\error.txt"

if %ERRORLEVEL% NEQ 0 (
   echo Errore durante la chiamata API:
   type "%TEMP_DIR%\error.txt"
   goto cleanup
)

REM Read the clean message
set /p COMMIT_MESSAGE=<"%TEMP_DIR%\clean_message.txt"

REM Display the message
echo.
echo Generated commit message:
echo !COMMIT_MESSAGE!
echo.

REM Copy the clean message to the clipboard
echo !COMMIT_MESSAGE!| clip
echo.
echo Message copied to clipboard.

REM If the --commit option is active, execute the commit directly
if "%COMMIT_DIRECTLY%"=="true" (
   echo.
   echo Executing commit with the generated message...
   git commit -m "!COMMIT_MESSAGE!"
   if %ERRORLEVEL% EQU 0 (
      echo Commit executed successfully.
   ) else (
      echo Error during commit execution.
   )
)

goto cleanup

REM ===== FUNCTIONS =====

:show_help
echo Usage: GitScribeAI [options]
echo.
echo Options:
echo   --model MODEL       Specify the OpenAI model (default: gpt-4o)
echo   --lang LANGUAGE     Specify the message language (default: english)
echo   --commit            Execute git commit directly with the generated message
echo   --create-config     Create a configuration file with current settings
echo   --help              Show this help message
echo.
echo Settings can be configured in the %CONFIG_FILE% file
exit /b 0

:create_config
echo Creating configuration file %CONFIG_FILE%...
(
echo [Settings]
echo MODEL=%MODEL%
echo LANGUAGE=%LANGUAGE%
echo COMMIT_DIRECTLY=%COMMIT_DIRECTLY%
echo.
echo [API]
echo # Leave empty if you prefer to use environment variables
echo # SECURITY WARNING: Never commit this file with your API key to public repositories
echo OPENAI_API_KEY=
) > "%CONFIG_FILE%"
echo Configuration file created successfully.
echo NOTE: Edit the file to insert your API key, but NEVER commit it to public repositories.
echo       Consider adding this file to .gitignore for security.
exit /b 0

:load_config
REM Function to load settings from the configuration file
for /f "tokens=1,2 delims==" %%a in ('type "%CONFIG_FILE%" ^| findstr /v "^#" ^| findstr /v "^$" ^| findstr "="') do (
    set "param=%%a"
    set "value=%%b"
    
    REM Remove leading and trailing spaces
    set "param=!param: =!"
    
    if "!param!"=="MODEL" set "MODEL=!value!"
    if "!param!"=="LANGUAGE" set "LANGUAGE=!value!"
    if "!param!"=="COMMIT_DIRECTLY" set "COMMIT_DIRECTLY=!value!"
    if "!param!"=="OPENAI_API_KEY" set "OPENAI_API_KEY=!value!"
)
exit /b 0

:cleanup
REM Clean up temporary files
rd /s /q %TEMP_DIR% 2>nul

REM Exit script successfully
exit /b 0
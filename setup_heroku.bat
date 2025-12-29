@echo off
setlocal

echo ========================================================
echo Firecrawl Heroku Setup Script
echo ========================================================

REM Check if Heroku CLI is installed
where heroku >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: Heroku CLI is not found in PATH.
    echo Please install Heroku CLI and login before running this script.
    exit /b 1
)

REM Check if user is logged in
call heroku auth:whoami >nul 2>nul
if %errorlevel% neq 0 (
    echo You are not logged in to Heroku.
    echo Please run 'heroku login' and try again.
    exit /b 1
)

REM Generate App Names
set API_APP_NAME=firecrawl-api-%RANDOM%-%RANDOM%
set PW_APP_NAME=firecrawl-pw-%RANDOM%-%RANDOM%

echo Creating API App: %API_APP_NAME%...
call heroku apps:create %API_APP_NAME%
if %errorlevel% neq 0 (
    echo Failed to create API app.
    exit /b 1
)

echo Creating Playwright Service App: %PW_APP_NAME%...
call heroku apps:create %PW_APP_NAME%
if %errorlevel% neq 0 (
    echo Failed to create Playwright app.
    exit /b 1
)

echo.
echo ========================================================
echo Provisioning Add-ons for API App...
echo ========================================================

echo Adding Heroku Postgres (Essential)...
call heroku addons:create heroku-postgresql:essential --app %API_APP_NAME%

echo Adding Heroku Redis (Mini)...
call heroku addons:create heroku-redis:mini --app %API_APP_NAME%

echo Adding CloudAMQP (Lemur)...
call heroku addons:create cloudamqp:lemur --app %API_APP_NAME%

echo.
echo ========================================================
echo Configuring Environment Variables...
echo ========================================================

REM Set Playwright Service URL on API App
set PW_URL=https://%PW_APP_NAME%.herokuapp.com/scrape
echo Linking API to Playwright at %PW_URL%...

call heroku config:set PLAYWRIGHT_MICROSERVICE_URL=%PW_URL% --app %API_APP_NAME%
call heroku config:set HOST=0.0.0.0 --app %API_APP_NAME%
call heroku config:set BULL_AUTH_KEY=changeme_to_secure_random --app %API_APP_NAME%
call heroku config:set NUM_WORKERS_PER_QUEUE=2 --app %API_APP_NAME%

REM Set Stack to Container
echo Setting stack to container for proper Docker support...
call heroku stack:set container --app %API_APP_NAME%
call heroku stack:set container --app %PW_APP_NAME%

echo.
echo ========================================================
echo Setting Up GitHub Secrets...
echo ========================================================

where gh >nul 2>nul
if %errorlevel% equ 0 (
    echo GitHub CLI (gh) found. Attempting to set secrets...
    
    echo Setting HEROKU_APP_NAME_API...
    call gh secret set HEROKU_APP_NAME_API --body "%API_APP_NAME%"
    
    echo Setting HEROKU_APP_NAME_PLAYWRIGHT...
    call gh secret set HEROKU_APP_NAME_PLAYWRIGHT --body "%PW_APP_NAME%"
    
    echo.
    echo NOTE: You still need to set HEROKU_API_KEY manually if not already set.
    echo checking if HEROKU_API_KEY is mapped...
    
    REM Get Heroku API Key
    for /f "tokens=*" %%i in ('heroku auth:token') do set HEROKU_TOKEN=%%i
    
    echo Setting HEROKU_API_KEY from current session...
    call gh secret set HEROKU_API_KEY --body "%HEROKU_TOKEN%"
    
    echo Secrets configured!
) else (
    echo GitHub CLI (gh) not found in PATH.
    echo Please manually set the following Secrets in your GitHub Repo:
    echo.
    echo HEROKU_APP_NAME_API = %API_APP_NAME%
    echo HEROKU_APP_NAME_PLAYWRIGHT = %PW_APP_NAME%
    echo HEROKU_API_KEY = [Your Heroku API Key check 'heroku auth:token']
    echo.
)

echo.
echo ========================================================
echo Setup Complete!
echo ========================================================
echo 1. Changes to 'apps/api/src/config.ts' and '.github/workflows' need to be committed.
echo 2. Run: git add .
echo 3. Run: git commit -m "Configure Heroku deployment"
echo 4. Run: git push origin main
echo.
echo Once pushed, the GitHub Action will start building and deploying your apps.
echo API URL: https://%API_APP_NAME%.herokuapp.com
echo Playwright URL: https://%PW_APP_NAME%.herokuapp.com
echo.
pause

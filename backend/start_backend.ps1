# Starts ASGI server, Celery worker, and Celery beat in separate windows.
# Run from the backend folder.

$backendDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $backendDir

$venvPython = Join-Path $backendDir "venv\Scripts\python.exe"
$venvActivate = Join-Path $backendDir "venv\Scripts\Activate.ps1"
if (-not (Test-Path $venvActivate)) {
  Write-Host "Virtual environment not found at $venvActivate" -ForegroundColor Red
  Write-Host "Create it with: python -m venv venv" -ForegroundColor Yellow
  exit 1
}

$missingPackages = @('daphne', 'celery')
$missingDeps = @()
foreach ($pkg in $missingPackages) {
  & $venvPython -c "import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('$pkg') else 1)" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    $missingDeps += $pkg
  }
}

if ($missingDeps.Count -gt 0) {
  Write-Host "Installing missing Python dependencies: $($missingDeps -join ', ')" -ForegroundColor Yellow
  & $venvPython -m pip install -r requirements.txt
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Dependency installation failed." -ForegroundColor Red
    exit 1
  }
}

$common = ". .\venv\Scripts\Activate.ps1"

Start-Process powershell -WorkingDirectory $backendDir -ArgumentList "-NoExit", "-Command", "$common; python -m daphne auditra_backend.asgi:application"
Start-Process powershell -WorkingDirectory $backendDir -ArgumentList "-NoExit", "-Command", "$common; python -m celery -A auditra_backend worker -l info --pool=solo"
Start-Process powershell -WorkingDirectory $backendDir -ArgumentList "-NoExit", "-Command", "$common; python -m celery -A auditra_backend beat -l info"

Write-Host "Started ASGI, Celery worker, and Celery beat." -ForegroundColor Green

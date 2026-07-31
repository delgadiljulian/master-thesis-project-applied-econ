[CmdletBinding()]
param(
    [ValidateSet("01", "02", "03", "all")]
    [string]$Stage = "all",

    [string]$StataExecutable = "C:\Program Files\Stata17\StataMP-64.exe"
)

$ErrorActionPreference = "Stop"

# Localizar la raíz a partir de la carpeta donde está guardado este ejecutor.
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDirectory "..\..\..\..")).Path

# Centralizar los registros automáticos de Stata en outputs.
$outputLogs = Join-Path $projectRoot "outputs\econometrics\stata-peer-1\gmm\logs"
$batchLogs = Join-Path $outputLogs "batch"
New-Item -ItemType Directory -Path $batchLogs -Force | Out-Null

# Verificar que el ejecutable solicitado existe antes de iniciar el análisis.
if (-not (Test-Path -LiteralPath $StataExecutable)) {
    throw "No se encontró Stata en: $StataExecutable"
}

# Definir el nombre del .do, su log analítico y la frase que confirma el cierre.
$availableStages = @{
    "01" = [pscustomobject]@{
        DoFile = "01_data_prep_and_diagnostics.do"
        InternalLog = "01_gmm_data_prep_and_diagnostics.log"
        CompletionMarker = "Parte 1 (GMM Data Prep & Diagnostics) completada con éxito."
    }
    "02" = [pscustomobject]@{
        DoFile = "02_models_and_exports.do"
        InternalLog = "02_models_and_exports.log"
        CompletionMarker = "Parte 2 (Secciones 5 a 8) completada con éxito."
    }
    "03" = [pscustomobject]@{
        DoFile = "03_resource_disaggregation.do"
        InternalLog = "03_resource_disaggregation.log"
        CompletionMarker = "Parte 3 (Secciones 9 a 14) completada con éxito."
    }
}

$stagesToRun = if ($Stage -eq "all") { @("01", "02", "03") } else { @($Stage) }

foreach ($s in $stagesToRun) {
    $info = $availableStages[$s]
    $doPath = Join-Path $scriptDirectory $info.DoFile
    $logPath = Join-Path $outputLogs $info.InternalLog

    if (-not (Test-Path -LiteralPath $doPath)) {
        throw "No existe el script .do requerido: $doPath"
    }

    Write-Host "Iniciando Etapa $s ($($info.DoFile)) en GMM..." -ForegroundColor Cyan

    $process = Start-Process -FilePath $StataExecutable -ArgumentList "/e", "do", "`"$doPath`"" -WorkingDirectory $scriptDirectory -PassThru -Wait

    if ($process.ExitCode -ne 0) {
        throw "Stata finalizó con un código de error no nulo ($($process.ExitCode)) en la Etapa $s."
    }

    if (-not (Test-Path -LiteralPath $logPath)) {
        throw "El archivo de log interno de la Etapa $s no fue generado en: $logPath"
    }

    $logContent = Get-Content -LiteralPath $logPath -Raw -Encoding UTF8
    if ($logContent -notmatch [regex]::Escape($info.CompletionMarker)) {
        throw "La Etapa $s finalizó pero no registró la marca de éxito esperada en $logPath."
    }

    Write-Host "Etapa $s completada correctamente en GMM." -ForegroundColor Green
}

Write-Host "Ejecución de GMM completada con éxito." -ForegroundColor Green

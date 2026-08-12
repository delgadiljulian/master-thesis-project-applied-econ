[CmdletBinding()]
param(
    [ValidateSet(
        "01", "02", "03", "04", "05", "06", "07", "08",
        "core", "extensions", "formal", "all"
    )]
    [string]$Stage = "02",

    [string]$StataExecutable = "C:\Program Files\Stata17\StataMP-64.exe"
)

$ErrorActionPreference = "Stop"

# Localizar la raíz a partir de la carpeta donde está guardado este ejecutor.
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDirectory "..\..\..\..")).Path

# Centralizar los registros automáticos de Stata en outputs.
$outputLogs = Join-Path $projectRoot "outputs\econometrics\stata-peer-1\01_twfe_main\logs"
$batchLogs = Join-Path $outputLogs "batch"
New-Item -ItemType Directory -Path $batchLogs -Force | Out-Null

# Verificar que el ejecutable solicitado existe antes de iniciar el análisis.
if (-not (Test-Path -LiteralPath $StataExecutable)) {
    throw "No se encontró Stata en: $StataExecutable"
}

# Definir el nombre del .do, su log analítico y la frase que confirma el cierre.
$availableStages = @{
    "01" = [pscustomobject]@{
        DoFile = "01_data_preparation_diagnostics.do"
        InternalLog = "logs\01_data_prep_and_diagnostics.log"
        CompletionMarker = "Parte 1 (Secciones 1 a 4) completada con éxito en stata-peer-1."
    }
    "02" = [pscustomobject]@{
        DoFile = "02_twfe_extractive_export_structure.do"
        InternalLog = "logs\02_twfe_extractive_export_structure.log"
        CompletionMarker = "Archivo 02 finalizado: secciones 5 y 6 completadas sin errores."
    }
    "03" = [pscustomobject]@{
        DoFile = "03_twfe_capabilities_stability.do"
        InternalLog = "logs\03_twfe_capabilities_stability.log"
        CompletionMarker = "Archivo 03 finalizado sin errores."
    }
    "04" = [pscustomobject]@{
        DoFile = "04_twfe_full.do"
        InternalLog = "logs\04_twfe_full.log"
        CompletionMarker = "Parte 2 (Secciones 5 a 8) completada con éxito en stata-peer-1."
    }
    "05" = [pscustomobject]@{
        DoFile = "05_twfe_model_comparison.do"
        InternalLog = "logs\05_twfe_model_comparison.log"
        CompletionMarker = "Archivo 05 finalizado sin errores."
    }
    "06" = [pscustomobject]@{
        DoFile = "06_twfe_oil_gas_models.do"
        InternalLog = "logs\06_twfe_oil_gas_models.log"
        CompletionMarker = "Archivo 06 finalizado sin errores."
    }
    "07" = [pscustomobject]@{
        DoFile = "07_twfe_mining_models.do"
        InternalLog = "logs\07_twfe_mining_models.log"
        CompletionMarker = "Archivo 07 finalizado sin errores."
    }
    "08" = [pscustomobject]@{
        DoFile = "08_twfe_resource_disaggregated_full.do"
        InternalLog = "logs\08_twfe_resource_disaggregated_full.log"
        CompletionMarker = "Parte 3 (Secciones 9 a 14) completada con éxito total en stata-peer-1."
    }
}

# Ejecutar una etapa y esperar a que su propio log confirme el cierre correcto.
function Invoke-StataStage {
    param(
        [Parameter(Mandatory)]
        [string]$StageNumber
    )

    $stageDefinition = $availableStages[$StageNumber]
    $doPath = Join-Path $scriptDirectory $stageDefinition.DoFile
    $internalLogPath = Join-Path $outputLogs $stageDefinition.InternalLog
    $automaticLogPath = Join-Path $batchLogs (
        [System.IO.Path]::GetFileNameWithoutExtension($stageDefinition.DoFile) + ".log"
    )

    if (-not (Test-Path -LiteralPath $doPath)) {
        throw "No se encontró el archivo requerido: $doPath"
    }

    if (Test-Path -LiteralPath $automaticLogPath) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $archivedName = "{0}_{1}.log" -f $timestamp, (
            [System.IO.Path]::GetFileNameWithoutExtension($stageDefinition.DoFile)
        )
        Move-Item -LiteralPath $automaticLogPath -Destination (
            Join-Path $batchLogs $archivedName
        ) -Force
    }

    $startedAt = Get-Date
    $stataProcess = Start-Process `
        -FilePath $StataExecutable `
        -ArgumentList @("/b", "do", "`"$doPath`"") `
        -WorkingDirectory $batchLogs `
        -WindowStyle Hidden `
        -PassThru

    $deadline = $startedAt.AddMinutes(30)
    $completed = $false

    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 1
        $stataProcess.Refresh()

        if (Test-Path -LiteralPath $automaticLogPath) {
            $logItem = Get-Item -LiteralPath $automaticLogPath
            if ($logItem.LastWriteTime -ge $startedAt.AddSeconds(-2)) {
                $marker = Select-String `
                    -LiteralPath $automaticLogPath `
                    -SimpleMatch $stageDefinition.CompletionMarker `
                    -Quiet
                if ($marker) {
                    $completed = $true
                    break
                }
            }
        }

        if ($stataProcess.HasExited) {
            break
        }
    }

    if (-not $completed) {
        if (-not $stataProcess.HasExited) {
            Stop-Process -Id $stataProcess.Id -Force
        }
        throw "La etapa $StageNumber falló o no escribió el marcador de finalización: $($stageDefinition.CompletionMarker)"
    }

    Write-Host "Etapa $StageNumber completada en stata-peer-1."
}

if ($Stage -eq "core") {
    $stagesToRun = @("01", "02", "03", "04", "05")
}
elseif ($Stage -eq "all") {
    $stagesToRun = @("01", "02", "03", "04", "05", "06", "07", "08")
}
else {
    $stagesToRun = @($Stage)
}

foreach ($stageNumber in $stagesToRun) {
    Invoke-StataStage -StageNumber $stageNumber
}

Write-Host "Ejecución finalizada en stata-peer-1."

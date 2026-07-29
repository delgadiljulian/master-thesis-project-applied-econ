[CmdletBinding()]
param(
    [ValidateSet("01", "02", "all")]
    [string]$Stage = "all",

    [string]$StataExecutable = "C:\Program Files\Stata17\StataMP-64.exe"
)

$ErrorActionPreference = "Stop"

# Localizar la raíz a partir de la carpeta donde está guardado este ejecutor.
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDirectory "..\..\..")).Path

# Centralizar los registros automáticos de Stata en outputs.
$outputLogs = Join-Path $projectRoot "outputs\econometrics\stata-peer-1\logs"
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
        InternalLog = "01_data_prep_and_diagnostics.log"
        CompletionMarker = "Parte 1 (Secciones 1 a 4) completada con éxito en stata-peer-1."
    }
    "02" = [pscustomobject]@{
        DoFile = "02_models_and_exports.do"
        InternalLog = "02_models_and_exports.log"
        CompletionMarker = "Parte 2 (Secciones 5 a 8) completada con éxito en stata-peer-1."
    }
}

# Ejecutar una etapa y esperar a que su propio log confirme el cierre correcto.
function Invoke-StataStage {
    param(
        [Parameter(Mandatory)]
        [string]$StageNumber
    )

    # Resolver las rutas completas utilizadas por esta etapa.
    $stageDefinition = $availableStages[$StageNumber]
    $doPath = Join-Path $scriptDirectory $stageDefinition.DoFile
    $internalLogPath = Join-Path $outputLogs $stageDefinition.InternalLog
    $automaticLogPath = Join-Path $batchLogs (
        [System.IO.Path]::GetFileNameWithoutExtension($stageDefinition.DoFile) + ".log"
    )

    # Detener la ejecución si el archivo .do no está disponible.
    if (-not (Test-Path -LiteralPath $doPath)) {
        throw "No se encontró el archivo requerido: $doPath"
    }

    # Archivar el log batch anterior si existe.
    if (Test-Path -LiteralPath $automaticLogPath) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $archivedName = "{0}_{1}.log" -f $timestamp, (
            [System.IO.Path]::GetFileNameWithoutExtension($stageDefinition.DoFile)
        )
        Move-Item -LiteralPath $automaticLogPath -Destination (
            Join-Path $batchLogs $archivedName
        )
    }

    # Iniciar Stata en modo batch usando logs/batch como directorio de trabajo.
    $startedAt = Get-Date
    $stataProcess = Start-Process `
        -FilePath $StataExecutable `
        -ArgumentList @("/b", "do", "`"$doPath`"") `
        -WorkingDirectory $batchLogs `
        -WindowStyle Hidden `
        -PassThru

    # Esperar hasta treinta minutos por la confirmación escrita por el .do.
    $deadline = $startedAt.AddMinutes(30)
    $completed = $false

    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 1
        $stataProcess.Refresh()

        # Aceptar el cierre únicamente cuando el log fue actualizado durante esta ejecución.
        if (Test-Path -LiteralPath $internalLogPath) {
            $logItem = Get-Item -LiteralPath $internalLogPath
            if ($logItem.LastWriteTime -ge $startedAt.AddSeconds(-2)) {
                $marker = Select-String `
                    -LiteralPath $internalLogPath `
                    -SimpleMatch $stageDefinition.CompletionMarker `
                    -Quiet
                if ($marker) {
                    $completed = $true
                    break
                }
            }
        }

        # Informar inmediatamente si Stata termina sin escribir el marcador.
        if ($stataProcess.HasExited) {
            break
        }
    }

    # Cerrar el proceso batch residual después de que el log confirmó el éxito.
    if (-not $stataProcess.HasExited) {
        Stop-Process -Id $stataProcess.Id -Force
    }

    # Detener el ejecutor si la etapa no produjo un cierre verificable.
    if (-not $completed) {
        throw (
            "La etapa $StageNumber no confirmó su finalización. " +
            "Revise: $automaticLogPath"
        )
    }

    Write-Host "Etapa $StageNumber completada correctamente en stata-peer-1."
}

# Construir el orden de ejecución solicitado por el usuario.
if ($Stage -eq "all") {
    $stagesToRun = @("01", "02")
}
else {
    $stagesToRun = @($Stage)
}

# Ejecutar las etapas seleccionadas respetando el orden metodológico.
foreach ($stageNumber in $stagesToRun) {
    Invoke-StataStage -StageNumber $stageNumber
}

Write-Host "Logs batch de stata-peer-1 guardados en: $batchLogs"

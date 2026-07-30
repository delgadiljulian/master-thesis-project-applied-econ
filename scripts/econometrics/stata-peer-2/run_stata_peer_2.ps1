[CmdletBinding()]
param(
    [ValidateSet("01", "02", "03", "all")]
    [string]$Stage = "all",

    # Ejecutar la siguiente instrucción del bloque
    [string]$StataExecutable = "C:\Program Files\Stata17\StataMP-64.exe"
)

# Ejecutar la siguiente instrucción del bloque
$ErrorActionPreference = "Stop"

# Localizar la raíz a partir de la carpeta donde está guardado este ejecutor.
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDirectory "..\..\..")).Path

# Centralizar los registros automáticos de Stata en outputs. Esta carpeta
# contiene únicamente los logs externos del modo batch; los logs analíticos
# creados dentro de cada .do permanecen un nivel más arriba.
$outputLogs = Join-Path $projectRoot "outputs\econometrics\stata-peer-2\logs"
$batchLogs = Join-Path $outputLogs "batch"
New-Item -ItemType Directory -Path $batchLogs -Force | Out-Null
$econometricsOutput = Join-Path $projectRoot "outputs\econometrics\stata-peer-2"

# Verificar que el ejecutable solicitado existe antes de iniciar el análisis.
if (-not (Test-Path -LiteralPath $StataExecutable)) {
    throw "No se encontró Stata en: $StataExecutable"
}

# Definir el nombre del .do, su log analítico y la frase que confirma el cierre.
$availableStages = @{
    "01" = [pscustomobject]@{
        DoFile = "01_data_preparation_diagnostics.do"
        InternalLog = "logs\01_data_preparation_diagnostics.log"
        CompletionMarker = "Archivo 01 completado: secciones 1 a 4 ejecutadas sin errores."
    }
    "02" = [pscustomobject]@{
        DoFile = "02_econometric_models.do"
        InternalLog = "logs\02_econometric_models.log"
        CompletionMarker = "Archivo 02 finalizado sin errores."
    }
    "03" = [pscustomobject]@{
        DoFile = "03_resource_disaggregation.do"
        InternalLog = "07_resource_disaggregation\logs\03_resource_disaggregation.log"
        CompletionMarker = "Archivo 03 finalizado: secciones 9 a 14 completadas sin errores."
    }
}

# Calcular las huellas de los outputs agregados que la etapa 03 solo puede leer.
function Get-ProtectedOutputSnapshot {
    param(
        [Parameter(Mandatory)]
        [string]$OutputRoot
    )

    # Delimitar las carpetas pertenecientes a las secciones 1 a 8.
    $protectedFolders = @(
        "00_design",
        "01_sample",
        "02_diagnostics",
        "03_eci",
        "04_divx",
        "05_stability",
        "06_final"
    )

    # Registrar ruta relativa y SHA-256 de cada archivo protegido.
    $snapshot = foreach ($folderName in $protectedFolders) {
        $folderPath = Join-Path $OutputRoot $folderName
        if (Test-Path -LiteralPath $folderPath) {
            foreach ($file in Get-ChildItem -LiteralPath $folderPath -Recurse -File) {
                [pscustomobject]@{
                    Path = $file.FullName.Substring($OutputRoot.Length).TrimStart("\")
                    Hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
                }
            }
        }
    }

    # Ordenar el resultado para que la comparación sea determinística.
    return @($snapshot | Sort-Object Path)
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
    $internalLogPath = Join-Path $econometricsOutput $stageDefinition.InternalLog
    $automaticLogPath = Join-Path $batchLogs (
        [System.IO.Path]::GetFileNameWithoutExtension($stageDefinition.DoFile) + ".log"
    )

    # Detener la ejecución si el archivo .do no está disponible.
    if (-not (Test-Path -LiteralPath $doPath)) {
        throw "No se encontró el archivo requerido: $doPath"
    }

    # Tomar una fotografía de las secciones 1 a 8 antes de ejecutar la etapa 03.
    $protectedOutputBefore = $null
    if ($StageNumber -eq "03") {
        $protectedOutputBefore = Get-ProtectedOutputSnapshot `
            -OutputRoot $econometricsOutput
    }

    # Archivar el log batch anterior para que Stata pueda crear uno nuevo sin
    # escribir en la raíz ni sobrescribir el historial de ejecuciones.
    if (Test-Path -LiteralPath $automaticLogPath) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $archivedName = "{0}_{1}.log" -f $timestamp, (
            [System.IO.Path]::GetFileNameWithoutExtension($stageDefinition.DoFile)
        )
        Move-Item -LiteralPath $automaticLogPath -Destination (
            Join-Path $batchLogs $archivedName
        )
    }

    # Iniciar Stata sin interfaz usando logs/batch como directorio de trabajo.
    # De esta manera el registro automático nunca aparece en la raíz del repo.
    $startedAt = Get-Date
    $stataProcess = Start-Process `
        -FilePath $StataExecutable `
        -ArgumentList @("-e", "do", "`"$doPath`"") `
        -WorkingDirectory $batchLogs `
        -WindowStyle Hidden `
        -PassThru

    # Esperar hasta treinta minutos por la confirmación escrita por el .do.
    $deadline = $startedAt.AddMinutes(30)
    $completed = $false

    # Iterar sobre los elementos del conjunto
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 1
        $stataProcess.Refresh()

        # Aceptar el cierre únicamente cuando el log fue actualizado durante
        # esta ejecución y contiene la frase final prevista.
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

    # Dar tiempo a Stata para cerrar normalmente después de escribir el marcador.
    if ($completed -and -not $stataProcess.HasExited) {
        [void]$stataProcess.WaitForExit(10000)
        $stataProcess.Refresh()
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

    # Confirmar que la etapa 03 no modificó ningún output de las secciones 1 a 8.
    if ($StageNumber -eq "03") {
        $protectedOutputAfter = Get-ProtectedOutputSnapshot `
            -OutputRoot $econometricsOutput
        $protectedChanges = Compare-Object `
            -ReferenceObject $protectedOutputBefore `
            -DifferenceObject $protectedOutputAfter `
            -Property Path, Hash

        if ($protectedChanges) {
            throw (
                "La etapa 03 modificó outputs protegidos de las secciones 1 a 8."
            )
        }

        Write-Host "Outputs de las secciones 1 a 8 preservados sin cambios."
    }

    # Informar que la etapa y sus verificaciones terminaron correctamente.
    Write-Host "Etapa $StageNumber completada correctamente."
}

# Construir el orden de ejecución solicitado por el usuario.
if ($Stage -eq "all") {
    $stagesToRun = @("01", "02", "03")
}
else {
    $stagesToRun = @($Stage)
}

# Ejecutar las etapas seleccionadas respetando el orden metodológico.
foreach ($stageNumber in $stagesToRun) {
    Invoke-StataStage -StageNumber $stageNumber
}

# Ejecutar la siguiente instrucción del bloque
Write-Host "Logs batch guardados en: $batchLogs"

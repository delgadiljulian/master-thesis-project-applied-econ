[CmdletBinding()]
param(
    [ValidateSet(
        "01", "02", "03", "04", "05", "06", "07", "08",
        "core", "extensions", "formal", "all"
    )]
    [string]$Stage = "core",

    # Ejecutar la siguiente instrucción del bloque
    [string]$StataExecutable = "C:\Program Files\Stata17\StataMP-64.exe"
)

# Ejecutar la siguiente instrucción del bloque
$ErrorActionPreference = "Stop"

# Localizar la raíz a partir de la carpeta donde está guardado este ejecutor.
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDirectory "..\..\..\..")).Path

# Centralizar los registros automáticos de Stata en outputs. Esta carpeta
# contiene únicamente los logs externos del modo batch; los logs analíticos
# creados dentro de cada .do permanecen un nivel más arriba.
$outputLogs = Join-Path $projectRoot "outputs\econometrics\stata-peer-2\01_twfe_main\logs"
$batchLogs = Join-Path $outputLogs "batch"
New-Item -ItemType Directory -Path $batchLogs -Force | Out-Null
$econometricsOutput = Join-Path $projectRoot "outputs\econometrics\stata-peer-2\01_twfe_main"

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
        DoFile = "02_twfe_extractive_export_structure.do"
        InternalLog = "08_extractive_export_structure\02_twfe_extractive_export_structure_full.log"
        CompletionMarker = "Archivo 02 finalizado: secciones 5 y 6 completadas sin errores."
    }
    "03" = [pscustomobject]@{
        DoFile = "03_twfe_capabilities_stability.do"
        InternalLog = "09_capabilities_stability\03_twfe_capabilities_stability.log"
        CompletionMarker = "Archivo 03 finalizado: secciones 7 y 8 completadas sin errores."
    }
    "04" = [pscustomobject]@{
        DoFile = "04_twfe_full.do"
        InternalLog = "logs\04_twfe_full.log"
        CompletionMarker = "Archivo 04 finalizado sin errores."
    }
    "05" = [pscustomobject]@{
        DoFile = "05_twfe_model_comparison.do"
        InternalLog = "12_model_comparison\05_twfe_model_comparison.log"
        CompletionMarker = "Archivo 05 finalizado: secciones 13 y 14 sin errores."
    }
    "06" = [pscustomobject]@{
        DoFile = "06_twfe_oil_gas_models.do"
        InternalLog = "10_oil_gas_models\06_twfe_oil_gas_models.log"
        CompletionMarker = "Archivo 06 finalizado: secciones 15 a 18 sin errores."
    }
    "07" = [pscustomobject]@{
        DoFile = "07_twfe_mining_models.do"
        InternalLog = "11_mining_models\07_twfe_mining_models.log"
        CompletionMarker = "Archivo 07 finalizado: secciones 15M a 18M sin errores."
    }
    "08" = [pscustomobject]@{
        DoFile = "08_resource_disaggregated_integrated.do"
        InternalLog = "07_resource_disaggregation\logs\08_resource_disaggregated_integrated.log"
        CompletionMarker = "Archivo 08 finalizado: secciones 19 a 24 completadas sin errores."
    }
}

# Calcular las huellas de los outputs agregados que la etapa 08 solo puede leer.
function Get-ProtectedOutputSnapshot {
    param(
        [Parameter(Mandatory)]
        [string]$OutputRoot
    )

    # Delimitar las carpetas de resultados agregados que deben preservarse.
    $protectedFolders = @(
        "00_design",
        "01_sample",
        "02_diagnostics",
        "03_eci",
        "04_divx",
        "05_stability",
        "06_final",
        "08_extractive_export_structure",
        "09_capabilities_stability",
        "10_oil_gas_models",
        "11_mining_models",
        "12_model_comparison"
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

    # Tomar una fotografía de los resultados agregados antes de la etapa 08.
    $protectedOutputBefore = $null
    if ($StageNumber -eq "08") {
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

    # Confirmar que la etapa 08 no modificó ningún resultado agregado.
    if ($StageNumber -eq "08") {
        $protectedOutputAfter = Get-ProtectedOutputSnapshot `
            -OutputRoot $econometricsOutput
        $protectedChanges = Compare-Object `
            -ReferenceObject $protectedOutputBefore `
            -DifferenceObject $protectedOutputAfter `
            -Property Path, Hash

        if ($protectedChanges) {
            throw (
                "La etapa 08 modificó resultados agregados protegidos."
            )
        }

        Write-Host "Resultados agregados preservados sin cambios."
    }

    # Informar que la etapa y sus verificaciones terminaron correctamente.
    Write-Host "Etapa $StageNumber completada correctamente."
}

# Construir el orden de ejecución solicitado por el usuario.
$stageGroups = @{
    "core" = @("01", "02", "03", "04", "05")
    "extensions" = @("06", "07")
    "formal" = @("08")
    "all" = @("01", "02", "03", "04", "05", "06", "07", "08")
}

if ($stageGroups.ContainsKey($Stage)) {
    $stagesToRun = $stageGroups[$Stage]
}
else {
    $stagesToRun = @($Stage)
}

Write-Host (
    "Grupo solicitado: {0}. Etapas: {1}." -f `
        $Stage, ($stagesToRun -join ", ")
)

# Ejecutar las etapas seleccionadas respetando el orden metodológico.
foreach ($stageNumber in $stagesToRun) {
    Invoke-StataStage -StageNumber $stageNumber
}

# Ejecutar la siguiente instrucción del bloque
Write-Host "Logs batch guardados en: $batchLogs"

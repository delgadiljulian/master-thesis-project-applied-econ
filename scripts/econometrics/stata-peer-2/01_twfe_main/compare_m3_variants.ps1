[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDirectory "..\..\..\..")).Path
$outputRoot = Join-Path $projectRoot `
    "outputs\econometrics\stata-peer-2\01_twfe_main"
$comparisonRoot = Join-Path $outputRoot "13_m3_component_comparison"
New-Item -ItemType Directory -Path $comparisonRoot -Force | Out-Null

function Get-TermMetadata {
    param([Parameter(Mandatory)][string]$Term)

    $metadata = switch ($Term) {
        "rents" { @("RENTS", "RENTS agregado", "Rentas", "resource") }
        "c.rents#c.inst" {
            @("RENTS_X_INST", "RENTS x INST", "Institucional", "resource")
        }
        "rents_oil_gas" {
            @("RENTS_OIL_GAS", "Rentas de petróleo y gas", "Rentas", "resource")
        }
        "c.rents_oil_gas#c.inst" {
            @("RENTS_OIL_GAS_X_INST", "Petróleo y gas x INST", "Institucional", "resource")
        }
        "rents_mining" {
            @("RENTS_MINING", "Rentas de minería y carbón", "Rentas", "resource")
        }
        "c.rents_mining#c.inst" {
            @("RENTS_MINING_X_INST", "Minería y carbón x INST", "Institucional", "resource")
        }
        "inst" { @("INST", "Calidad institucional", "Institucional", "common") }
        "ln1p_oilpc" { @("LN1P_OILPC", "log(1 + OILPC)", "Abundancia", "common") }
        "ln1p_gaspc" { @("LN1P_GASPC", "log(1 + GASPC)", "Abundancia", "common") }
        "ln1p_coalpc" { @("LN1P_COALPC", "log(1 + COALPC)", "Abundancia", "common") }
        "hhi" { @("HHI", "HHI", "Estructura exportadora", "common") }
        "pexp" { @("PEXP", "PEXP", "Estructura exportadora", "common") }
        "fexp" { @("FEXP", "FEXP", "Estructura exportadora", "common") }
        "vol" { @("VOL", "VOL", "Macroeconomía", "common") }
        "rer" { @("RER", "RER", "Macroeconomía", "common") }
        "humcap" { @("HUMCAP", "HUMCAP", "Capacidades productivas", "common") }
        "innov" { @("INNOV", "INNOV", "Capacidades productivas", "common") }
        "net" { @("NET", "NET", "Capacidades productivas", "common") }
        "log_gdppc" { @("LOG_GDPPC", "log(GDPPC)", "Controles económicos", "common") }
        "govcons" { @("GOVCONS", "GOVCONS", "Controles económicos", "common") }
        "fin" { @("FIN", "FIN", "Controles económicos", "common") }
        default { throw "Término no reconocido en comparación M3: $Term" }
    }

    return [pscustomobject]@{
        CanonicalTerm = $metadata[0]
        Label = $metadata[1]
        Channel = $metadata[2]
        Role = $metadata[3]
    }
}

function Get-Significance {
    param([double]$PValue)
    if ($PValue -lt 0.01) { return "***" }
    if ($PValue -lt 0.05) { return "**" }
    if ($PValue -lt 0.10) { return "*" }
    return ""
}

function Read-CoefficientFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Model,
        [string]$Outcome
    )

    foreach ($row in Import-Csv -LiteralPath $Path) {
        $metadata = Get-TermMetadata -Term $row.term
        $currentOutcome = if ($Outcome) { $Outcome } else { $row.outcome }
        $pValue = [double]$row.p_value
        [pscustomobject]@{
            model = $Model
            outcome = $currentOutcome
            order = [int]$row.order
            term = $row.term
            canonical_term = $metadata.CanonicalTerm
            variable_label = $metadata.Label
            channel = $metadata.Channel
            term_role = $metadata.Role
            coefficient = [double]$row.coefficient
            standard_error = [double]$row.standard_error
            p_value = $pValue
            ci_lower = [double]$row.ci_lower
            ci_upper = [double]$row.ci_upper
            significance = Get-Significance -PValue $pValue
        }
    }
}

$coefficientSources = @(
    @{ Path = "03_eci\eci_twfe_coefficients.csv"; Model = "M3_AGG"; Outcome = "ECI" },
    @{ Path = "04_divx\divx_twfe_coefficients.csv"; Model = "M3_AGG"; Outcome = "DIVX" },
    @{ Path = "10_oil_gas_models\03_m3_full\og_m3_coefficients.csv"; Model = "M3_OG"; Outcome = "" },
    @{ Path = "11_mining_models\03_m3_full\mining_m3_coefficients.csv"; Model = "M3_MIN"; Outcome = "" },
    @{ Path = "07_resource_disaggregation\02_eci\eci_disaggregated_coefficients.csv"; Model = "M3_SIM"; Outcome = "ECI" },
    @{ Path = "07_resource_disaggregation\03_divx\divx_disaggregated_coefficients.csv"; Model = "M3_SIM"; Outcome = "DIVX" }
)

$coefficients = foreach ($source in $coefficientSources) {
    Read-CoefficientFile `
        -Path (Join-Path $outputRoot $source.Path) `
        -Model $source.Model `
        -Outcome $source.Outcome
}

$modelOrder = @{ M3_AGG = 1; M3_OG = 2; M3_MIN = 3; M3_SIM = 4 }
$outcomeOrder = @{ ECI = 1; DIVX = 2 }
$coefficients = @($coefficients | Sort-Object `
    @{ Expression = { $outcomeOrder[$_.outcome] } }, `
    @{ Expression = { $modelOrder[$_.model] } }, order)

$coefficients | Export-Csv -LiteralPath (
    Join-Path $comparisonRoot "m3_coefficients_long.csv"
) -NoTypeInformation -Encoding utf8

$commonOrder = @(
    "INST", "LN1P_OILPC", "LN1P_GASPC", "LN1P_COALPC", "HHI",
    "PEXP", "FEXP", "VOL", "RER", "HUMCAP", "INNOV", "NET",
    "LOG_GDPPC", "GOVCONS", "FIN"
)

$commonRows = foreach ($outcome in @("ECI", "DIVX")) {
    foreach ($canonicalTerm in $commonOrder) {
        $matches = @($coefficients | Where-Object {
            $_.outcome -eq $outcome -and
            $_.canonical_term -eq $canonicalTerm -and
            $_.term_role -eq "common"
        })
        if ($matches.Count -eq 0) { continue }
        if ($matches.Count -ne 4) {
            throw "El término común $canonicalTerm/$outcome no aparece en los cuatro modelos."
        }

        $row = [ordered]@{
            outcome = $outcome
            order = [array]::IndexOf($commonOrder, $canonicalTerm) + 1
            canonical_term = $canonicalTerm
            variable_label = $matches[0].variable_label
            channel = $matches[0].channel
        }
        foreach ($model in @("M3_AGG", "M3_OG", "M3_MIN", "M3_SIM")) {
            $match = $matches | Where-Object model -eq $model
            $prefix = $model.ToLower()
            $row["${prefix}_coefficient"] = $match.coefficient
            $row["${prefix}_standard_error"] = $match.standard_error
            $row["${prefix}_p_value"] = $match.p_value
            $row["${prefix}_significance"] = $match.significance
        }
        [pscustomobject]$row
    }
}

$commonRows | Export-Csv -LiteralPath (
    Join-Path $comparisonRoot "m3_common_channels_comparison.csv"
) -NoTypeInformation -Encoding utf8

$resourceRows = @($coefficients | Where-Object term_role -eq "resource")
$resourceRows | Export-Csv -LiteralPath (
    Join-Path $comparisonRoot "m3_resource_terms_comparison.csv"
) -NoTypeInformation -Encoding utf8

function Read-ModelSummary {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Model,
        [string]$Outcome
    )
    foreach ($row in Import-Csv -LiteralPath $Path) {
        $currentOutcome = if ($Outcome) { $Outcome } elseif ($row.outcome) {
            $row.outcome
        } else { $row.dependent_variable.ToUpper() }
        $years = if ($row.effective_years) { $row.effective_years } else { $row.years }
        [pscustomobject]@{
            model = $Model
            outcome = $currentOutcome
            observations = [int]$row.observations
            countries = [int]$row.countries
            clusters = [int]$row.clusters
            effective_years = [int]$years
            r2_within = [double]$row.r2_within
            r2_between = [double]$row.r2_between
            r2_overall = [double]$row.r2_overall
            model_p_value = [double]$row.model_p_value
        }
    }
}

$summarySources = @(
    @{ Path = "03_eci\eci_twfe_model_summary.csv"; Model = "M3_AGG"; Outcome = "ECI" },
    @{ Path = "04_divx\divx_twfe_model_summary.csv"; Model = "M3_AGG"; Outcome = "DIVX" },
    @{ Path = "10_oil_gas_models\03_m3_full\og_m3_model_summary.csv"; Model = "M3_OG"; Outcome = "" },
    @{ Path = "11_mining_models\03_m3_full\mining_m3_model_summary.csv"; Model = "M3_MIN"; Outcome = "" },
    @{ Path = "07_resource_disaggregation\02_eci\eci_disaggregated_model_summary.csv"; Model = "M3_SIM"; Outcome = "ECI" },
    @{ Path = "07_resource_disaggregation\03_divx\divx_disaggregated_model_summary.csv"; Model = "M3_SIM"; Outcome = "DIVX" }
)

$summaries = foreach ($source in $summarySources) {
    Read-ModelSummary `
        -Path (Join-Path $outputRoot $source.Path) `
        -Model $source.Model `
        -Outcome $source.Outcome
}
$summaries = @($summaries | Sort-Object `
    @{ Expression = { $outcomeOrder[$_.outcome] } }, `
    @{ Expression = { $modelOrder[$_.model] } })
$summaries | Export-Csv -LiteralPath (
    Join-Path $comparisonRoot "m3_model_summary_comparison.csv"
) -NoTypeInformation -Encoding utf8

function Read-JointTests {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Model,
        [string]$Outcome,
        [switch]$Component
    )
    foreach ($row in Import-Csv -LiteralPath $Path) {
        $currentOutcome = if ($Outcome) { $Outcome } else { $row.outcome }
        $testName = if ($Component) { $row.channel } else { $row.test }
        [pscustomobject]@{
            model = $Model
            outcome = $currentOutcome
            order = [int]$row.order
            test = $testName
            null_hypothesis = $row.null_hypothesis
            f_statistic = [double]$row.f_statistic
            df1 = [double]$row.df1
            df2 = [double]$row.df2
            p_value = [double]$row.p_value
            significance = Get-Significance -PValue ([double]$row.p_value)
        }
    }
}

$jointTests = @(
    Read-JointTests -Path (Join-Path $outputRoot "03_eci\eci_twfe_joint_tests.csv") -Model "M3_AGG" -Outcome "ECI"
    Read-JointTests -Path (Join-Path $outputRoot "04_divx\divx_twfe_joint_tests.csv") -Model "M3_AGG" -Outcome "DIVX"
    Read-JointTests -Path (Join-Path $outputRoot "10_oil_gas_models\03_m3_full\og_m3_joint_tests.csv") -Model "M3_OG" -Component
    Read-JointTests -Path (Join-Path $outputRoot "11_mining_models\03_m3_full\mining_m3_joint_tests.csv") -Model "M3_MIN" -Component
    Read-JointTests -Path (Join-Path $outputRoot "07_resource_disaggregation\02_eci\eci_disaggregated_tests.csv") -Model "M3_SIM" -Outcome "ECI"
    Read-JointTests -Path (Join-Path $outputRoot "07_resource_disaggregation\03_divx\divx_disaggregated_tests.csv") -Model "M3_SIM" -Outcome "DIVX"
)
$jointTests | Export-Csv -LiteralPath (
    Join-Path $comparisonRoot "m3_joint_tests_comparison.csv"
) -NoTypeInformation -Encoding utf8

$validation = @(
    [pscustomobject]@{ check = "Coefficient rows"; expected = 136; observed = $coefficients.Count; passed = ($coefficients.Count -eq 136) },
    [pscustomobject]@{ check = "Common-channel rows"; expected = 29; observed = $commonRows.Count; passed = ($commonRows.Count -eq 29) },
    [pscustomobject]@{ check = "Resource-term rows"; expected = 20; observed = $resourceRows.Count; passed = ($resourceRows.Count -eq 20) },
    [pscustomobject]@{ check = "Model-summary rows"; expected = 8; observed = $summaries.Count; passed = ($summaries.Count -eq 8) },
    [pscustomobject]@{ check = "Joint-test rows"; expected = 54; observed = $jointTests.Count; passed = ($jointTests.Count -eq 54) },
    [pscustomobject]@{ check = "Models outside 1,044 observations"; expected = 0; observed = (@($summaries | Where-Object observations -ne 1044).Count); passed = (@($summaries | Where-Object observations -ne 1044).Count -eq 0) },
    [pscustomobject]@{ check = "Models outside 49 countries"; expected = 0; observed = (@($summaries | Where-Object countries -ne 49).Count); passed = (@($summaries | Where-Object countries -ne 49).Count -eq 0) },
    [pscustomobject]@{ check = "Missing coefficient fields"; expected = 0; observed = (@($coefficients | Where-Object { $null -eq $_.coefficient -or $null -eq $_.standard_error -or $null -eq $_.p_value }).Count); passed = (@($coefficients | Where-Object { $null -eq $_.coefficient -or $null -eq $_.standard_error -or $null -eq $_.p_value }).Count -eq 0) }
)
if (@($validation | Where-Object passed -ne $true).Count -ne 0) {
    throw "La validación de la comparación M3 no fue superada."
}
$validation | Export-Csv -LiteralPath (
    Join-Path $comparisonRoot "comparison_validation.csv"
) -NoTypeInformation -Encoding utf8

$manifest = @(
    [pscustomobject]@{ order = 1; file = "m3_coefficients_long.csv"; purpose = "Coeficientes e incertidumbre de los cuatro M3." },
    [pscustomobject]@{ order = 2; file = "m3_common_channels_comparison.csv"; purpose = "Comparación de los canales comunes." },
    [pscustomobject]@{ order = 3; file = "m3_resource_terms_comparison.csv"; purpose = "Comparación de términos directos e interacciones de rentas." },
    [pscustomobject]@{ order = 4; file = "m3_model_summary_comparison.csv"; purpose = "Muestra y ajuste de los cuatro M3." },
    [pscustomobject]@{ order = 5; file = "m3_joint_tests_comparison.csv"; purpose = "Pruebas conjuntas por modelo y resultado." },
    [pscustomobject]@{ order = 6; file = "comparison_validation.csv"; purpose = "Controles automáticos de completitud y comparabilidad." },
    [pscustomobject]@{ order = 7; file = "M3_COMPONENT_COMPARISON.md"; purpose = "Lectura econométrica y límites interpretativos." },
    [pscustomobject]@{ order = 8; file = "results_manifest.csv"; purpose = "Inventario reproducible del bloque 4." }
)
$manifest | Export-Csv -LiteralPath (
    Join-Path $comparisonRoot "results_manifest.csv"
) -NoTypeInformation -Encoding utf8

Write-Host "Comparación M3 generada en: $comparisonRoot"

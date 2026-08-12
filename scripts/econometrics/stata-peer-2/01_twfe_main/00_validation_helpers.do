// *****************************************************************************
// Universidad: Universidad de Buenos Aires
// Facultad: Facultad de Ciencias Económicas
// Programa: Maestría en Economía Aplicada
//
// Tipo de trabajo: Trabajo Final de Maestría (TFM)
// Título: Rentas extractivas y transformación estructural externa en economías
//         dependientes de recursos naturales no renovables del subsuelo (1996--2021)
// Autor: Julián Alberto Delgadillo Marín
// Director: Martín Grandes
//
// Archivo: 00_validation_helpers.do (Versión Codex - Peer-2)
// Propósito: Centralizar las rutinas auxiliares de validación y control de calidad.
// Ubicación: scripts/econometrics/stata-peer-2/01_twfe_main/
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************

// =============================================================================
// PROGRAMA AUXILIAR: peer2_assert_estimation_contract
// =============================================================================
// Este programa actúa como una "red de seguridad" pre-flight tras cada regresión.
// Verifica automáticamente que el modelo recién estimado cumpla con tres criterios:
//   1. Que la muestra activa (e(sample)) coincida exactamente con la variable de filtro.
//   2. Que el número total de observaciones (e(N)) coincida con el valor preestablecido.
//   3. Que la cantidad de países (e(N_g)) y clusters coincida con la grilla analítica congelada.
// =============================================================================

capture program drop peer2_assert_estimation_contract
program define peer2_assert_estimation_contract
    version 17.0

    // Definición de parámetros requeridos y opcionales
    syntax, SAMPLE(varname) OBSERVATIONS(integer) COUNTRIES(integer) ///
        [CLUSTERS(integer)]

    // 1. Validar que ninguna observación se haya omitido involuntariamente
    assert e(sample) == `sample'

    // 2. Confirmar que el número de casos (N) sea exactamente el especificado
    assert e(N) == `observations'

    // 3. Confirmar la cantidad de unidades de panel (países)
    assert e(N_g) == `countries'

    // 4. Si se especificó el número de clusters, verificar coincidencia
    if "`clusters'" != "" {
        assert e(N_clust) == `clusters'
    }
    
    display as text "  -> [OK] Contrato de estimación verificado: N=`observations', Países=`countries'."
end

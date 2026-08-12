// *****************************************************************************
// Utilidades de validación compartidas de stata-peer-2
// Propósito: centralizar controles econométricos esenciales sin alterar modelos.
// *****************************************************************************

capture program drop peer2_assert_estimation_contract
program define peer2_assert_estimation_contract
    version 17.0

    * Confirma que la estimación recién ejecutada utiliza exactamente la muestra
    * preespecificada y conserva la estructura transversal esperada.
    syntax, SAMPLE(varname) OBSERVATIONS(integer) COUNTRIES(integer) ///
        [CLUSTERS(integer)]

    assert e(sample) == `sample'
    assert e(N) == `observations'
    assert e(N_g) == `countries'

    if "`clusters'" != "" {
        assert e(N_clust) == `clusters'
    }
end

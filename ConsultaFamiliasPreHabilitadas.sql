-- ============================================================================
-- OBJETIVO: Contar famílias pré-habilitadas no mês (RF_FOLHA),
--           total Brasil e por UF (CO_MUNIC_IBGE_2_FAM).
-- BASE: escolha a competência ODS para buscar a UF da família.
-- ============================================================================

DATABASE P_CADASTRO_ODS_202509;  -- ajuste a competência do ODS se desejar

WITH pre_hab AS (  -- famílias marcadas como pré-habilitadas no mês alvo
    SELECT DISTINCT CO_FAMILIAR
    FROM P_DEBEN_ACC.VW_PRE_HABILITACAO_PBF
    WHERE RF_FOLHA = 202510               -- ajuste o mês de pré-habilitação
),
familias_pre AS ( -- 1 linha por família pré-habilitada com sua UF
    SELECT DISTINCT
        F.CO_FAMILIAR_FAM,
        CASE CAST(F.CO_MUNIC_IBGE_2_FAM AS INTEGER)
             WHEN 11 THEN 'RO'  WHEN 12 THEN 'AC'  WHEN 13 THEN 'AM'  WHEN 14 THEN 'RR'
             WHEN 15 THEN 'PA'  WHEN 16 THEN 'AP'  WHEN 17 THEN 'TO'  WHEN 21 THEN 'MA'
             WHEN 22 THEN 'PI'  WHEN 23 THEN 'CE'  WHEN 24 THEN 'RN'  WHEN 25 THEN 'PB'
             WHEN 26 THEN 'PE'  WHEN 27 THEN 'AL'  WHEN 28 THEN 'SE'  WHEN 29 THEN 'BA'
             WHEN 31 THEN 'MG'  WHEN 32 THEN 'ES'  WHEN 33 THEN 'RJ'  WHEN 35 THEN 'SP'
             WHEN 41 THEN 'PR'  WHEN 42 THEN 'SC'  WHEN 43 THEN 'RS'
             WHEN 50 THEN 'MS'  WHEN 51 THEN 'MT'  WHEN 52 THEN 'GO'  WHEN 53 THEN 'DF'
             ELSE 'NA'
        END AS UF
    FROM P_CADASTRO_ODS_202509.TB_FAMILIA_01 F
    JOIN pre_hab PH
      ON PH.CO_FAMILIAR = F.CO_FAMILIAR_FAM
)

SELECT
    CASE WHEN GROUPING(UF)=1 THEN 'TOTAL BRASIL' ELSE UF END AS UF,
    COUNT(*) AS Qtd_Familias_PreHabilitadas
FROM familias_pre
GROUP BY ROLLUP (UF)
ORDER BY 1;

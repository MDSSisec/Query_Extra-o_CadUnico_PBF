-- ============================================================================
-- OBJETIVO
--   Contabilizar o total de pessoas, no Brasil e por UF,
--   pertencentes a famílias PRÉ-HABILITADAS no Programa Bolsa Família,
--   considerando a folha do mês de referência (RF_FOLHA = 202510).
--
-- REGRAS ADOTADAS
--   • Considerar apenas famílias com cadastro válido no CadÚnico
--   • Considerar apenas pessoas com situação cadastral ativa
--   • Utilizar a base ODS do mesmo mês da RF_FOLHA analisada
--   • Apresentar o total por UF e o total Brasil
-- ============================================================================

-- ============================================================================
-- DEFINIÇÃO DO ODS
--   Base ODS utilizada como referência para os dados do CadÚnico.
--   Deve ser igual ao mês da RF_FOLHA analisada.
-- ============================================================================
DATABASE P_CADASTRO_ODS_202510;

WITH universo_pessoa AS (
    -- ========================================================================
    -- UNIVERSO_PESSOA
    --   Define o universo de pessoas válidas no CadÚnico.
    --   Considera apenas pessoas ativas, pertencentes a famílias
    --   com situação cadastral regular.
    -- ========================================================================
    SELECT DISTINCT
        P.CO_CHV_NATURAL_PESSOA,     -- Identificador único da pessoa
        P.CO_FAMILIAR_FAM,           -- Identificador da família
        CAST(F.CO_MUNIC_IBGE_2_FAM AS INTEGER) AS UF_CD  -- Código da UF (IBGE)
    FROM TB_PESSOA_04 P
    JOIN TB_FAMILIA_01 F
      ON F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
    WHERE
        -- Exclui famílias com situação cadastral inválida
        F.CO_EST_CADASTRAL_FAM NOT IN (1, 2, 4)
        -- Considera apenas pessoas com situação cadastral ativa
        AND P.CO_EST_CADASTRAL_MEMB = 3
),
pre_hab AS (
    -- ========================================================================
    -- PRE_HAB
    --   Identifica as famílias marcadas como PRÉ-HABILITADAS
    --   no Programa Bolsa Família no mês de referência.
    -- ========================================================================
    SELECT DISTINCT
        CO_FAMILIAR
    FROM P_DEBEN_ACC.VW_PRE_HABILITACAO_PBF
    WHERE
        -- Mês/ano da folha analisada (deve ser igual ao ODS utilizado)
        RF_FOLHA = 202510
),
pessoas_pre AS (
    -- ========================================================================
    -- PESSOAS_PRE
    --   Gera uma linha por pessoa pertencente a famílias pré-habilitadas.
    --   A conversão do código IBGE para sigla da UF é feita nesta etapa
    --   para facilitar a agregação final.
    -- ========================================================================
    SELECT
        CASE UF_CD
             WHEN 11 THEN 'RO'  WHEN 12 THEN 'AC'  WHEN 13 THEN 'AM'  WHEN 14 THEN 'RR'
             WHEN 15 THEN 'PA'  WHEN 16 THEN 'AP'  WHEN 17 THEN 'TO'  WHEN 21 THEN 'MA'
             WHEN 22 THEN 'PI'  WHEN 23 THEN 'CE'  WHEN 24 THEN 'RN'  WHEN 25 THEN 'PB'
             WHEN 26 THEN 'PE'  WHEN 27 THEN 'AL'  WHEN 28 THEN 'SE'  WHEN 29 THEN 'BA'
             WHEN 31 THEN 'MG'  WHEN 32 THEN 'ES'  WHEN 33 THEN 'RJ'  WHEN 35 THEN 'SP'
             WHEN 41 THEN 'PR'  WHEN 42 THEN 'SC'  WHEN 43 THEN 'RS'
             WHEN 50 THEN 'MS'  WHEN 51 THEN 'MT'  WHEN 52 THEN 'GO'  WHEN 53 THEN 'DF'
             ELSE 'NA'
        END AS UF
    FROM universo_pessoa U
    JOIN pre_hab PH
      ON PH.CO_FAMILIAR = U.CO_FAMILIAR_FAM
)

-- ============================================================================
-- RESULTADO FINAL
--   Retorna a quantidade de pessoas pré-habilitadas:
--   • Por Unidade da Federação (UF)
--   • Total Brasil
-- ============================================================================
SELECT
    CASE
        WHEN GROUPING(UF) = 1 THEN 'TOTAL BRASIL'
        ELSE UF
    END AS UF,
    COUNT(*) AS Qtd_Pessoas_PreHabilitadas
FROM pessoas_pre
GROUP BY ROLLUP (UF)
ORDER BY 1;


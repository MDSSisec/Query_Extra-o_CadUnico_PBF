-- ============================================================================
-- OBJETIVO
--   Contar, dentro do universo de famílias do CadÚnico (base 202509),
--   quantas aparecem na folha do Bolsa Família do mês seguinte (202510/202511).
--
-- REGRAS ADOTADAS
--   • Considerar apenas famílias com cadastro ativo no CadÚnico
--   • Considerar apenas membros com situação cadastral válida
--   • Comparar o universo do CadÚnico com a folha do Bolsa Família
--     do mês subsequente ao período de referência
-- ============================================================================

-- ============================================================================
-- DEFINIÇÃO DO ODS
--   Base ODS utilizada como referência para os dados do CadÚnico.
--   Ajustar conforme o mês/ano desejado (ex.: 202601).
-- ============================================================================
DATABASE P_CADASTRO_ODS_202510;

WITH universo_familia AS (
    -- ========================================================================
    -- UNIVERSO_FAMILIA
    --   Identifica o universo de famílias válidas no CadÚnico.
    --   São consideradas apenas famílias ativas e com pelo menos
    --   um membro em situação cadastral válida.
    -- ========================================================================
    SELECT DISTINCT
        F.CO_FAMILIAR_FAM
    FROM TB_FAMILIA_01 F
    JOIN TB_PESSOA_04 P
      ON P.CO_FAMILIAR_FAM = F.CO_FAMILIAR_FAM
    WHERE
        -- Exclui famílias com situação cadastral inválida
        F.CO_EST_CADASTRAL_FAM NOT IN (1, 2, 4)
        -- Considera apenas membros com cadastro válido
        AND P.CO_EST_CADASTRAL_MEMB = 3
),
folha_any AS (
    -- ========================================================================
    -- FOLHA_ANY
    --   Lista as famílias presentes na folha de pagamento do
    --   Programa Bolsa Família.
    --   Utiliza a folha referente ao mês seguinte ao período base.
    -- ========================================================================
    SELECT DISTINCT
        FOL.CO_FAMILIAR
    FROM P_DEBEN_ACC.VW_FOLHA_PAGAMENTO FOL
    WHERE
        -- Mês/ano da folha de pagamento (ex.: base 202510 → folha 202511)
        FOL.RF_FOLHA = 202511
)

-- ============================================================================
-- RESULTADO FINAL
--   1) Total de famílias inscritas no CadÚnico (universo válido)
--   2) Total de famílias do CadÚnico que aparecem na folha do Bolsa Família
-- ============================================================================
SELECT
    -- Total de famílias válidas no CadÚnico
    (SELECT COUNT(*)
       FROM universo_familia) AS Familias_inscritas_CadUnico,

    -- Total de famílias do CadÚnico presentes na folha do Bolsa Família
    (SELECT COUNT(DISTINCT U.CO_FAMILIAR_FAM)
       FROM universo_familia U
       JOIN folha_any A
         ON A.CO_FAMILIAR = U.CO_FAMILIAR_FAM
    ) AS Familias_inscritas_BolsaFamilia;


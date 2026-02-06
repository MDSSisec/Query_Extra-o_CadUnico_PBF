-- Base CadÚnico (set/2025)
DATABASE P_CADASTRO_ODS_202510;

-- Parâmetro da folha: mês seguinte (out/2025)
-- Se preferir, troque direto no WHERE abaixo.
-- .SET COMP_FOLHA 202510;

WITH universo_pessoa AS (
    -- Universo que representa as 94.5M (para 202509) / 94.8M (para 202510)
    SELECT DISTINCT
        P.CO_CHV_NATURAL_PESSOA,
        P.CO_FAMILIAR_FAM
    FROM TB_PESSOA_04 P
    JOIN TB_FAMILIA_01 F
      ON F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
    WHERE F.CO_EST_CADASTRAL_FAM NOT IN (1,2,4)   -- família = 3
      AND P.CO_EST_CADASTRAL_MEMB = 3             -- pessoa = 3
),

-- Famílias presentes na folha do mês seguinte
folha_any AS (
    SELECT DISTINCT FOL.CO_FAMILIAR
    FROM P_DEBEN_ACC.VW_FOLHA_PAGAMENTO FOL
    WHERE FOL.RF_FOLHA = 202511                    -- mês seguinte da base
)

SELECT
    (SELECT COUNT(*) FROM universo_pessoa) AS Pessoas_inscritos_CadUnico,
    (SELECT COUNT(DISTINCT U.CO_CHV_NATURAL_PESSOA)
       FROM universo_pessoa U
       JOIN folha_any A ON A.CO_FAMILIAR = U.CO_FAMILIAR_FAM) AS Pessoas_inscritas_BolsaFamilia;

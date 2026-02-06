-- ============================================================================
-- OBJETIVO: Pessoas do CadÚnico (fam=3, pessoa=3) por UF
--           cujas famílias aparecem na folha do mês seguinte (qualquer situação)
-- BASE: ODS 202509  ➜  FOLHA 202510
-- Nível: PESSOA (DISTINCT CO_CHV_NATURAL_PESSOA)
-- ============================================================================

DATABASE P_CADASTRO_ODS_202510;

WITH universo_pessoa AS (
    SELECT DISTINCT
        P.CO_CHV_NATURAL_PESSOA,
        P.CO_FAMILIAR_FAM,
        CAST(F.CO_MUNIC_IBGE_2_FAM AS INTEGER) AS UF_CD
    FROM TB_PESSOA_04 P
    JOIN TB_FAMILIA_01 F
      ON F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
    WHERE F.CO_EST_CADASTRAL_FAM NOT IN (1,2,4)   -- família cadastrada (=3)
      AND P.CO_EST_CADASTRAL_MEMB = 3             -- pessoa cadastrada (=3)
),
folha_any AS (
    SELECT DISTINCT
        FOL.CO_FAMILIAR
    FROM P_DEBEN_ACC.VW_FOLHA_PAGAMENTO FOL
    WHERE FOL.RF_FOLHA = 202511                   -- mês seguinte da base
)

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
    END AS UF,
    COUNT(DISTINCT U.CO_CHV_NATURAL_PESSOA) AS Qtd_Pessoas_inscritas_BolsaFamilia_PorUF
FROM universo_pessoa U
JOIN folha_any A
  ON A.CO_FAMILIAR = U.CO_FAMILIAR_FAM
GROUP BY 1
ORDER BY 1;

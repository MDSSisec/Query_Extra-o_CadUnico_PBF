-- Pessoas "cadastradas" (membro=3) em famílias "cadastradas" (fam=3),
-- agregadas pela UF (CO_MUNIC_IBGE_2_FAM).

DATABASE P_CADASTRO_ODS_202512;

WITH universo AS (
    -- Universo que já bateu o total de 94.800.889
    SELECT DISTINCT
        P.CO_CHV_NATURAL_PESSOA,
        P.CO_FAMILIAR_FAM
    FROM TB_PESSOA_04 P
    JOIN TB_FAMILIA_01 F
      ON F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
    WHERE F.CO_EST_CADASTRAL_FAM NOT IN (1, 2, 4)  -- fam = 3 (CADASTRADO)
      AND P.CO_EST_CADASTRAL_MEMB = 3              -- pessoa = 3 (CADASTRADO)
),
pessoa_uf AS (
    -- Anexamos a UF (2 dígitos) da família
    SELECT
        U.CO_CHV_NATURAL_PESSOA,
        CAST(F.CO_MUNIC_IBGE_2_FAM AS INTEGER) AS UF_CD
    FROM universo U
    JOIN TB_FAMILIA_01 F
      ON F.CO_FAMILIAR_FAM = U.CO_FAMILIAR_FAM
)
SELECT
    -- Sigla de UF a partir do código de 2 dígitos
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
    COUNT(DISTINCT CO_CHV_NATURAL_PESSOA) AS Qtd_Pessoas_inscritas_CadUnico_PorUF
FROM pessoa_uf
GROUP BY 1
ORDER BY 1;

------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------

-- Pessoas "cadastradas" (membro=3) em famílias "cadastradas" (fam != 1,2,4),
-- filtradas por MUNICÍPIO (CODIBGE = UF2 + IBGE5) e contando pessoas distintas.

DATABASE P_CADASTRO_ODS_202512;

WITH params AS (
  SELECT
    '5200258' AS CODIBGE_ALVO   -- <<< informe aqui o CODIBGE (7 dígitos)
),

universo AS (
  SELECT DISTINCT
      P.CO_CHV_NATURAL_PESSOA,
      P.CO_FAMILIAR_FAM
  FROM TB_PESSOA_04 P
  JOIN TB_FAMILIA_01 F
    ON F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
  CROSS JOIN params prm
  WHERE F.CO_EST_CADASTRAL_FAM NOT IN (1, 2, 4)
    AND P.CO_EST_CADASTRAL_MEMB = 3

    -- filtro por CODIBGE (UF2 + IBGE5)
    AND (
      LPAD(TRIM(CAST(F.CO_MUNIC_IBGE_2_FAM AS VARCHAR(2))), 2, '0') ||
      LPAD(TRIM(CAST(F.CO_MUNIC_IBGE_5_FAM AS VARCHAR(5))), 5, '0')
    ) = prm.CODIBGE_ALVO
)

SELECT
  (SELECT CODIBGE_ALVO FROM params) AS CODIBGE,
  COUNT(DISTINCT CO_CHV_NATURAL_PESSOA) AS Qtd_Pessoas_inscritas_CadUnico_Ativo
FROM universo;


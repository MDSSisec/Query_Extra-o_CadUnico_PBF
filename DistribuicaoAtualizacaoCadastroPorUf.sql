/* ============================================================================
   📌 OBJETIVO DO SCRIPT
   Gerar, por UF, a distribuição de pessoas com cadastro ativo no CadÚnico
   conforme o tempo decorrido desde a última atualização do membro
   (DT_ATUAL_MEMB), usando um ANO/MÊS de referência parametrizado.

   🔍 O que o script faz:
     - Define o parâmetro ANOMES_REF e calcula a data base do mês de referência.
     - Seleciona o universo de pessoas cadastradas (família situação = 3,
       pessoa situação = 3) a partir das tabelas TB_FAMILIA_01 e TB_PESSOA_04.
     - Associa cada pessoa à UF, convertendo o código numérico IBGE em sigla.
     - Calcula MESES_DESDE_ATUAL entre DT_ATUAL_MEMB e o mês de referência.
     - Agrupa por UF e contabiliza as pessoas nos buckets:
         • 0 a 6 meses
         • 7 a 12 meses
         • 13 a 18 meses
         • 19 a 24 meses
         • 25 meses ou mais
         • Data de atualização nula (DT_ATUAL_MEMB IS NULL)
     - Retorna, para cada UF, o total de pessoas e a distribuição por faixa.
   ============================================================================ */


DATABASE P_CADASTRO_ODS_202511;   -- ajuste para o ANOMES desejado

/* Parâmetro de referência mensal (YYYYMM) */
WITH params AS (
    SELECT 202511 AS ANOMES_REF            -- << ajuste aqui (nov/2025, por ex.)
),
ref AS (
    /* Constrói a data do 1º dia do mês de referência e seu "ano-mês em meses" */
    SELECT
        CAST(CAST(p.ANOMES_REF * 100 + 01 AS CHAR(8)) AS DATE FORMAT 'YYYYMMDD') AS REF_DT,
        (EXTRACT(YEAR  FROM CAST(CAST(p.ANOMES_REF * 100 + 01 AS CHAR(8)) AS DATE FORMAT 'YYYYMMDD')) * 12
       + EXTRACT(MONTH FROM CAST(CAST(p.ANOMES_REF * 100 + 01 AS CHAR(8)) AS DATE FORMAT 'YYYYMMDD'))) AS REF_YM
    FROM params p
),

/* Universo de pessoas: mesmo critério da sua query oficial de 94,8M */
universo AS (
    SELECT DISTINCT
        P.CO_CHV_NATURAL_PESSOA,
        P.CO_FAMILIAR_FAM,
        P.DT_ATUAL_MEMB
    FROM TB_PESSOA_04 P
    JOIN TB_FAMILIA_01 F
      ON F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
    WHERE F.CO_EST_CADASTRAL_FAM NOT IN (1, 2, 4)   -- família cadastrada (3)
      AND P.CO_EST_CADASTRAL_MEMB = 3               -- pessoa cadastrada (3)
),

/* Adiciona UF e calcula MESES_DESDE_ATUAL (inteiro) */
pessoa_uf_diff AS (
    SELECT
        U.CO_CHV_NATURAL_PESSOA,
        CAST(F.CO_MUNIC_IBGE_2_FAM AS INTEGER) AS UF_CD,
        U.DT_ATUAL_MEMB,
        CASE
          WHEN U.DT_ATUAL_MEMB IS NULL THEN NULL
          ELSE (
            (SELECT REF_YM FROM ref)
            - (EXTRACT(YEAR  FROM U.DT_ATUAL_MEMB) * 12
             + EXTRACT(MONTH FROM U.DT_ATUAL_MEMB))
          )
        END AS MESES_DESDE_ATUAL
    FROM universo U
    JOIN TB_FAMILIA_01 F
      ON F.CO_FAMILIAR_FAM = U.CO_FAMILIAR_FAM
),

/* Mapeia UF numérica -> sigla UF */
pessoa_uf_sigla AS (
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
        CO_CHV_NATURAL_PESSOA,
        DT_ATUAL_MEMB,
        MESES_DESDE_ATUAL
    FROM pessoa_uf_diff
)

SELECT
    UF,

    /* (opcional) total por UF para conferência com a query de universo */
    COUNT(*) AS QT_TOTAL_PESSOAS_UF,

    /* 0 a 5 meses (mais recentes) */
    SUM(CASE 
          WHEN MESES_DESDE_ATUAL BETWEEN 0 AND 6 THEN 1 
          ELSE 0 
        END) AS QT_0_A_6_MESES,

    /* exatamente 6 meses */
--    SUM(CASE 
--          WHEN MESES_DESDE_ATUAL = 6 THEN 1 
--          ELSE 0 
--        END) AS QT_6_MESES,

    /* 7 a 11 meses */
    SUM(CASE 
          WHEN MESES_DESDE_ATUAL BETWEEN 7 AND 12 THEN 1 
          ELSE 0 
        END) AS QT_7_A_12_MESES,

    /* 12 a 17 meses */
    SUM(CASE 
          WHEN MESES_DESDE_ATUAL BETWEEN 13 AND 18 THEN 1 
          ELSE 0 
        END) AS QT_13_A_18_MESES,

    /* 18 a 23 meses */
    SUM(CASE 
          WHEN MESES_DESDE_ATUAL BETWEEN 19 AND 24 THEN 1 
          ELSE 0 
        END) AS QT_19_A_24_MESES,

    /* 24 meses ou mais */
    SUM(CASE 
          WHEN MESES_DESDE_ATUAL >= 25 THEN 1 
          ELSE 0 
        END) AS QT_MAIOR_OU_IGUAL_25_MESES,

    /* DT_ATUAL_MEMB nulos */
    SUM(CASE 
          WHEN MESES_DESDE_ATUAL IS NULL THEN 1 
          ELSE 0 
        END) AS QT_DT_ATUAL_NULO

FROM pessoa_uf_sigla
GROUP BY 1
ORDER BY 1;

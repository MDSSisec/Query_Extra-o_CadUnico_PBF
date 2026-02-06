/* ============================================================================
   OBJETIVO
     Amostra por CODIBGE (UF + Município), com DT_ATUAL_MEMB <= 12 meses,
     devolvendo colunas:
       CPF, NIS, NOME, SEXO, DT_NASC, IDADE, ESCOLARIDADE, UF, MUNICIPIO,
       CODIBGE, REGIAO, BAIRRO, DDD, TELEFONE, CATEGORIA
     Proporções-alvo: 40% CAD, 35% PRE, 25% PBF (completar com CAD se faltar).
   ============================================================================ */

DATABASE P_CADASTRO_ODS_202510; -------------------- rodar primeiro somente 1x vez!!!!!!!!

WITH
params AS (
  SELECT
    43     AS COD_UF,          -- ex.: 31 = MG 	------------------------------------------------ MEXER AQUI
    12401  AS COD_MUN,         -- ex.: Contagem ------------------------------------------------ MEXER AQUI
    202510 AS ANOMES_ODS,      -- ODS base (YYYYMM)
    202511 AS RF_FOLHA,        -- Folha alvo (normalmente ODS+1)
    250    AS N_TOTAL,         -- Tamanho desejado da amostra -- Quantidade de Vagas * 20 SE FOR MENOR QUE 250, USA 250 ------------------------------------------------ MEXER AQUI
    0.40   AS P_CAD,
    0.35   AS P_PRE,
    0.25   AS P_PBF
),
ref AS (
  SELECT
    CAST(CAST(p.ANOMES_ODS*100 + 01 AS CHAR(8)) AS DATE FORMAT 'YYYYMMDD') AS REF_DT,
    (EXTRACT(YEAR  FROM CAST(CAST(p.ANOMES_ODS*100 + 01 AS CHAR(8)) AS DATE FORMAT 'YYYYMMDD')) * 12
   + EXTRACT(MONTH FROM CAST(CAST(p.ANOMES_ODS*100 + 01 AS CHAR(8)) AS DATE FORMAT 'YYYYMMDD'))) AS REF_YM,
    p.*
  FROM params p
),

/* ============================================================
   1) Universo base (fam=3, pess=3) e com DT_ATUAL_MEMB <= 12m
   ============================================================ */
universo AS (
  SELECT
      /* Identificação */
      CAST(DOC.NU_CPF_PESSOA AS VARCHAR(11))           AS CPF,
      P.NU_NIS_PESSOA                                    AS NIS,
      P.NO_PESSOA                                        AS NOME,

      /* Demografia */
      CASE P.CO_SEXO_PESSOA
           WHEN 1 THEN 'Masculino'
           WHEN 2 THEN 'Feminino'
           ELSE 'Não informado'
      END                                                AS SEXO,
      P.DT_NASC_PESSOA                                   AS DT_NASC,
      CAST((CURRENT_DATE - P.DT_NASC_PESSOA)/365 AS INTEGER) AS IDADE,

      /* Escolaridade (mesma regra que você já usava) */
      CASE
        /* ---------- Ensino Fundamental Incompleto ---------- */
        WHEN (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB IN (1,2)
              AND ESC.CO_CURSO_FREQUENTA_MEMB  = 7 AND ESC.CO_ANO_SERIE_FREQUENTA_MEMB IN (1,10))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB IN (1,2)
              AND ESC.CO_CURSO_FREQUENTA_MEMB IN (10,11))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 5 AND ESC.CO_ANO_SERIE_FREQUENTOU_MEMB IN (8,10))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 6 AND ESC.CO_ANO_SERIE_FREQUENTOU_MEMB IN (9,10))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 7 AND ESC.CO_ANO_SERIE_FREQUENTOU_MEMB IN (8,10))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 11)
        THEN 'EFI'

        /* ---------- Ensino Fundamental Completo ---------- */
        WHEN (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB IN (1,2)
              AND ESC.CO_CURSO_FREQUENTA_MEMB  = 4 AND ESC.CO_ANO_SERIE_FREQUENTA_MEMB IN (2,3,4,5,6,7,8))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB IN (1,2)
              AND ESC.CO_CURSO_FREQUENTA_MEMB  = 5 AND ESC.CO_ANO_SERIE_FREQUENTA_MEMB IN (3,4,5,6,7,8,9))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB IN (1,2)
              AND ESC.CO_CURSO_FREQUENTA_MEMB  = 10)
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 4 AND ESC.CO_ANO_SERIE_FREQUENTOU_MEMB IN (1,2,3,4,10))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 5 AND ESC.CO_ANO_SERIE_FREQUENTOU_MEMB IN (5,6,7))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 6 AND ESC.CO_ANO_SERIE_FREQUENTOU_MEMB IN (2,3,4,5,6,7,8))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 7 AND ESC.CO_ANO_SERIE_FREQUENTOU_MEMB IN (1,2,3,4,5,6,7))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 10)
        THEN 'EFC'

        /* ---------- Ensino Médio Incompleto ---------- */
        WHEN (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB IN (1,2)
              AND ESC.CO_CURSO_FREQUENTA_MEMB  = 7 AND ESC.CO_ANO_SERIE_FREQUENTA_MEMB IN (2,3,4))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB IN (8,9) AND ESC.CO_ANO_SERIE_FREQUENTOU_MEMB IN (1,2))
        THEN 'EMI'

        /* ---------- Ensino Médio Completo ---------- */
        WHEN (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB IN (1,2)
              AND ESC.CO_CURSO_FREQUENTA_MEMB  = 14)
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB IN (8,9) AND ESC.CO_ANO_SERIE_FREQUENTOU_MEMB IN (3,4,10))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 12)
        THEN 'EMC'

        /* ---------- Ensino Superior e acima ---------- */
        WHEN (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB IN (1,2)
              AND ESC.CO_CURSO_FREQUENTA_MEMB  = 13)
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 13)
        THEN 'ES OU +'

        ELSE 'Não Informado'
      END AS ESCOLARIDADE,

      /* UF sigla */
      CASE F.CO_MUNIC_IBGE_2_FAM
           WHEN 11 THEN 'RO' WHEN 12 THEN 'AC' WHEN 13 THEN 'AM' WHEN 14 THEN 'RR'
           WHEN 15 THEN 'PA' WHEN 16 THEN 'AP' WHEN 17 THEN 'TO' WHEN 21 THEN 'MA'
           WHEN 22 THEN 'PI' WHEN 23 THEN 'CE' WHEN 24 THEN 'RN' WHEN 25 THEN 'PB'
           WHEN 26 THEN 'PE' WHEN 27 THEN 'AL' WHEN 28 THEN 'SE' WHEN 29 THEN 'BA'
           WHEN 31 THEN 'MG' WHEN 32 THEN 'ES' WHEN 33 THEN 'RJ' WHEN 35 THEN 'SP'
           WHEN 41 THEN 'PR' WHEN 42 THEN 'SC' WHEN 43 THEN 'RS' WHEN 50 THEN 'MS'
           WHEN 51 THEN 'MT' WHEN 52 THEN 'GO' WHEN 53 THEN 'DF'
           ELSE 'Não Informado'
      END                                                AS UF,

      /* MUNICIPIO: nome não está na FAMILIA_01 → placeholder */
      'Montenegro'                                              AS MUNICIPIO, 			------------------------------------------------ MEXER AQUI

      /* CODIBGE UF(2)+MUN(5) */
      CAST(F.CO_MUNIC_IBGE_2_FAM AS VARCHAR(2)) ||
      CAST(F.CO_MUNIC_IBGE_5_FAM AS VARCHAR(5))          AS CODIBGE,

      /* Região: placeholder */
      '---'                                              AS REGIAO,

      /* Bairro */
      F.NO_LOCALIDADE_FAM                                AS BAIRRO,

      /* Contato */
      CONT.NU_DDD_CONTATO_1_FAM                          AS DDD,
      CASE
           WHEN CONT.NU_TEL_CONTATO_1_FAM IS NULL THEN NULL
           WHEN CONT.NU_TEL_CONTATO_1_FAM LIKE '0%' 
                THEN SUBSTRING(CONT.NU_TEL_CONTATO_1_FAM FROM 2)
           ELSE CONT.NU_TEL_CONTATO_1_FAM
      END                                                AS TELEFONE,

      /* chaves e controle */
      F.DT_ULT_ATUAL_FAM                                 AS DATA_ATUALIZACAO,
      P.CO_CHV_NATURAL_PESSOA                            AS CHAVE_PESSOA,
      F.CO_FAMILIAR_FAM                                  AS CO_FAMILIAR_FAM,
      P.DT_ATUAL_MEMB,
      ((SELECT REF_YM FROM ref)
        - (EXTRACT(YEAR  FROM P.DT_ATUAL_MEMB)*12 + EXTRACT(MONTH FROM P.DT_ATUAL_MEMB))) AS MESES_DESDE_ATUAL

  FROM TB_PESSOA_04 P
  JOIN TB_FAMILIA_01 F
    ON F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
  JOIN TB_DOCUMENTO_05 DOC
    ON DOC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA
  LEFT JOIN TB_ESCOLARIDADE_07 ESC
    ON ESC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA
  LEFT JOIN TB_CONTATO_09 CONT
    ON CONT.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
  WHERE DOC.NU_CPF_PESSOA IS NOT NULL
    AND (CURRENT_DATE - P.DT_NASC_PESSOA)/365 BETWEEN 18 AND 65
    AND F.CO_EST_CADASTRAL_FAM = 3
    AND F.IN_CADASTRO_VALIDO_FAM = 1
    AND F.CO_MUNIC_IBGE_2_FAM = (SELECT COD_UF FROM ref)
    AND F.CO_MUNIC_IBGE_5_FAM = (SELECT COD_MUN FROM ref)
    AND P.DT_ATUAL_MEMB IS NOT NULL
    AND ((SELECT REF_YM FROM ref)
        - (EXTRACT(YEAR FROM P.DT_ATUAL_MEMB)*12 + EXTRACT(MONTH FROM P.DT_ATUAL_MEMB))) <= 12
),

/* Dedupe por CPF: mais recente */
base_dedup AS (
  SELECT *
  FROM universo
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CPF
    ORDER BY DATA_ATUALIZACAO DESC, CHAVE_PESSOA
  ) = 1
),

/* Famílias em PRE e PBF (no RF_FOLHA) */
pre_fam AS (
  SELECT DISTINCT CO_FAMILIAR
  FROM P_DEBEN_ACC.VW_PRE_HABILITACAO_PBF
  WHERE RF_FOLHA = (SELECT RF_FOLHA FROM ref)
),
pbf_fam AS (
  SELECT DISTINCT CO_FAMILIAR
  FROM P_DEBEN_ACC.VW_FOLHA_PAGAMENTO
  WHERE RF_FOLHA = (SELECT RF_FOLHA FROM ref)
    AND TRIM(UPPER(NO_TIPO_SITIUACAO_BEN)) IN ('LIBERADO','L')
),

/* Classificação exclusiva */
classif AS (
  SELECT
    b.*,
    CASE
      WHEN p.CO_FAMILIAR IS NOT NULL THEN 'PRE'
      WHEN f.CO_FAMILIAR IS NOT NULL THEN 'PBF'
      ELSE 'CAD'
    END AS CATEGORIA
  FROM base_dedup b
  LEFT JOIN pre_fam p ON p.CO_FAMILIAR = b.CO_FAMILIAR_FAM
  LEFT JOIN pbf_fam f ON f.CO_FAMILIAR = b.CO_FAMILIAR_FAM
),

/* Metas (40/35/25) */
targets AS (
  SELECT
    N_TOTAL,
    CAST(CEILING(N_TOTAL * P_CAD) AS INTEGER) AS T_CAD,
    CAST(CEILING(N_TOTAL * P_PRE) AS INTEGER) AS T_PRE,
    CAST(CEILING(N_TOTAL * P_PBF) AS INTEGER) AS T_PBF
  FROM ref
),

/* Seleção pseudo-aleatória por HASHROW (sem RANDOM) */
ranked AS (
  SELECT
    c.*,
    ROW_NUMBER()
      OVER (PARTITION BY c.CATEGORIA ORDER BY HASHROW(c.CPF)) AS RN_CAT
  FROM classif c
),
pick1 AS (
  SELECT r.*
  FROM ranked r
  JOIN targets t ON 1=1
  WHERE (r.CATEGORIA='CAD' AND r.RN_CAT <= t.T_CAD)
     OR (r.CATEGORIA='PRE' AND r.RN_CAT <= t.T_PRE)
     OR (r.CATEGORIA='PBF' AND r.RN_CAT <= t.T_PBF)
),

/* Completar com CAD se faltar */
contagens AS (
  SELECT
    SUM(CASE WHEN CATEGORIA='CAD' THEN 1 ELSE 0 END) AS SEL_CAD,
    SUM(CASE WHEN CATEGORIA='PRE' THEN 1 ELSE 0 END) AS SEL_PRE,
    SUM(CASE WHEN CATEGORIA='PBF' THEN 1 ELSE 0 END) AS SEL_PBF
  FROM pick1
),
deficits AS (
  SELECT
    t.N_TOTAL,
    t.T_CAD,
    t.T_PRE,
    t.T_PBF,
    GREATEST(0, t.T_CAD - COALESCE(c.SEL_CAD,0)) AS D_CAD,
    GREATEST(0, t.T_PRE - COALESCE(c.SEL_PRE,0)) AS D_PRE,
    GREATEST(0, t.T_PBF - COALESCE(c.SEL_PBF,0)) AS D_PBF
  FROM targets t
  LEFT JOIN contagens c ON 1=1
),
need_cad AS (
  SELECT (D_CAD + D_PRE + D_PBF) AS NEED_EXTRA
  FROM deficits
),
cad_pool AS (
  SELECT r.*
  FROM ranked r
  WHERE r.CATEGORIA='CAD'
    AND NOT EXISTS (SELECT 1 FROM pick1 p WHERE p.CPF = r.CPF)
),
cad_rank AS (
  SELECT
    c.*,
    ROW_NUMBER() OVER (ORDER BY HASHROW(c.CPF)) AS RN
  FROM cad_pool c
),
pick_cad_extra AS (
  SELECT cr.*
  FROM cad_rank cr
  JOIN need_cad nd ON 1=1
  WHERE cr.RN <= nd.NEED_EXTRA
),

/* Resultado final (colunas alinhadas) */
final_pick AS (
  SELECT CPF, NIS, NOME, SEXO, DT_NASC, IDADE, ESCOLARIDADE,
         UF, MUNICIPIO, CODIBGE, REGIAO, BAIRRO, DDD, TELEFONE, CATEGORIA
  FROM pick1
  UNION ALL
  SELECT CPF, NIS, NOME, SEXO, DT_NASC, IDADE, ESCOLARIDADE,
         UF, MUNICIPIO, CODIBGE, REGIAO, BAIRRO, DDD, TELEFONE, CATEGORIA
  FROM pick_cad_extra
)

SELECT
  CPF, NIS, NOME, SEXO, DT_NASC, IDADE, ESCOLARIDADE,
  UF, MUNICIPIO, CODIBGE, REGIAO, BAIRRO, DDD, TELEFONE,
  CATEGORIA
FROM final_pick;

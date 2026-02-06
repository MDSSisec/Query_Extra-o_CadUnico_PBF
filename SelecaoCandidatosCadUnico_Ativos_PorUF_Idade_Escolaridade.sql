/* ============================================================================
   OBJETIVO
     Extrair candidatos do ODS (CadÚnico ativo), com filtros por:
       - faixa etária
       - escolaridade (EMC/EMI, etc.)
       - atualização cadastral (<= 12 meses)
       - UF específica
     + marcar FL_PBF e FL_PRE_HAB conforme suas regras de RF_FOLHA
     + deduplicar por CPF (pega ocorrência vigente)

   AJUSTES (só mexer aqui):
     - ANOMES_ODS
     - UF_CD
     - IDADE_MIN / IDADE_MAX
     - LISTA_ESC (EMC, EMI, ...)
     - MESES_MAX_ATUAL (12 = até 1 ano)
   ============================================================================ */

DATABASE P_CADASTRO_ODS_202510;   -- <- ajuste para seu ANOMES

/* 0) Parâmetros em tabela volátil (evita ficar caçando na query inteira) */
DROP TABLE vt_params;

CREATE VOLATILE TABLE vt_params (
  ANOMES_ODS        INTEGER,
  UF_CD             INTEGER,
  IDADE_MIN         INTEGER,
  IDADE_MAX         INTEGER,
  MESES_MAX_ATUAL   INTEGER
) ON COMMIT PRESERVE ROWS;

INSERT INTO vt_params VALUES (
  202510,   -- ANOMES_ODS
  35,       -- UF_CD (ex.: 35=SP, 31=MG, etc.)
  16,       -- IDADE_MIN
  30,       -- IDADE_MAX
  12        -- MESES_MAX_ATUAL (12 = até 1 ano; se quiser 13, troque aqui)
);

/* 1) Calcula RF_FOLHA (PBF = mês seguinte; PRE = mesmo mês) */
WITH ref AS (
  SELECT
    p.ANOMES_ODS,
    p.UF_CD,
    p.IDADE_MIN,
    p.IDADE_MAX,
    p.MESES_MAX_ATUAL,

    /* transforma YYYYMM em DATE (YYYYMM01) */
    CAST(CAST(p.ANOMES_ODS * 100 + 01 AS CHAR(8)) AS DATE FORMAT 'YYYYMMDD') AS DT_REF,

    /* RF_FOLHA PBF = +1 mês calendário */
    (EXTRACT(YEAR  FROM ADD_MONTHS(CAST(CAST(p.ANOMES_ODS * 100 + 01 AS CHAR(8)) AS DATE FORMAT 'YYYYMMDD'), 1)) * 100
   + EXTRACT(MONTH FROM ADD_MONTHS(CAST(CAST(p.ANOMES_ODS * 100 + 01 AS CHAR(8)) AS DATE FORMAT 'YYYYMMDD'), 1))
    ) AS RF_FOLHA_PBF,

    /* RF_FOLHA PRE = mesmo mês do ODS */
    p.ANOMES_ODS AS RF_FOLHA_PRE,

    /* referência em “meses absolutos” (YEAR*12 + MONTH) para comparar com DT_ATUAL_MEMB */
    (EXTRACT(YEAR FROM CAST(CAST(p.ANOMES_ODS * 100 + 01 AS CHAR(8)) AS DATE FORMAT 'YYYYMMDD')) * 12
   + EXTRACT(MONTH FROM CAST(CAST(p.ANOMES_ODS * 100 + 01 AS CHAR(8)) AS DATE FORMAT 'YYYYMMDD'))
    ) AS REF_YM
  FROM vt_params p
),

/* 2) Conjuntos de famílias nas views (por RF_FOLHA correto) */
folha_any AS (
  SELECT DISTINCT FOL.CO_FAMILIAR
  FROM P_DEBEN_ACC.VW_FOLHA_PAGAMENTO FOL
  JOIN ref r
    ON FOL.RF_FOLHA = r.RF_FOLHA_PBF
),
pre_any AS (
  SELECT DISTINCT PRE.CO_FAMILIAR
  FROM P_DEBEN_ACC.VW_PRE_HABILITACAO_PBF PRE
  JOIN ref r
    ON PRE.RF_FOLHA = r.RF_FOLHA_PRE
),

/* 3) Base (CadÚnico ativo + filtros) */
base_raw AS (
  SELECT
      /* Identificação */
      CAST(DOC.NU_CPF_PESSOA AS DECIMAL(20,0))              AS CPF_NUM,
      P.NU_NIS_PESSOA                                       AS NIS,
      P.NO_PESSOA                                           AS NOME,

      /* Demográficos */
      CASE P.CO_SEXO_PESSOA
        WHEN 1 THEN 'Masculino'
        WHEN 2 THEN 'Feminino'
        ELSE 'Não informado'
      END                                                   AS SEXO,

      P.DT_NASC_PESSOA                                      AS DT_NASC,

      CAST((CURRENT_DATE - P.DT_NASC_PESSOA) / 365 AS INTEGER) AS IDADE,

      /* Escolaridade (mantive apenas o essencial p/ EMI/EMC; o resto vira OUTROS)
         Se você quiser o case COMPLETO (EFI/EFC/EMI/EMC/ES+), eu expando. */
      CASE
        /* EMI (mantenha suas regras reais aqui se quiser 100% fiel) */
        WHEN (ESC.CO_SABE_LER_ESCREVER_MEMB = 1
              AND ESC.IN_FREQUENTA_ESCOLA_MEMB IN (1,2)
              AND ESC.CO_CURSO_FREQUENTA_MEMB  = 7
              AND ESC.CO_ANO_SERIE_FREQUENTA_MEMB IN (2,3,4))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1
              AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB IN (8,9)
              AND ESC.CO_ANO_SERIE_FREQUENTOU_MEMB IN (1,2))
        THEN 'EMI'

        /* EMC */
        WHEN (ESC.CO_SABE_LER_ESCREVER_MEMB = 1
              AND ESC.IN_FREQUENTA_ESCOLA_MEMB IN (1,2)
              AND ESC.CO_CURSO_FREQUENTA_MEMB  = 14)
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1
              AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB IN (8,9)
              AND ESC.CO_ANO_SERIE_FREQUENTOU_MEMB IN (3,4,10))
          OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1
              AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
              AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 12)
        THEN 'EMC'

        ELSE 'OUTROS'
      END                                                   AS ESCOLARIDADE,

      /* UF (a partir do código UF do IBGE) */
      CASE F.CO_MUNIC_IBGE_2_FAM
        WHEN 11 THEN 'RO' WHEN 12 THEN 'AC' WHEN 13 THEN 'AM' WHEN 14 THEN 'RR'
        WHEN 15 THEN 'PA' WHEN 16 THEN 'AP' WHEN 17 THEN 'TO' WHEN 21 THEN 'MA'
        WHEN 22 THEN 'PI' WHEN 23 THEN 'CE' WHEN 24 THEN 'RN' WHEN 25 THEN 'PB'
        WHEN 26 THEN 'PE' WHEN 27 THEN 'AL' WHEN 28 THEN 'SE' WHEN 29 THEN 'BA'
        WHEN 31 THEN 'MG' WHEN 32 THEN 'ES' WHEN 33 THEN 'RJ' WHEN 35 THEN 'SP'
        WHEN 41 THEN 'PR' WHEN 42 THEN 'SC' WHEN 43 THEN 'RS'
        WHEN 50 THEN 'MS' WHEN 51 THEN 'MT' WHEN 52 THEN 'GO' WHEN 53 THEN 'DF'
        ELSE 'Não Informado'
      END                                                   AS UF,

      /* MUNICIPIO: sem dicionário aqui, devolvo o código como texto (você pode trocar por join em lookup se tiver) */
      TRIM(CAST(F.CO_MUNIC_IBGE_5_FAM AS VARCHAR(5)))        AS MUNICIPIO,

      /* CODIBGE 7 dígitos (UF2 + MUN5) */
      LPAD(TRIM(CAST(F.CO_MUNIC_IBGE_2_FAM AS VARCHAR(2))), 2, '0')
      || LPAD(TRIM(CAST(F.CO_MUNIC_IBGE_5_FAM AS VARCHAR(5))), 5, '0') AS CODIBGE,

      '---'                                                 AS REGIAO,
      F.NO_LOCALIDADE_FAM                                   AS BAIRRO,

      /* Contato */
      CONT.NU_DDD_CONTATO_1_FAM                              AS DDD,
      CASE
        WHEN CONT.NU_TEL_CONTATO_1_FAM IS NULL THEN NULL
        WHEN CONT.NU_TEL_CONTATO_1_FAM LIKE '0%' THEN SUBSTRING(CONT.NU_TEL_CONTATO_1_FAM FROM 2)
        ELSE CONT.NU_TEL_CONTATO_1_FAM
      END                                                   AS TELEFONE,

      /* Datas */
      P.DT_ATUAL_MEMB                                       AS DT_ATUAL_MEMB,
      F.DT_ATUALIZACAO_FAM                                  AS DT_ATUALIZACAO_FAM,

      /* Flags PBF/PRE por CO_FAMILIAR (família da ocorrência vigente) */
      CASE WHEN FA.CO_FAMILIAR IS NOT NULL THEN 1 ELSE 0 END AS FL_PBF,
      CASE WHEN PR.CO_FAMILIAR IS NOT NULL THEN 1 ELSE 0 END AS FL_PRE_HAB,

      /* Para dedup */
      P.CO_CHV_NATURAL_PESSOA                               AS CHAVE_PESSOA

  FROM TB_PESSOA_04 P
  JOIN TB_FAMILIA_01 F
    ON F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
  JOIN TB_DOCUMENTO_05 DOC
    ON DOC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA
  LEFT JOIN TB_ESCOLARIDADE_07 ESC
    ON ESC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA
  LEFT JOIN TB_CONTATO_09 CONT
    ON CONT.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
  LEFT JOIN folha_any FA
    ON FA.CO_FAMILIAR = F.CO_FAMILIAR_FAM
  LEFT JOIN pre_any PR
    ON PR.CO_FAMILIAR = F.CO_FAMILIAR_FAM
  CROSS JOIN ref r

  WHERE
      /* Universo CadÚnico ativo (seu critério) */
      F.CO_EST_CADASTRAL_FAM NOT IN (1,2,4)
      AND P.CO_EST_CADASTRAL_MEMB = 3

      /* UF específica */
      AND F.CO_MUNIC_IBGE_2_FAM = r.UF_CD

      /* CPF existente */
      AND DOC.NU_CPF_PESSOA IS NOT NULL

      /* Faixa etária */
      AND CAST((CURRENT_DATE - P.DT_NASC_PESSOA) / 365 AS INTEGER) BETWEEN r.IDADE_MIN AND r.IDADE_MAX

      /* Atualização cadastral <= MESES_MAX_ATUAL */
      AND P.DT_ATUAL_MEMB IS NOT NULL
      AND ( r.REF_YM
            - (EXTRACT(YEAR FROM P.DT_ATUAL_MEMB) * 12 + EXTRACT(MONTH FROM P.DT_ATUAL_MEMB))
          ) BETWEEN 0 AND r.MESES_MAX_ATUAL
),

/* 4) Dedup por CPF: pega ocorrência “vigente” */
base_dedup AS (
  SELECT *
  FROM base_raw
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CPF_NUM
    ORDER BY DT_ATUAL_MEMB DESC, DT_ATUALIZACAO_FAM DESC, CHAVE_PESSOA
  ) = 1
)

SELECT
  /* CPF 11 dígitos (com zero à esquerda) */
  LPAD(TRIM(CAST(CPF_NUM AS VARCHAR(20))), 11, '0') AS CPF,
  NIS, NOME, SEXO, DT_NASC, IDADE, ESCOLARIDADE, UF, MUNICIPIO, CODIBGE, REGIAO,
  BAIRRO, DDD, TELEFONE,
  FL_PBF, FL_PRE_HAB, DT_ATUAL_MEMB, DT_ATUALIZACAO_FAM,

  /* categoria (precedência PRE > PBF > CAD) */
  CASE
    WHEN FL_PRE_HAB = 1 THEN 'PRE'
    WHEN FL_PBF = 1     THEN 'PBF'
    ELSE 'CAD'
  END AS categoria

FROM base_dedup
/* Filtra escolaridade desejada aqui (ex.: só EMC e EMI) */
WHERE ESCOLARIDADE IN ('EMC','EMI')
ORDER BY NOME;
--SAMPLE 1000;   -- ajuste “quantidade X” aqui


/* ============================================================================
   QUERY: Extracao_CadUnico_Candidatos_Dedup_CPF_Com_PBF_e_PreHab

   OBJETIVO:
     Extrair candidatos do CadÚnico (ODS mensal), retornando 1 registro por CPF
     (ocorrência vigente), aplicando filtros demográficos, cadastrais e
     educacionais, e marcando a situação da família em relação ao
     Programa Bolsa Família.

   FILTROS APLICADOS:
     - UF específica (CO_MUNIC_IBGE_2_FAM = UF2)
     - Faixa etária configurável (IDADE_MIN a IDADE_MAX)
     - Cadastro ativo no CadÚnico:
         * Pessoa ativa (CO_EST_CADASTRAL_MEMB = 3)
         * Família ativa (CO_EST_CADASTRAL_FAM NOT IN (1,2,4))
     - Cadastro válido e elegível:
         * IN_CADASTRO_VALIDO_FAM <> 2
         * CO_CONDICAO_CADASTRO_FAM <> 6
     - Atualização cadastral dentro do intervalo de 0 a 13 meses
       em relação ao ANOMES de referência
     - Escolaridade filtrada (ex.: EMI, EMC)

   DEDUPLICAÇÃO:
     - Retorna apenas 1 linha por CPF
     - Critério de escolha da ocorrência vigente:
         1) Maior DT_ATUAL_MEMB
         2) Maior DT_ATUALIZACAO_FAM
         3) Maior CO_CHV_NATURAL_PESSOA

   FLAGS GERADAS:
     - FL_PBF:
         Indica se a família vigente do CPF está presente
         na folha do Bolsa Família (RF_FOLHA = ANOMES_REF + 1)
     - FL_PRE_HAB:
         Indica se a família vigente do CPF está
         pré-habilitada no mês de referência (RF_FOLHA = ANOMES_REF)

   PARAMETRIZAÇÃO:
     Todos os principais parâmetros (UF, idade, ANOMES, RF_FOLHA)
     estão concentrados no CTE "params" para facilitar reuso e manutenção.

   OBSERVAÇÃO TÉCNICA:
     - O schema ODS deve ser alterado manualmente nos FROM/JOIN,
       pois o Teradata não aceita nomes de schema dinâmicos.
   ============================================================================ */
/* =========================================================
   PARAMETROS (edite aqui)
   ========================================================= */
WITH params AS (
  SELECT
    /* Schema mensal do CadÚnico (ex.: P_CADASTRO_ODS_202510) */
    'P_CADASTRO_ODS_202510' AS SCHEMA_ODS,

    /* UF2 = código IBGE 2 dígitos (ex.: 35=SP, 53=DF, 52=GO etc.) */
    53 AS UF2,

    /* Faixa etária */
    16 AS IDADE_MIN,
    50 AS IDADE_MAX,

    /* Referência ANOMES para regra 0..13 meses (mesma lógica do seu ANOMES_REF_YM) */
    202510 AS ANOMES_REF_YM,

    /* Folhas PBF/PRE (use os mesmos valores do seu config.py) */
    202511 AS RF_FOLHA_PBF,
    202510 AS RF_FOLHA_PRE
),
base_raw AS (
  SELECT
      DOC.NU_CPF_PESSOA                                  AS CPF,
      P.NU_NIS_PESSOA                                    AS NIS,
      P.NO_PESSOA                                        AS NOME,
      CASE P.CO_SEXO_PESSOA
           WHEN 1 THEN 'Masculino'
           WHEN 2 THEN 'Feminino'
           ELSE 'Não informado'
      END                                                AS SEXO,
      P.DT_NASC_PESSOA                                   AS DT_NASC,
      (CURRENT_DATE - P.DT_NASC_PESSOA) / 365            AS IDADE,

      /* ======= ESCOLARIDADE (mesma regra da sua query) ======= */
      CASE
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
           WHEN (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB IN (1,2)
                 AND ESC.CO_CURSO_FREQUENTA_MEMB  = 7 AND ESC.CO_ANO_SERIE_FREQUENTA_MEMB IN (2,3,4))
             OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
                 AND ESC.CO_CURSO_FREQ_PESSOA_MEMB IN (8,9) AND ESC.CO_ANO_SERIE_FREQUENTOU_MEMB IN (1,2))
                THEN 'EMI'
           WHEN (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB IN (1,2)
                 AND ESC.CO_CURSO_FREQUENTA_MEMB  = 14)
             OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
                 AND ESC.CO_CURSO_FREQ_PESSOA_MEMB IN (8,9) AND ESC.CO_ANO_SERIE_FREQUENTOU_MEMB IN (3,4,10))
             OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
                 AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 12)
                THEN 'EMC'
           WHEN (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB IN (1,2)
                 AND ESC.CO_CURSO_FREQUENTA_MEMB  = 13)
             OR (ESC.CO_SABE_LER_ESCREVER_MEMB = 1 AND ESC.IN_FREQUENTA_ESCOLA_MEMB = 3
                 AND ESC.CO_CURSO_FREQ_PESSOA_MEMB = 13)
                THEN 'ES OU +'
           ELSE 'Não Informado'
      END                                                AS ESCOLARIDADE,

      F.NO_LOCALIDADE_FAM                                AS BAIRRO,
      CONT.NU_DDD_CONTATO_1_FAM                          AS DDD,
      CASE WHEN CONT.NU_TEL_CONTATO_1_FAM LIKE '0%' THEN SUBSTRING(CONT.NU_TEL_CONTATO_1_FAM FROM 2)
           ELSE CONT.NU_TEL_CONTATO_1_FAM END           AS TELEFONE,

      P.DT_ATUAL_MEMB                                    AS DT_ATUAL_MEMB,
      F.DT_ATUALIZACAO_FAM                               AS DT_ATUALIZACAO_FAM,
      P.CO_CHV_NATURAL_PESSOA                            AS CO_CHV_NATURAL_PESSOA,
      P.CO_FAMILIAR_FAM                                  AS CO_FAMILIAR_FAM
  FROM params prm
  JOIN  (SELECT * FROM DBC.TablesV WHERE 1=1) dummy ON 1=1  /* no-op p/ permitir prm primeiro */

  /* >>> TROQUE abaixo o schema manualmente (Teradata não aceita prm.SCHEMA_ODS como identificador) */
  JOIN   P_CADASTRO_ODS_202510.TB_PESSOA_04       P
         ON 1=1
  JOIN   P_CADASTRO_ODS_202510.TB_FAMILIA_01      F
         ON  F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
  JOIN   P_CADASTRO_ODS_202510.TB_DOCUMENTO_05    DOC
         ON  DOC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA
  LEFT JOIN P_CADASTRO_ODS_202510.TB_ESCOLARIDADE_07 ESC
         ON  ESC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA
  LEFT JOIN P_CADASTRO_ODS_202510.TB_CONTATO_09   CONT
         ON  CONT.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM

  WHERE DOC.NU_CPF_PESSOA IS NOT NULL
    AND (CURRENT_DATE - P.DT_NASC_PESSOA) / 365 BETWEEN prm.IDADE_MIN AND prm.IDADE_MAX
    AND F.CO_EST_CADASTRAL_FAM NOT IN (1, 2, 4)
    AND P.CO_EST_CADASTRAL_MEMB = 3
    AND P.DT_ATUAL_MEMB IS NOT NULL
    AND (prm.ANOMES_REF_YM - (EXTRACT(YEAR FROM P.DT_ATUAL_MEMB) * 12 + EXTRACT(MONTH FROM P.DT_ATUAL_MEMB))) BETWEEN 0 AND 13
    AND F.IN_CADASTRO_VALIDO_FAM <> 2
    AND F.CO_CONDICAO_CADASTRO_FAM <> 6
    AND F.CO_MUNIC_IBGE_2_FAM = prm.UF2
),
base_filtrada AS (
  /* filtro de escolaridade aqui (porque não dá pra usar alias ESCOLARIDADE no WHERE do mesmo SELECT) */
  SELECT *
  FROM base_raw
  WHERE ESCOLARIDADE IN ('EMI','EMC')  /* <<< edite a lista */
),
base_dedup AS (
  SELECT *
  FROM base_filtrada
  QUALIFY ROW_NUMBER() OVER (
      PARTITION BY CPF
      ORDER BY DT_ATUAL_MEMB DESC, DT_ATUALIZACAO_FAM DESC, CO_CHV_NATURAL_PESSOA
  ) = 1
),
folha_any AS (
  SELECT DISTINCT CO_FAMILIAR
  FROM P_DEBEN_ACC.VW_FOLHA_PAGAMENTO
  WHERE RF_FOLHA = (SELECT RF_FOLHA_PBF FROM params)
),
pre_any AS (
  SELECT DISTINCT CO_FAMILIAR
  FROM P_DEBEN_ACC.VW_PRE_HABILITACAO_PBF
  WHERE RF_FOLHA = (SELECT RF_FOLHA_PRE FROM params)
),
pbf_pre_por_cpf AS (
  SELECT
      b.CPF,
      MAX(CASE WHEN fa.CO_FAMILIAR IS NOT NULL THEN 1 ELSE 0 END) AS FL_PBF,
      MAX(CASE WHEN pr.CO_FAMILIAR IS NOT NULL THEN 1 ELSE 0 END) AS FL_PRE_HAB
  FROM base_dedup b
  LEFT JOIN folha_any fa ON fa.CO_FAMILIAR = b.CO_FAMILIAR_FAM
  LEFT JOIN pre_any  pr ON pr.CO_FAMILIAR = b.CO_FAMILIAR_FAM
  GROUP BY 1
)
SELECT
  b.CPF, b.NIS, b.NOME, b.SEXO, b.DT_NASC, b.IDADE,
  b.ESCOLARIDADE,
  b.BAIRRO, b.DDD, b.TELEFONE,
  COALESCE(flags.FL_PBF, 0)      AS FL_PBF,
  COALESCE(flags.FL_PRE_HAB, 0)  AS FL_PRE_HAB,
  b.DT_ATUAL_MEMB,
  b.DT_ATUALIZACAO_FAM
FROM base_dedup b
LEFT JOIN pbf_pre_por_cpf flags ON flags.CPF = b.CPF;


WITH params AS (
  SELECT
    'P_CADASTRO_ODS_202510' AS SCHEMA_ODS,
    53 AS UF2,
    16 AS IDADE_MIN,
    50 AS IDADE_MAX,
    202510 AS ANOMES_REF_YM,
    202511 AS RF_FOLHA_PBF,
    202510 AS RF_FOLHA_PRE
),
base_raw AS (
  SELECT
      P.NU_CPF_PESSOA AS CPF,
      P.NO_PESSOA AS NOME,
      (CURRENT_DATE - P.DT_NASC_PESSOA) / 365 AS IDADE,
      CASE P.CO_SEXO_PESSOA
           WHEN 1 THEN 'Masculino'
           WHEN 2 THEN 'Feminino'
           ELSE 'Não informado'
      END AS SEXO,
      ESCOLARIDADE /* Adicione outras colunas relevantes conforme necessário */
  FROM params prm
  JOIN P_CADASTRO_ODS_202510.TB_PESSOA_04 P ON 1=1
  LEFT JOIN P_CADASTRO_ODS_202510.TB_ESCOLARIDADE_07 ESC
    ON ESC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA
  WHERE (CURRENT_DATE - P.DT_NASC_PESSOA) / 365 BETWEEN prm.IDADE_MIN AND prm.IDADE_MAX
    AND F.CO_MUNIC_IBGE_2_FAM = prm.UF2
),
base_filtrada AS (
  SELECT *
  FROM base_raw
  WHERE ESCOLARIDADE IN ('EMI', 'EMC')  /* Ajuste conforme necessidade */
)
SELECT * FROM base_filtrada;


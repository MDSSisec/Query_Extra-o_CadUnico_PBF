/* =============================================================================
   ConsultaSelecaoCandidatosCadUnico_Deduplicada_PBF_PreHab
   -----------------------------------------------------------------------------
   OBJETIVO:
     Extrair candidatos do CadÚnico (ODS), retornando uma base única por CPF,
     com informações demográficas, escolares, territoriais, de contato e
     situação no Programa Bolsa Família.

   A consulta:
     - Parte do CadÚnico ativo (família válida e cadastrada)
     - Aplica filtros por:
         • Faixa etária (18 a 65 anos)
         • Escolaridade (classificada em EFI, EFC, EMI, EMC, ES ou +)
         • UF e município específicos
     - Identifica situação no Bolsa Família:
         • Beneficiário ativo
         • Suspenso
         • Bloqueado
         • Pré-habilitado
         • Não participante
     - Cria flag booleana (PBF = TRUE/FALSE)
     - Deduplica registros por CPF, mantendo a ocorrência mais recente
       com base na data de atualização da família.

   BASES UTILIZADAS:
     - TB_PESSOA_04
     - TB_FAMILIA_01
     - TB_DOCUMENTO_05
     - TB_ESCOLARIDADE_07
     - TB_CONTATO_09
     - VW_FOLHA_PAGAMENTO
     - VW_PRE_HABILITACAO_PBF

   REGRAS IMPORTANTES:
     - Apenas famílias ativas e válidas (CO_EST_CADASTRAL_FAM = 3)
     - Apenas pessoas com CPF preenchido
     - Deduplicação via ROW_NUMBER() por CPF
     - A situação PBF considera suspensão e bloqueio como NÃO elegível

   OBSERVAÇÃO:
     O resultado final retorna 1 linha por CPF (registro vigente).

   ============================================================================= */

WITH base AS (
  SELECT
      -- ===== IDENTIFICAÇÃO =====
      DOC.NU_CPF_PESSOA                                  AS CPF,
      P.NU_NIS_PESSOA                                    AS NIS,
      P.NO_PESSOA                                        AS NOME,
      
      -- ===== DADOS DEMOGRÁFICOS =====
      CASE P.CO_SEXO_PESSOA
           WHEN 1 THEN 'Masculino'
           WHEN 2 THEN 'Feminino'
           ELSE 'Não informado'
      END                                                AS SEXO,
      
      P.DT_NASC_PESSOA                                   AS DT_NASC,
      CAST((CURRENT_DATE - P.DT_NASC_PESSOA) / 365 AS INTEGER) AS IDADE,

      -- ===== ESCOLARIDADE =====
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
      END                                                AS ESCOLARIDADE,

      -- ===== LOCALIZAÇÃO (DINÂMICA) =====
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
      
      'Contagem'                                         AS MUNICIPIO,
      
      CAST(F.CO_MUNIC_IBGE_2_FAM AS VARCHAR(2)) || 
      CAST(F.CO_MUNIC_IBGE_5_FAM AS VARCHAR(5))          AS CODIBGE,
      
      '---'                                              AS REGIAO,
      
      F.NO_LOCALIDADE_FAM                                AS BAIRRO,

      -- ===== CONTATO =====
      CONT.NU_DDD_CONTATO_1_FAM                          AS DDD,
      
      CASE
           WHEN CONT.NU_TEL_CONTATO_1_FAM IS NULL THEN NULL
           WHEN CONT.NU_TEL_CONTATO_1_FAM LIKE '0%' 
                THEN SUBSTRING(CONT.NU_TEL_CONTATO_1_FAM FROM 2)
           ELSE CONT.NU_TEL_CONTATO_1_FAM
      END                                                AS TELEFONE,

      -- ===== PBF BOOLEANO (MANTIDO) =====
      -- TRUE se está na folha E não está suspenso/bloqueado
      -- FALSE se não está no programa OU está suspenso/bloqueado
      CASE 
          WHEN BF.CO_FAMILIAR IS NOT NULL 
           AND COALESCE(BF.NO_TIPO_SITIUACAO_BEN, 'LIBERADO') NOT IN ('SUSPENSO', 'BLOQUEADO')
          THEN 'TRUE' 
          ELSE 'FALSE' 
      END                                                AS PBF,
      
      -- ===== STATUS PBF DETALHADO (NOVO) =====
      CASE 
          -- Pré-habilitados (na fila de espera)
          WHEN PRE.CO_FAMILIAR IS NOT NULL 
          THEN 'PRÉ-HABILITADO'
          
          -- Beneficiários ativos (LIBERADO ou sem informação = liberado por padrão)
          WHEN BF.CO_FAMILIAR IS NOT NULL 
           AND COALESCE(BF.NO_TIPO_SITIUACAO_BEN, 'LIBERADO') IN ('LIBERADO', 'L', 'NAO INFORMADO')
          THEN 'ATIVO'
          
          -- Suspensos
          WHEN BF.CO_FAMILIAR IS NOT NULL 
           AND BF.NO_TIPO_SITIUACAO_BEN = 'SUSPENSO'
          THEN 'SUSPENSO'
          
          -- Bloqueados
          WHEN BF.CO_FAMILIAR IS NOT NULL 
           AND BF.NO_TIPO_SITIUACAO_BEN = 'BLOQUEADO'
          THEN 'BLOQUEADO'
          
          -- Não está no programa
          ELSE NULL
      END                                                AS STATUS_PBF,
      
      -- ===== CAMPOS PARA DEDUPLICAÇÃO =====
      F.DT_ULT_ATUAL_FAM                                 AS DATA_ATUALIZACAO,
      P.CO_CHV_NATURAL_PESSOA                            AS CHAVE_PESSOA

  FROM   P_CADASTRO_ODS_202503.TB_PESSOA_04       P
  
  JOIN   P_CADASTRO_ODS_202503.TB_FAMILIA_01      F
         ON  F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
  
  JOIN   P_CADASTRO_ODS_202503.TB_DOCUMENTO_05    DOC
         ON  DOC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA
  
  LEFT JOIN P_CADASTRO_ODS_202503.TB_ESCOLARIDADE_07 ESC
         ON  ESC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA
  
  LEFT JOIN P_CADASTRO_ODS_202503.TB_CONTATO_09      CONT
         ON  CONT.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
  
  LEFT JOIN P_DEBEN_ACC.VW_FOLHA_PAGAMENTO BF
         ON  F.CO_FAMILIAR_FAM = BF.CO_FAMILIAR
  
  LEFT JOIN P_DEBEN_ACC.VW_PRE_HABILITACAO_PBF PRE
         ON  F.CO_FAMILIAR_FAM = PRE.CO_FAMILIAR

  WHERE DOC.NU_CPF_PESSOA IS NOT NULL
    AND (CURRENT_DATE - P.DT_NASC_PESSOA) / 365 BETWEEN 18 AND 65
    AND F.CO_EST_CADASTRAL_FAM = 3                       -- Apenas CADASTRADOS
    AND F.IN_CADASTRO_VALIDO_FAM = 1                     -- Apenas VÁLIDOS
    AND F.CO_MUNIC_IBGE_2_FAM = 31                       -- Estado: MG
    AND F.CO_MUNIC_IBGE_5_FAM = 18601                    -- Município: Contagem
)

-- ===== SELECT FINAL COM DEDUPLICAÇÃO =====
SELECT
  CPF, 
  NIS, 
  NOME, 
  SEXO, 
  DT_NASC, 
  IDADE,
  ESCOLARIDADE, 
  UF, 
  MUNICIPIO,
  CODIBGE,
  REGIAO,
  BAIRRO, 
  DDD, 
  TELEFONE,
  PBF,           -- Booleano: TRUE/FALSE
  STATUS_PBF     -- Detalhado: PRÉ-HABILITADO/ATIVO/INATIVO/NULL

FROM base

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CPF 
    ORDER BY DATA_ATUALIZACAO DESC,
             CHAVE_PESSOA
) = 1

SAMPLE 100;
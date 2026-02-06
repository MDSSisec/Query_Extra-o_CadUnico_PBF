/* ============================================================================
   OBJETIVO:
     Para uma lista (NOME, CPF), marcar para cada CPF:

       - CADUNICO_ATIVO
           Pessoa com CO_EST_CADASTRAL_MEMB = 3
           E pelo menos uma família com CO_EST_CADASTRAL_FAM = 3 no ANOMES ODS.

       - CADUNICO_PRESENCA
           CPF tem pessoa vinculada em família com CO_EST_CADASTRAL_FAM = 3
           (mesmo que a pessoa não esteja em estado 3).

       - PBF
           Considera SOMENTE o CO_FAMILIAR_FAM da ocorrência vigente
           (pessoa=3 e família=3, mais recente), e verifica se essa família
           está na VW_FOLHA_PAGAMENTO (RF_FOLHA = ODS+1).

       - PRE_HABILITADO
           Mesma lógica do PBF, mas usando VW_PRE_HABILITACAO_PBF (RF_FOLHA = ODS+1).

     + Diagnóstico de por que o CPF NÃO é considerado CADÚNICO_ATIVO / PBF.

   AJUSTES NECESSÁRIOS AO TROCAR O MÊS:
     1) Trocar o DATABASE P_CADASTRO_ODS_202512;
     2) Trocar o schema das tabelas TB_* (se mudar o ANOMES);
     3) Trocar o RF_FOLHA = 202511 nas CTEs folha_any e pre_any.

   ============================================================================ */

-- essa é a consulta oficial pai bota o gabriel p subir isso no git slc

-- Limpa tabela volátil anterior (se existir)
DROP TABLE vt_lista_cpf;

DELETE FROM vt_lista_cpf;

-- ODS de referência do universo
DATABASE P_CADASTRO_ODS_202512;

-------------------------------------------------------------------------------
-- 1) Tabela volátil de entrada: lista de CPFs para batimento
-------------------------------------------------------------------------------
CREATE VOLATILE TABLE vt_lista_cpf (
  NOME     VARCHAR(200) CHARACTER SET UNICODE,
  CPF_RAW  VARCHAR(64)  CHARACTER SET LATIN,
  CPF_NUM  DECIMAL(20,0)
) PRIMARY INDEX (CPF_NUM)
ON COMMIT PRESERVE ROWS;

-- Exemplo de carga (substitua pelos seus INSERTs / IMPORT):
-- INSERT INTO vt_lista_cpf (NOME, CPF_RAW) VALUES ('MARIA DA SILVA','123.456.789-01');

-- Higienização do CPF (remove máscara e converte para número)
UPDATE vt_lista_cpf
SET CPF_NUM =
  CASE
    WHEN OTRANSLATE(CPF_RAW, ' .-/', '') IS NULL
      OR OTRANSLATE(CPF_RAW, ' .-/', '') = '' THEN NULL
    ELSE CAST(OTRANSLATE(CPF_RAW, ' .-/', '') AS DECIMAL(20,0))
  END;

-------------------------------------------------------------------------------
-- 2) CTEs de batimento
-------------------------------------------------------------------------------
WITH
-------------------------------------------------------------------------------
-- 2.1) Mapeia CPF -> chave natural da pessoa (via DOCUMENTO_05)
-------------------------------------------------------------------------------
docs_map AS (
  SELECT DISTINCT
         CAST(D.NU_CPF_PESSOA AS DECIMAL(20,0)) AS CPF_NUM,
         D.CO_CHV_NATURAL_PESSOA
  FROM  P_CADASTRO_ODS_202512.TB_DOCUMENTO_05 AS D
  WHERE D.NU_CPF_PESSOA IS NOT NULL
),

-------------------------------------------------------------------------------
-- 2.2) Base agregada por CPF: flags de presença no ODS e estados máximos
-------------------------------------------------------------------------------
base_por_cpf AS (
  SELECT
      dm.CPF_NUM,

      -- Encontrou CPF no DOC_05?
      MAX(1) AS FL_DOC_ENCONTRADO,

      -- Tem alguma pessoa ligada a esse CPF?
      MAX(CASE WHEN P.CO_CHV_NATURAL_PESSOA IS NOT NULL THEN 1 ELSE 0 END) AS FL_TEM_PESSOA,

      -- Tem alguma família ligada a essa(s) pessoa(s)?
      MAX(CASE WHEN F.CO_FAMILIAR_FAM      IS NOT NULL THEN 1 ELSE 0 END)  AS FL_TEM_FAMILIA,

      -- Estados "máximos" para debug (não são somas, apenas um representativo)
      MAX(P.CO_EST_CADASTRAL_MEMB) AS ANY_EST_PESSOA,
      MAX(F.CO_EST_CADASTRAL_FAM)  AS ANY_EST_FAM,

      -- Alguma família com estado 3?
      MAX(CASE WHEN F.CO_EST_CADASTRAL_FAM  = 3 THEN 1 ELSE 0 END) AS FL_FAM_3,

      -- Alguma pessoa com estado 3?
      MAX(CASE WHEN P.CO_EST_CADASTRAL_MEMB = 3 THEN 1 ELSE 0 END) AS FL_PESSOA_3

  FROM docs_map dm
  LEFT JOIN P_CADASTRO_ODS_202512.TB_PESSOA_04  AS P
    ON P.CO_CHV_NATURAL_PESSOA = dm.CO_CHV_NATURAL_PESSOA
  LEFT JOIN P_CADASTRO_ODS_202512.TB_FAMILIA_01 AS F
    ON F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
  GROUP BY 1
),

-------------------------------------------------------------------------------
-- 2.3) Escolha da família "vigente" por CPF:
--      SOMENTE ocorrências com pessoa=3 e família=3
--      e prioriza a mais recente (DT_ATUAL_MEMB / DT_ATUALIZACAO_FAM).
-------------------------------------------------------------------------------
pessoa_familia_ativa AS (
  SELECT
      dm.CPF_NUM,
      P.CO_CHV_NATURAL_PESSOA,
      P.CO_FAMILIAR_FAM,
      P.CO_EST_CADASTRAL_MEMB,
      F.CO_EST_CADASTRAL_FAM,
      P.DT_ATUAL_MEMB,
      F.DT_ATUALIZACAO_FAM,
      ROW_NUMBER() OVER (
        PARTITION BY dm.CPF_NUM
        ORDER BY
          P.DT_ATUAL_MEMB      DESC,
          F.DT_ATUALIZACAO_FAM DESC,
          P.CO_CHV_NATURAL_PESSOA
      ) AS RN
  FROM docs_map dm
  JOIN P_CADASTRO_ODS_202512.TB_PESSOA_04  AS P
    ON P.CO_CHV_NATURAL_PESSOA = dm.CO_CHV_NATURAL_PESSOA
  JOIN P_CADASTRO_ODS_202512.TB_FAMILIA_01 AS F
    ON F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
  WHERE P.CO_EST_CADASTRAL_MEMB = 3   -- pessoa ativa
    AND F.CO_EST_CADASTRAL_FAM = 3    -- família cadastrada
),

familia_vigente_por_cpf AS (
  SELECT
      CPF_NUM,
      CO_CHV_NATURAL_PESSOA,
      CO_FAMILIAR_FAM
  FROM pessoa_familia_ativa
  WHERE RN = 1       -- pega apenas a ocorrência vigente por CPF
),

-------------------------------------------------------------------------------
-- 2.4) Famílias na folha do Bolsa Família (qualquer situação) no mês alvo
-------------------------------------------------------------------------------
folha_any AS (
  SELECT DISTINCT FOL.CO_FAMILIAR
  FROM P_DEBEN_ACC.VW_FOLHA_PAGAMENTO AS FOL
  WHERE FOL.RF_FOLHA = 202601      -- <<< AJUSTE RF_FOLHA (normalmente ODS+1)
),

-------------------------------------------------------------------------------
-- 2.5) Famílias na fila de pré-habilitação no mesmo RF_FOLHA
-------------------------------------------------------------------------------
pre_any AS (
  SELECT DISTINCT PRE.CO_FAMILIAR
  FROM P_DEBEN_ACC.VW_PRE_HABILITACAO_PBF AS PRE
  WHERE PRE.RF_FOLHA = 202512      -- <<< AJUSTE RF_FOLHA (normalmente ODS+1)
),

-------------------------------------------------------------------------------
-- 2.6) PBF e Pré-habilitado por CPF, usando APENAS a família vigente
-------------------------------------------------------------------------------
pbf_pre_por_cpf AS (
  SELECT
      fv.CPF_NUM,
      CASE WHEN fa.CO_FAMILIAR IS NOT NULL THEN 1 ELSE 0 END AS FL_PBF,
      CASE WHEN pr.CO_FAMILIAR IS NOT NULL THEN 1 ELSE 0 END AS FL_PRE_HAB
  FROM familia_vigente_por_cpf fv
  LEFT JOIN folha_any fa
    ON fa.CO_FAMILIAR = fv.CO_FAMILIAR_FAM
  LEFT JOIN pre_any pr
    ON pr.CO_FAMILIAR = fv.CO_FAMILIAR_FAM
)

-------------------------------------------------------------------------------
-- 3) SELECT FINAL: junta lista de CPFs com flags CADÚNICO / PBF / PRÉ
-------------------------------------------------------------------------------
SELECT
    V.NOME,

    -- CPF com 11 dígitos (preserva zeros à esquerda)
    LPAD(
      OTRANSLATE(TRIM(CAST(V.CPF_NUM AS VARCHAR(20))), ' .-/', ''),
      11,
      '0'
    ) AS CPF,

    /* 3.1) CADUNICO_ATIVO:
           pessoa=3 E existe família com estado 3 no ODS */
    CASE 
      WHEN COALESCE(B.FL_PESSOA_3,0) = 1
       AND COALESCE(B.FL_FAM_3,0)    = 1
      THEN 'SIM'
      ELSE 'NAO'
    END AS CADUNICO_ATIVO,

    /* 3.2) CADUNICO_PRESENCA:
           CPF tem pessoa vinculada em família com estado 3
           (mesmo que a pessoa não esteja em estado 3) */
    CASE 
      WHEN COALESCE(B.FL_TEM_PESSOA,0) = 1
       AND COALESCE(B.FL_FAM_3,0)      = 1
      THEN 'SIM'
      ELSE 'NAO'
    END AS CADUNICO_PRESENCA,

    /* 3.3) PBF:
           Família VIGENTE (pessoa=3, família=3) está na folha? */
    CASE 
      WHEN COALESCE(PP.FL_PBF,0) = 1 THEN 'SIM'
      ELSE 'NAO'
    END AS PBF,

    /* 3.4) PRE_HABILITADO:
           Família VIGENTE está na pré-habilitação? */
    CASE 
      WHEN COALESCE(PP.FL_PRE_HAB,0) = 1 THEN 'SIM'
      ELSE 'NAO'
    END AS PRE_HABILITADO,

    /* 3.5) Diagnóstico CADÚNICO (por que não está ativo?) */
    CASE 
      WHEN COALESCE(B.FL_DOC_ENCONTRADO,0) = 0 THEN 'CPF NÃO ENCONTRADO NO DOC_05'
      WHEN COALESCE(B.FL_TEM_PESSOA,0)     = 0 THEN 'CPF SEM PESSOA VINCULADA NO ODS'
      WHEN COALESCE(B.FL_FAM_3,0)          = 0 THEN 'NENHUMA FAMÍLIA COM ESTADO 3 NO ODS'
      WHEN COALESCE(B.FL_PESSOA_3,0)       = 0 THEN 'NENHUMA PESSOA COM ESTADO 3 NO ODS'
      ELSE 'OK'
    END AS MOTIVO_CADUNICO,

    /* 3.6) Diagnóstico PBF (por que não está no programa?) */
    CASE 
      WHEN COALESCE(B.FL_PESSOA_3,0) = 0 THEN 'SEM PESSOA EM ESTADO 3 → NÃO ELEGÍVEL PARA PBF'
      WHEN COALESCE(B.FL_FAM_3,0)    = 0 THEN 'SEM FAMÍLIA EM ESTADO 3 → NÃO ELEGÍVEL PARA PBF'
      WHEN COALESCE(PP.FL_PBF,0)     = 0 THEN 'FAMÍLIA VIGENTE NÃO ENCONTRADA NA FOLHA'
      ELSE 'OK'
    END AS MOTIVO_PBF,

    /* 3.7) DEBUG: estados máximos encontrados no ODS */
    B.ANY_EST_PESSOA AS DEBUG_CO_EST_CADASTRAL_MEMB,
    B.ANY_EST_FAM    AS DEBUG_CO_EST_CADASTRAL_FAM

FROM vt_lista_cpf V
LEFT JOIN base_por_cpf    B  ON B.CPF_NUM  = V.CPF_NUM
LEFT JOIN pbf_pre_por_cpf PP ON PP.CPF_NUM = V.CPF_NUM
ORDER BY 1;
 
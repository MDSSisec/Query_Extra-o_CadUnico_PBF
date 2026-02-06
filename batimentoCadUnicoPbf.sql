/* ============================================================================
   OBJETIVO:
     Para uma lista (NOME, CPF), marcar:
       - CADUNICO_ATIVO     : pessoa=3 e família (CO_EST_CADASTRAL_FAM) = 3
       - CADUNICO_PRESENCA  : pessoa existe no CadÚnico em família=3 (não exige pessoa=3)
       - PBF                : família na folha (qualquer situação) no RF_FOLHA alvo
     + Colunas de diagnóstico para entender divergências.
   AJUSTES:
     - Troque P_CADASTRO_ODS_202511 pelo ANOMES ODS desejado
     - Ajuste RF_FOLHA (normalmente ODS+1)
    
   ============================================================================ */

DROP TABLE vt_lista_cpf;

DATABASE P_CADASTRO_ODS_202510;     -- ODS de referência do universo
-- RF_FOLHA alvo na CTE folha_any (abaixo): 202510

/* 1) Tabela volátil de entrada */
CREATE VOLATILE TABLE vt_lista_cpf (
  NOME     VARCHAR(200) CHARACTER SET UNICODE,
  CPF_RAW  VARCHAR(64)  CHARACTER SET LATIN,
  CPF_NUM  DECIMAL(20,0)
) PRIMARY INDEX (CPF_NUM)
ON COMMIT PRESERVE ROWS;

-- EXEMPLOS (substitua pelos seus INSERTs/IMPORT):
-- INSERT INTO vt_lista_cpf (NOME, CPF_RAW) VALUES ('MARIA DA SILVA','123.456.789-01');

-- Higieniza CPF
UPDATE vt_lista_cpf
SET CPF_NUM =
  CASE
    WHEN OTRANSLATE(CPF_RAW, ' .-/', '') IS NULL OR OTRANSLATE(CPF_RAW, ' .-/', '') = '' THEN NULL
    ELSE CAST(OTRANSLATE(CPF_RAW, ' .-/', '') AS DECIMAL(20,0))
  END;

/* 2) Mapeamento CPF -> pessoa (DOC_05) */
WITH docs_map AS (
  SELECT DISTINCT
         CAST(D.NU_CPF_PESSOA AS DECIMAL(20,0)) AS CPF_NUM,
         D.CO_CHV_NATURAL_PESSOA
  FROM  P_CADASTRO_ODS_202511.TB_DOCUMENTO_05 AS D
  WHERE D.NU_CPF_PESSOA IS NOT NULL
),

/* 3) Enriquecimento por CPF com dados de pessoa e família */
base_por_cpf AS (
  SELECT
      dm.CPF_NUM,
      MAX(1)                                                  AS FL_DOC_ENCONTRADO,
      /* Flags de existência/estados */
      MAX(CASE WHEN P.CO_CHV_NATURAL_PESSOA IS NOT NULL THEN 1 ELSE 0 END)        AS FL_TEM_PESSOA,
      MAX(CASE WHEN F.CO_FAMILIAR_FAM      IS NOT NULL THEN 1 ELSE 0 END)         AS FL_TEM_FAMILIA,
      /* Estados máximos para "debug" (não são somas, apenas um representativo) */
      MAX(P.CO_EST_CADASTRAL_MEMB)                                               AS ANY_EST_PESSOA,
      MAX(F.CO_EST_CADASTRAL_FAM)                                                AS ANY_EST_FAM,
      /* Flags de interesse */
      MAX(CASE WHEN F.CO_EST_CADASTRAL_FAM = 3 THEN 1 ELSE 0 END)                 AS FL_FAM_3,
      MAX(CASE WHEN P.CO_EST_CADASTRAL_MEMB = 3 THEN 1 ELSE 0 END)                AS FL_PESSOA_3
  FROM docs_map dm
  LEFT JOIN P_CADASTRO_ODS_202511.TB_PESSOA_04  AS P
    ON P.CO_CHV_NATURAL_PESSOA = dm.CO_CHV_NATURAL_PESSOA
  LEFT JOIN P_CADASTRO_ODS_202511.TB_FAMILIA_01 AS F
    ON F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
  GROUP BY 1
),

/* 4) Famílias na folha (qualquer situação) no mês alvo */
folha_any AS (
  SELECT DISTINCT FOL.CO_FAMILIAR
  FROM P_DEBEN_ACC.VW_FOLHA_PAGAMENTO AS FOL
  WHERE FOL.RF_FOLHA = 202511   -- <<< AJUSTE RF_FOLHA (ODS+1)
),

/* 5) PBF por CPF: existe família do CPF na folha? */
pbf_por_cpf AS (
  SELECT
      dm.CPF_NUM,
      MAX(CASE WHEN fa.CO_FAMILIAR IS NOT NULL THEN 1 ELSE 0 END) AS FL_PBF
  FROM docs_map dm
  LEFT JOIN P_CADASTRO_ODS_202511.TB_PESSOA_04  AS P
    ON P.CO_CHV_NATURAL_PESSOA = dm.CO_CHV_NATURAL_PESSOA
  LEFT JOIN P_CADASTRO_ODS_202511.TB_FAMILIA_01 AS F
    ON F.CO_FAMILIAR_FAM = P.CO_FAMILIAR_FAM
  LEFT JOIN folha_any fa
    ON fa.CO_FAMILIAR = F.CO_FAMILIAR_FAM
  GROUP BY 1
)

/* 6) Resultado final com três flags e diagnóstico */
SELECT
    V.NOME,

    -- CPF 11 dígitos (preserva zeros à esquerda)
    -- SUBSTR('00000000000' || TRIM(CAST(V.CPF_NUM AS VARCHAR(20))),
       --    CHAR_LENGTH('00000000000' || TRIM(CAST(V.CPF_NUM AS VARCHAR(20)))) - 10, 11) AS CPF,
       
    LPAD(OTRANSLATE(TRIM(CAST(V.CPF_NUM AS VARCHAR(20))), ' .-/', ''), 11, '0') AS CPF,

    /* 6.1) CADUNICO_ATIVO: seu critério original (pessoa=3 E família=3) */
    CASE WHEN COALESCE(B.FL_PESSOA_3,0)=1 AND COALESCE(B.FL_FAM_3,0)=1
         THEN 'SIM' ELSE 'NAO' END AS CADUNICO_ATIVO,

    /* 6.2) CADUNICO_PRESENCA: pessoa existe no CadÚnico em família=3 (NÃO exige pessoa=3) */
    CASE WHEN COALESCE(B.FL_TEM_PESSOA,0)=1 AND COALESCE(B.FL_FAM_3,0)=1
         THEN 'SIM' ELSE 'NAO' END AS CADUNICO_PRESENCA,

    /* 6.3) PBF: família do CPF na folha (qualquer situação) */
    CASE WHEN COALESCE(PB.FL_PBF,0)=1
         THEN 'SIM' ELSE 'NAO' END AS PBF,

    /* 6.4) Diagnóstico (opcional) - ajuda a explicar "NAO" */
    CASE WHEN COALESCE(B.FL_DOC_ENCONTRADO,0)=0 THEN 'CPF NÃO ENCONTRADO NO DOC_05'
         WHEN COALESCE(B.FL_TEM_PESSOA,0)=0      THEN 'CPF SEM PESSOA VINCULADA'
         WHEN COALESCE(B.FL_FAM_3,0)=0           THEN 'FAMÍLIA ≠ 3 NO ANOMES ODS'
         WHEN COALESCE(B.FL_PESSOA_3,0)=0        THEN 'PESSOA ≠ 3 NO ANOMES ODS'
         ELSE 'OK'
    END AS MOTIVO_CADUNICO,

    CASE WHEN COALESCE(PB.FL_PBF,0)=0 THEN 'FAMÍLIA NÃO ENCONTRADA NA FOLHA'
         ELSE 'OK'
    END AS MOTIVO_PBF,

    /* (debug) Estados máximos "vistos" no ODS para ajudar auditoria */
    B.ANY_EST_PESSOA AS DEBUG_CO_EST_CADASTRAL_MEMB,
    B.ANY_EST_FAM    AS DEBUG_CO_EST_CADASTRAL_FAM

FROM vt_lista_cpf V
LEFT JOIN base_por_cpf B  ON B.CPF_NUM  = V.CPF_NUM
LEFT JOIN pbf_por_cpf PB  ON PB.CPF_NUM = V.CPF_NUM
ORDER BY 1;

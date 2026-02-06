/* ============================================================================
   ConsultaDocPessoaFamiliaExclusaoBFPrefHabPorCPF
   ----------------------------------------------------------------------------
   OBJETIVO:
     - Montar um dossiê completo de Documento + Pessoa + Família no CadÚnico
       para um CPF específico, incluindo:
         * Dados de DOC → PESSOA → FAMÍLIA
         * Situação cadastral da família e da pessoa
         * UF e CODIBGE da família
         * Informação de exclusão da pessoa (TB_PESSOA_EXCLUIDA_19)
         * Presença do CO_FAMILIAR na folha do Bolsa Família (mês seguinte)
         * Presença do CO_FAMILIAR na fila de Pré-Habilitação (mês seguinte)

   PARÂMETROS:
     - Schema ODS usado abaixo: P_CADASTRO_ODS_202510
     - Mês de referência da folha: 202511 (ANOMES_ODS + 1)

   IMPORTANTE:
     - A mesma pessoa pode ter mais de um CO_FAMILIAR_FAM (histórico).
       Esta query retorna TODAS as combinações DOC–PESSOA–FAMÍLIA
       ligadas ao CPF informado, sem deduplicar.
   ============================================================================ */

DATABASE P_CADASTRO_ODS_202512;

/* 1) Famílias presentes na folha do Bolsa Família (mês seguinte) */
WITH folha_bf AS (
    SELECT DISTINCT
           FOL.CO_FAMILIAR
    FROM P_DEBEN_ACC.VW_FOLHA_PAGAMENTO FOL
    WHERE FOL.RF_FOLHA = 202601       -- <<< AJUSTE AQUI O RF_FOLHA (ANOMES_ODS + 1)
),

/* 2) Famílias presentes na fila de Pré-Habilitação (mesmo RF_FOLHA) */
pre_hab AS (
    SELECT DISTINCT
           PRE.CO_FAMILIAR
    FROM P_DEBEN_ACC.VW_PRE_HABILITACAO_PBF PRE
    WHERE PRE.RF_FOLHA = 202512       -- <<< AJUSTE AQUI O RF_FOLHA (ANOMES_ODS + 1)
)

SELECT 
    /* ========== TB_DOCUMENTO_05 ========== */
    DOC.CO_FAMILIAR_FAM           AS DOC_CO_FAMILIAR_FAM,
    DOC.CO_CHV_NATURAL_PESSOA     AS DOC_CO_CHV_NATURAL_PESSOA,
    DOC.NU_CPF_PESSOA             AS DOC_NU_CPF_PESSOA,
    DOC.CO_CERTIDAO_CIVIL_PESSOA  AS DOC_CO_CERTIDAO_CIVIL_PESSOA,
    DOC.NO_CARTORIO_PESSOA        AS DOC_NO_CARTORIO_PESSOA,
    DOC.NU_IDENTIDADE_PESSOA      AS DOC_NU_IDENTIDADE_PESSOA,
    DOC.SG_UF_IDENT_PESSOA        AS DOC_SG_UF_IDENT_PESSOA,
    DOC.NU_TITULO_ELEITOR_PESSOA  AS DOC_NU_TITULO_ELEITOR_PESSOA,

    /* ========== TB_PESSOA_04 ========== */
    P.CO_FAMILIAR_FAM             AS PES_CO_FAMILIAR_FAM,
    P.CO_CHV_NATURAL_PESSOA       AS PES_CO_CHV_NATURAL_PESSOA,
    P.DT_CADASTRAMENTO_MEMB       AS PES_DT_CADASTRAMENTO_MEMB,
    P.DT_ATUAL_MEMB               AS PES_DT_ATUAL_MEMB,
    P.CO_EST_CADASTRAL_MEMB       AS PES_CO_EST_CADASTRAL_MEMB,
    P.NO_PESSOA                   AS PES_NO_PESSOA,
    P.NU_NIS_PESSOA               AS PES_NU_NIS_PESSOA,
    P.NO_APELIDO_PESSOA           AS PES_NO_APELIDO_PESSOA,
    P.DT_NASC_PESSOA              AS PES_DT_NASC_PESSOA,
    P.CO_ORIGEM_FAMILIA_PESSOA    AS PES_CO_ORIGEM_FAMILIA_PESSOA,
    P.IN_ORIGEM_ALTERACAO_PESSOA  AS PES_IN_ORIGEM_ALTERACAO_PESSOA,
    P.CO_CHV_NAT_PES_ATUAL        AS PES_CO_CHV_NAT_PES_ATUAL,
    P.CO_CHV_NAT_PES_ORIGINAL     AS PES_CO_CHV_NAT_PES_ORIGINAL,
    P.NU_NIS_ORIGINAL             AS PES_NU_NIS_ORIGINAL,
    P.IN_TRANSFERENCIA_PESSOA     AS PES_IN_TRANSFERENCIA_PESSOA,

    /* ========== TB_FAMILIA_01 ========== */
    F.CO_FAMILIAR_FAM             AS FAM_CO_FAMILIAR_FAM,
    F.DT_CADASTRO_FAM             AS FAM_DT_CADASTRO_FAM,
    F.DT_ULT_ATUAL_FAM            AS FAM_DT_ULT_ATUAL_FAM,
    F.CO_EST_CADASTRAL_FAM        AS FAM_CO_EST_CADASTRAL_FAM,
    F.IN_CADASTRO_VALIDO_FAM      AS FAM_IN_CADASTRO_VALIDO_FAM,
    F.CO_CONDICAO_CADASTRO_FAM    AS FAM_CO_CONDICAO_CADASTRO_FAM,
    F.CO_MODALIDADE_OPER_FAM      AS FAM_CO_MODALIDADE_OPER_FAM,
    F.CO_ORIGEM_FAMILIA_FAM       AS FAM_CO_ORIGEM_FAMILIA_FAM,
    F.DT_CDSTR_ATUAL_FMLA         AS FAM_DT_CDSTR_ATUAL_FMLA,
    F.IN_FAM_ALTERADA_V7          AS FAM_IN_FAM_ALTERADA_V7,
    F.DT_ATUALIZACAO_FAM          AS FAM_DT_ATUALIZACAO_FAM,
    
    /* ========== TB_CONTATO_09 ========== */
    CONT.NU_DDD_CONTATO_1_FAM   AS CONT_DDD_1,
    CONT.NU_TEL_CONTATO_1_FAM   AS CONT_TEL_1,
    CONT.NU_DDD_CONTATO_2_FAM   AS CONT_DDD_2,
    CONT.NU_TEL_CONTATO_2_FAM   AS CONT_TEL_2,
    CONT.IN_TIPO_EMAIL_FAM      AS CONT_TIPO_EMAIL,
    CONT.DS_EMAIL_FAM           AS CONT_EMAIL,


    /* ===== LOCALIZAÇÃO (UF / CODIBGE) ===== */
    CASE F.CO_MUNIC_IBGE_2_FAM
         WHEN 11 THEN 'RO' WHEN 12 THEN 'AC' WHEN 13 THEN 'AM' WHEN 14 THEN 'RR'
         WHEN 15 THEN 'PA' WHEN 16 THEN 'AP' WHEN 17 THEN 'TO' WHEN 21 THEN 'MA'
         WHEN 22 THEN 'PI' WHEN 23 THEN 'CE' WHEN 24 THEN 'RN' WHEN 25 THEN 'PB'
         WHEN 26 THEN 'PE' WHEN 27 THEN 'AL' WHEN 28 THEN 'SE' WHEN 29 THEN 'BA'
         WHEN 31 THEN 'MG' WHEN 32 THEN 'ES' WHEN 33 THEN 'RJ' WHEN 35 THEN 'SP'
         WHEN 41 THEN 'PR' WHEN 42 THEN 'SC' WHEN 43 THEN 'RS' WHEN 50 THEN 'MS'
         WHEN 51 THEN 'MT' WHEN 52 THEN 'GO' WHEN 53 THEN 'DF'
         ELSE 'Não Informado'
    END AS UF,

    CAST(F.CO_MUNIC_IBGE_2_FAM AS CHAR(2)) ||
    CAST(F.CO_MUNIC_IBGE_5_FAM AS CHAR(5)) AS CODIBGE,

    /* ========== TB_PESSOA_EXCLUIDA_19 ========== */
    EXC.DT_EXCLUSAO_PESSOA        AS EXC_DT_EXCLUSAO_PESSOA,
    EXC.CO_MOTIVO_EXCLUSAO        AS EXC_CO_MOTIVO_EXCLUSAO,

    /* ========== FLAGS DE BOLSA FAMÍLIA E PRÉ-HAB ========== */
    CASE 
        WHEN FB.CO_FAMILIAR IS NOT NULL THEN 'SIM'
        ELSE 'NAO'
    END AS FAMILIA_NA_FOLHA_BF,

    CASE 
        WHEN PH.CO_FAMILIAR IS NOT NULL THEN 'SIM'
        ELSE 'NAO'
    END AS FAMILIA_PRE_HABILITADA

FROM P_CADASTRO_ODS_202510.TB_DOCUMENTO_05 DOC

/* JOIN com Pessoa (chave natural da pessoa) */
JOIN P_CADASTRO_ODS_202510.TB_PESSOA_04 P
  ON DOC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA

/* JOIN com Família (pode haver mais de uma por pessoa ao longo do histórico) */
JOIN P_CADASTRO_ODS_202510.TB_FAMILIA_01 F
  ON P.CO_FAMILIAR_FAM = F.CO_FAMILIAR_FAM

/* Exclusão da pessoa – histórico */
LEFT JOIN P_CADASTRO_ODS_202510.TB_PESSOA_EXCLUIDA_19 EXC
  ON EXC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA

/* Presença na folha do BF (mês seguinte) */
LEFT JOIN folha_bf FB
  ON FB.CO_FAMILIAR = F.CO_FAMILIAR_FAM

/* Presença na fila de Pré-Habilitação (mês seguinte) */
LEFT JOIN pre_hab PH
  ON PH.CO_FAMILIAR = F.CO_FAMILIAR_FAM
  
/* Contatos da família */
LEFT JOIN P_CADASTRO_ODS_202510.TB_CONTATO_09 CONT
  ON CONT.CO_FAMILIAR_FAM = F.CO_FAMILIAR_FAM


--WHERE DOC.NU_CPF_PESSOA = '07800050580'  -- <<< SUBSTITUA PELO CPF DESEJADO
--;

-- Para consultar mais de um CPF, comente a linha acima e descomente todas as linhas abaixo

 WHERE DOC.NU_CPF_PESSOA IN (
 		'38513107808',
'55677612871',
'32617455840',
'24884892801',
'50500229830',
'34052444809',
'29205253871',
'41663461805',
'39579819807',
'43057207871',
'19541721842',
'03841508375',
'13546477421',
'16177397824',
'45689707848',
'38655554898',
'42902201850'

 )

 ORDER BY DOC.NU_CPF_PESSOA;


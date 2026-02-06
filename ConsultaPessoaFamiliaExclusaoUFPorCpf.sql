/* ============================================================================
   Consulta dados de documento, pessoa e família no CadÚnico (ODS 202510),
   monta UF e código IBGE do município e verifica histórico de exclusão
   da pessoa, retornando um dossiê completo para o CPF informado.
============================================================================ */


SELECT 
    /* ========== TB_DOCUMENTO_05 ========== */
    DOC.CO_FAMILIAR_FAM                AS DOC_CO_FAMILIAR_FAM,
    DOC.CO_CHV_NATURAL_PESSOA          AS DOC_CO_CHV_NATURAL_PESSOA,
    DOC.NU_CPF_PESSOA                  AS DOC_NU_CPF_PESSOA,
    
    /* ========== TB_PESSOA_04 ========== */
    P.CO_FAMILIAR_FAM                  AS PES_CO_FAMILIAR_FAM,
    P.CO_CHV_NATURAL_PESSOA            AS PES_CO_CHV_NATURAL_PESSOA,
    P.DT_CADASTRAMENTO_MEMB            AS PES_DT_CADASTRAMENTO_MEMB,
    P.DT_ATUAL_MEMB                    AS PES_DT_ATUAL_MEMB,
    P.CO_EST_CADASTRAL_MEMB            AS PES_CO_EST_CADASTRAL_MEMB,
    P.NO_PESSOA                        AS PES_NO_PESSOA,
    P.NU_NIS_PESSOA                    AS PES_NU_NIS_PESSOA,
    P.NO_APELIDO_PESSOA                AS PES_NO_APELIDO_PESSOA,
    P.DT_NASC_PESSOA                   AS PES_DT_NASC_PESSOA,
    P.CO_ORIGEM_FAMILIA_PESSOA         AS PES_CO_ORIGEM_FAMILIA_PESSOA,
    P.IN_ORIGEM_ALTERACAO_PESSOA       AS PES_IN_ORIGEM_ALTERACAO_PESSOA,
    P.CO_CHV_NAT_PES_ATUAL             AS PES_CO_CHV_NAT_PES_ATUAL,
    P.CO_CHV_NAT_PES_ORIGINAL          AS PES_CO_CHV_NAT_PES_ORIGINAL,
    P.NU_NIS_ORIGINAL                  AS PES_NU_NIS_ORIGINAL,
    P.IN_TRANSFERENCIA_PESSOA          AS PES_IN_TRANSFERENCIA_PESSOA,

    /* ========== TB_FAMILIA_01 ========== */
    F.CO_FAMILIAR_FAM                  AS FAM_CO_FAMILIAR_FAM,
    F.DT_CADASTRO_FAM                  AS FAM_DT_CADASTRO_FAM,
    F.DT_ULT_ATUAL_FAM                 AS FAM_DT_ULT_ATUAL_FAM,
    F.CO_EST_CADASTRAL_FAM             AS FAM_CO_EST_CADASTRAL_FAM,
    F.IN_CADASTRO_VALIDO_FAM           AS FAM_IN_CADASTRO_VALIDO_FAM,
    F.CO_CONDICAO_CADASTRO_FAM         AS FAM_CO_CONDICAO_CADASTRO_FAM,

    /* ===== LOCALIZAÇÃO ===== */
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

    /* Município (código de 7 dígitos) */
    CAST(F.CO_MUNIC_IBGE_2_FAM AS CHAR(2)) ||
    CAST(F.CO_MUNIC_IBGE_5_FAM AS CHAR(5))  AS CODIBGE,

    /* ========== TB_PESSOA_EXCLUIDA_19 ========== */
    EXC.DT_EXCLUSAO_PESSOA             AS EXC_DT_EXCLUSAO_PESSOA,
    EXC.CO_MOTIVO_EXCLUSAO             AS EXC_CO_MOTIVO_EXCLUSAO

FROM P_CADASTRO_ODS_202510.TB_DOCUMENTO_05 DOC

JOIN P_CADASTRO_ODS_202510.TB_PESSOA_04 P
  ON DOC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA

JOIN P_CADASTRO_ODS_202510.TB_FAMILIA_01 F
  ON P.CO_FAMILIAR_FAM = F.CO_FAMILIAR_FAM

/* JOIN CORRETO: chave natural da pessoa (não por família) */
LEFT JOIN P_CADASTRO_ODS_202510.TB_PESSOA_EXCLUIDA_19 EXC
  ON EXC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA

WHERE DOC.NU_CPF_PESSOA = '00704117517';  -- Consulta para apenas um CPF

-- Para consultar mais de um CPF, comente a linha acima e descomente todas as linhas abaixo

-- WHERE DOC.NU_CPF_PESSOA IN (
--      '00704117517',
-- '11281490440',
-- '02954792213',
-- '05718290407',
-- )

-- ORDER BY DOC.NU_CPF_PESSOA;

-- ============================================================================
-- CONSULTA: Detalhamento de Documento, Pessoa e Família por CPF
--
-- OBJETIVO
--   Retornar informações completas e consolidadas das tabelas:
--     • TB_DOCUMENTO_05  (Documento / CPF)
--     • TB_PESSOA_04     (Dados cadastrais da pessoa)
--     • TB_FAMILIA_01    (Dados cadastrais da família)
--
--   A consulta permite:
--     • Consulta pontual por um CPF
--     • Consulta simplificada (menos colunas)
--     • Consulta por múltiplos CPFs
--
-- BASE UTILIZADA
--   ODS CadÚnico - P_CADASTRO_ODS_202510
--
-- RELACIONAMENTOS
--   TB_DOCUMENTO_05.CO_CHV_NATURAL_PESSOA
--       → TB_PESSOA_04.CO_CHV_NATURAL_PESSOA
--   TB_PESSOA_04.CO_FAMILIAR_FAM
--       → TB_FAMILIA_01.CO_FAMILIAR_FAM
--
-- OBSERVAÇÕES
--   • Cada CPF pode ter histórico, mas a consulta retorna
--     os registros conforme as chaves atuais na base.
--   • Ajustar o CPF ou lista de CPFs no WHERE conforme necessidade.
-- ============================================================================


-- ============================================================================
-- VERSÃO COMPLETA (com prefixos para identificar a origem das colunas)
--   Indicada para:
--     • Auditoria
--     • Análise técnica
--     • Validação de chaves e datas
-- ============================================================================

SELECT 
    -- ==========================
    -- TB_DOCUMENTO_05 (Documento)
    -- ==========================
    DOC.CO_FAMILIAR_FAM              AS DOC_CO_FAMILIAR_FAM,
    DOC.CO_CHV_NATURAL_PESSOA        AS DOC_CO_CHV_NATURAL_PESSOA,
    DOC.NU_CPF_PESSOA                AS DOC_NU_CPF_PESSOA,
    
    -- ======================
    -- TB_PESSOA_04 (Pessoa)
    -- ======================
    P.CO_FAMILIAR_FAM                AS PES_CO_FAMILIAR_FAM,
    P.CO_CHV_NATURAL_PESSOA          AS PES_CO_CHV_NATURAL_PESSOA,
    P.DT_CADASTRAMENTO_MEMB          AS PES_DT_CADASTRAMENTO_MEMB,
    P.DT_ATUAL_MEMB                  AS PES_DT_ATUAL_MEMB,
    P.CO_EST_CADASTRAL_MEMB          AS PES_CO_EST_CADASTRAL_MEMB,
    P.NO_PESSOA                      AS PES_NO_PESSOA,
    P.NU_NIS_PESSOA                  AS PES_NU_NIS_PESSOA,
    P.NO_APELIDO_PESSOA              AS PES_NO_APELIDO_PESSOA,
    P.DT_NASC_PESSOA                 AS PES_DT_NASC_PESSOA,
    P.CO_ORIGEM_FAMILIA_PESSOA       AS PES_CO_ORIGEM_FAMILIA_PESSOA,
    P.IN_ORIGEM_ALTERACAO_PESSOA     AS PES_IN_ORIGEM_ALTERACAO_PESSOA,
    P.CO_CHV_NAT_PES_ATUAL           AS PES_CO_CHV_NAT_PES_ATUAL,
    P.CO_CHV_NAT_PES_ORIGINAL        AS PES_CO_CHV_NAT_PES_ORIGINAL,
    P.NU_NIS_ORIGINAL                AS PES_NU_NIS_ORIGINAL,
    P.IN_TRANSFERENCIA_PESSOA        AS PES_IN_TRANSFERENCIA_PESSOA,
    
    -- ========================
    -- TB_FAMILIA_01 (Família)
    -- ========================
    F.CO_FAMILIAR_FAM                AS FAM_CO_FAMILIAR_FAM,
    F.DT_CADASTRO_FAM                AS FAM_DT_CADASTRO_FAM,
    F.DT_ULT_ATUAL_FAM               AS FAM_DT_ULT_ATUAL_FAM,
    F.CO_EST_CADASTRAL_FAM           AS FAM_CO_EST_CADASTRAL_FAM,
    F.IN_CADASTRO_VALIDO_FAM         AS FAM_IN_CADASTRO_VALIDO_FAM,
    F.CO_CONDICAO_CADASTRO_FAM       AS FAM_CO_CONDICAO_CADASTRO_FAM,
    F.CO_MODALIDADE_OPER_FAM         AS FAM_CO_MODALIDADE_OPER_FAM,
    F.CO_ORIGEM_FAMILIA_FAM          AS FAM_CO_ORIGEM_FAMILIA_FAM,
    F.DT_CDSTR_ATUAL_FMLA            AS FAM_DT_CDSTR_ATUAL_FMLA,
    F.IN_FAM_ALTERADA_V7             AS FAM_IN_FAM_ALTERADA_V7,
    F.DT_ATUALIZACAO_FAM             AS FAM_DT_ATUALIZACAO_FAM

FROM P_CADASTRO_ODS_202510.TB_DOCUMENTO_05 DOC

-- Relaciona Documento → Pessoa pela chave natural
JOIN P_CADASTRO_ODS_202510.TB_PESSOA_04 P
  ON DOC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA

-- Relaciona Pessoa → Família
JOIN P_CADASTRO_ODS_202510.TB_FAMILIA_01 F
  ON P.CO_FAMILIAR_FAM = F.CO_FAMILIAR_FAM

-- Filtro por CPF (consulta pontual)
WHERE DOC.NU_CPF_PESSOA = '53562860587';
-- ⬅️ Substituir pelo CPF desejado



-- ============================================================================
-- VERSÃO SIMPLIFICADA
--   Indicada para:
--     • Consulta rápida
--     • Análise operacional
--     • Uso em relatórios
-- ============================================================================

SELECT 
    -- Documento
    DOC.CO_FAMILIAR_FAM,
    DOC.CO_CHV_NATURAL_PESSOA,
    DOC.NU_CPF_PESSOA,
    
    -- Pessoa
    P.DT_CADASTRAMENTO_MEMB,
    P.DT_ATUAL_MEMB,
    P.CO_EST_CADASTRAL_MEMB,
    P.NO_PESSOA,
    P.NU_NIS_PESSOA,
    P.NO_APELIDO_PESSOA,
    P.DT_NASC_PESSOA,
    P.CO_ORIGEM_FAMILIA_PESSOA,
    P.IN_ORIGEM_ALTERACAO_PESSOA,
    P.CO_CHV_NAT_PES_ATUAL,
    P.CO_CHV_NAT_PES_ORIGINAL,
    P.NU_NIS_ORIGINAL,
    P.IN_TRANSFERENCIA_PESSOA,
    
    -- Família
    F.DT_CADASTRO_FAM,
    F.DT_ULT_ATUAL_FAM,
    F.CO_EST_CADASTRAL_FAM,
    F.IN_CADASTRO_VALIDO_FAM,
    F.CO_CONDICAO_CADASTRO_FAM,
    F.CO_MODALIDADE_OPER_FAM,
    F.CO_ORIGEM_FAMILIA_FAM,
    F.DT_CDSTR_ATUAL_FMLA,
    F.IN_FAM_ALTERADA_V7,
    F.DT_ATUALIZACAO_FAM

FROM P_CADASTRO_ODS_202510.TB_DOCUMENTO_05 DOC
JOIN P_CADASTRO_ODS_202510.TB_PESSOA_04 P
  ON DOC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA
JOIN P_CADASTRO_ODS_202510.TB_FAMILIA_01 F
  ON P.CO_FAMILIAR_FAM = F.CO_FAMILIAR_FAM

WHERE DOC.NU_CPF_PESSOA = '12345678901';
-- ⬅️ Substituir pelo CPF desejado



-- ============================================================================
-- VERSÃO PARA MÚLTIPLOS CPFs
--   Indicada para:
--     • Lotes de validação
--     • Conferência em massa
-- ============================================================================

SELECT 
    DOC.NU_CPF_PESSOA,
    P.NO_PESSOA,
    P.NU_NIS_PESSOA,
    F.CO_FAMILIAR_FAM,

    -- Chave da pessoa
    DOC.CO_CHV_NATURAL_PESSOA        AS DOC_CHAVE_PESSOA,

    -- Datas da pessoa
    P.DT_CADASTRAMENTO_MEMB,
    P.DT_ATUAL_MEMB,
    P.DT_NASC_PESSOA,

    -- Status da pessoa
    P.CO_EST_CADASTRAL_MEMB,
    P.CO_ORIGEM_FAMILIA_PESSOA,
    P.IN_ORIGEM_ALTERACAO_PESSOA,
    P.IN_TRANSFERENCIA_PESSOA,

    -- Chaves históricas
    P.CO_CHV_NAT_PES_ATUAL,
    P.CO_CHV_NAT_PES_ORIGINAL,
    P.NU_NIS_ORIGINAL,

    -- Datas da família
    F.DT_CADASTRO_FAM,
    F.DT_ULT_ATUAL_FAM,
    F.DT_ATUALIZACAO_FAM,
    F.DT_CDSTR_ATUAL_FMLA,

    -- Status da família
    F.CO_EST_CADASTRAL_FAM,
    F.IN_CADASTRO_VALIDO_FAM,
    F.CO_CONDICAO_CADASTRO_FAM,
    F.CO_MODALIDADE_OPER_FAM,
    F.CO_ORIGEM_FAMILIA_FAM,
    F.IN_FAM_ALTERADA_V7

FROM P_CADASTRO_ODS_202510.TB_DOCUMENTO_05 DOC
JOIN P_CADASTRO_ODS_202510.TB_PESSOA_04 P
  ON DOC.CO_CHV_NATURAL_PESSOA = P.CO_CHV_NATURAL_PESSOA
JOIN P_CADASTRO_ODS_202510.TB_FAMILIA_01 F
  ON P.CO_FAMILIAR_FAM = F.CO_FAMILIAR_FAM

WHERE DOC.NU_CPF_PESSOA IN (
    '10914434594',
    '08313913592',
    '08378934535',
    '86718313530',
    '12099623570'
    -- ⬅️ Adicionar mais CPFs conforme necessário
)
ORDER BY DOC.NU_CPF_PESSOA;

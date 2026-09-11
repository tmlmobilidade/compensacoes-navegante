-- ============================================================
-- query_SL_TT.sql — Separação TT (Transtejo) / SL (Soflusa)
-- Fonte: DW_PROC.F_VALIDATIONS
--
-- Método: georreferenciação por RUN_CODE
--   RUN_CODE = 7  → SL (Soflusa / ferry Barreiro)
--   outros RUN_CODEs → TT (Transtejo)
--
-- Replica a metodologia da aba TT_SL do Excel:
-- os totais absolutos (PT) são ancorados ao Recibo B de TT
-- (que agrega TT+SL); os rácios TT/SL vêm desta query.
-- ============================================================


-- ============================================================
-- Query 2b → CORRER ESTE para o pipeline R
-- Agrega por TICKET_CODE + RUN_CODE com as regras da fórmula da colega:
--   - TICKET_OPERATOR_CODE = 31
--   - VALID_TYPE_ID = 0
--   - VALBYPROF = 0
--   - RUN_CODE = 7  → SL (Soflusa / ferry Barreiro)
--   - outros RUN_CODEs (ou != 7) → TT (Transtejo)
-- Alterar DISTRIBUTION_YEAR e DISTRIBUTION_MONTH conforme o mês.
-- ============================================================
SELECT
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    ENTITY_ID,
    RUN_CODE,
    VALID_TYPE_ID,
    VALBYPROF,
    SUM(QNT_VALIDATION) AS PT_VALIDACOES
FROM DW_PROC.F_VALIDATIONS
WHERE DISTRIBUTION_YEAR  = 2026
  AND DISTRIBUTION_MONTH = 5       -- alterar conforme o mês
  AND ENTITY_ID IN (5, 8)          -- 5=TT (Transtejo), 8=SL (Soflusa)
  AND TICKET_OPERATOR_CODE = 31
  AND VALID_TYPE_ID = 0
  AND VALBYPROF = 0
GROUP BY
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    ENTITY_ID,
    RUN_CODE,
    VALID_TYPE_ID,
    VALBYPROF
ORDER BY TICKET_CODE, ENTITY_ID, RUN_CODE;



-- ============================================================
-- Query 2 (referência) — versão granular completa
-- Inclui REF_STOP_ID, ROUTE, VALID_TYPE_ID, VALBYPROF, PROFILENAME.
-- Útil para auditoria/diagnóstico; não necessária para o pipeline R.
-- ============================================================
-- SELECT
--     DISTRIBUTION_YEAR, DISTRIBUTION_MONTH,
--     TICKET_OPERATOR_CODE, TICKET_CODE,
--     VALBYPROF, PROFILENAME,
--     ENTITY_ID, REF_STOP_ID, RUN_CODE, ROUTE, VALID_TYPE_ID,
--     SUM(QNT_VALIDATION)
-- FROM DW_PROC.F_VALIDATIONS
-- WHERE DISTRIBUTION_YEAR = 2026
--   AND DISTRIBUTION_MONTH = 5
--   AND ENTITY_ID IN (5, 8)
-- GROUP BY
--     DISTRIBUTION_YEAR, DISTRIBUTION_MONTH,
--     TICKET_OPERATOR_CODE, TICKET_CODE,
--     VALBYPROF, PROFILENAME,
--     ENTITY_ID, REF_STOP_ID, RUN_CODE, ROUTE, VALID_TYPE_ID;


-- ============================================================
-- Query 1 (diagnóstico) — PT por operador/título, todos os operadores
-- Não necessária para o pipeline R.
-- ============================================================
-- SELECT
--     DISTRIBUTION_YEAR, DISTRIBUTION_MONTH,
--     TICKET_OPERATOR_CODE, TICKET_CODE,
--     ENTITY_ID, VALID_TYPE_ID,
--     SUM(QNT_VALIDATION) AS PT_VALIDACOES
-- FROM DW_PROC.F_VALIDATIONS
-- WHERE DISTRIBUTION_YEAR = 2026
--   AND DISTRIBUTION_MONTH = 5
-- GROUP BY
--     DISTRIBUTION_YEAR, DISTRIBUTION_MONTH,
--     TICKET_OPERATOR_CODE, TICKET_CODE,
--     ENTITY_ID, VALID_TYPE_ID;




-- ============================================================
-- Query 2c → Validações Portal VIVA (Fiscais móveis Carris Metropolitana)
-- ENTITY_ID = 23 (Portal VIVA / validadores móveis de fiscalização)
-- Agrupado por TICKET_CODE e AREA_CM (FLOOR(RUN_CODE / 1000) + 40):
--   1xxx -> 41 (Área 1 / A1)
--   2xxx -> 42 (Área 2 / A2)
--   3xxx -> 43 (Área 3 / A3)
--   4xxx -> 44 (Área 4 / A4)
-- Retorna apenas ~47 linhas (sem risco de truncatura no Oracle SQL Developer).
-- Exportar para INPUT_DIR como entity23_*(timestamp).csv (ex: entity23_202609111609.csv).
-- O script escolhe automaticamente o timestamp mais recente (ou com _update se existir).
-- Alterar DISTRIBUTION_YEAR e DISTRIBUTION_MONTH conforme o mês.
-- ============================================================
SELECT
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    23 AS ENTITY_ID,
    FLOOR(RUN_CODE / 1000) + 40 AS AREA_CM,
    VALID_TYPE_ID,
    VALBYPROF,
    SUM(QNT_VALIDATION) AS PT_VALIDACOES
FROM DW_PROC.F_VALIDATIONS
WHERE DISTRIBUTION_YEAR  = 2026
  AND DISTRIBUTION_MONTH = 5       -- alterar conforme o mês
  AND ENTITY_ID = 23               -- Portal VIVA (CM móvel)
  AND TICKET_OPERATOR_CODE = 31    -- Navegante
  AND VALID_TYPE_ID = 0
  AND VALBYPROF = 0
  AND RUN_CODE BETWEEN 1000 AND 4999
GROUP BY
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    FLOOR(RUN_CODE / 1000) + 40,
    VALID_TYPE_ID,
    VALBYPROF
ORDER BY TICKET_CODE, AREA_CM;



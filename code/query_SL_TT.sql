-- ============================================================
-- Query 1: PT por operador e título (todos excepto TT/SL)
-- Fonte: DW_PROC.F_VALIDATIONS
-- ============================================================
SELECT
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    ENTITY_ID,
    VALID_TYPE_ID,
    SUM(QNT_VALIDATION) AS PT_VALIDACOES
FROM DW_PROC.F_VALIDATIONS
WHERE DISTRIBUTION_YEAR = 2026
  AND DISTRIBUTION_MONTH = 5        -- alterar conforme o mês
GROUP BY
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    ENTITY_ID,
    VALID_TYPE_ID;

-- ============================================================
-- Query 2: PT de TT (entity 5) e SL (entity 8) com georreferenciação
-- Para separar TT de SL pelo equipamento validador (linha/paragem)
-- ============================================================
SELECT
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    ENTITY_ID,          -- 5 = TT (Tâmega e Tua), 8 = SL (Soflusa/Barreiro)
    REF_STOP_ID,        -- paragem de validação
    RUN_CODE,           -- carreira/serviço
    ROUTE,              -- linha
    VALID_TYPE_ID,
    SUM(QNT_VALIDATION) AS PT_VALIDACOES
FROM DW_PROC.F_VALIDATIONS
WHERE DISTRIBUTION_YEAR = 2026
  AND DISTRIBUTION_MONTH = 5        -- alterar conforme o mês
  AND ENTITY_ID IN (5, 8)           -- 5=TT, 8=SL
GROUP BY
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    ENTITY_ID,
    REF_STOP_ID,
    RUN_CODE,
    ROUTE,
    VALID_TYPE_ID;

-- ============================================================
-- Query 2b: Totais TT e SL por ticket (versão agregada) ---> correr este!
-- ============================================================
SELECT
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    ENTITY_ID,
    SUM(QNT_VALIDATION) AS PT_VALIDACOES
FROM DW_PROC.F_VALIDATIONS
WHERE DISTRIBUTION_YEAR = 2026
  AND DISTRIBUTION_MONTH = 5
  AND ENTITY_ID IN (5, 8)
  AND TICKET_OPERATOR_CODE = 31     -- só Navegante
  AND TICKET_CODE > 0               -- excluir linha de totais
GROUP BY
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    ENTITY_ID
ORDER BY TICKET_CODE, ENTITY_ID;

# Diagnóstico: Totais PT por Operador — maio 2026

## 1. Comparação: R vs. Excel colega (Estado Atual)

| Operador | R (script) | Excel colega | Diferença | Estado |
|:---|---:|---:|---:|:---:|
| CP | 8 201 403 | 8 201 403 | 0 | ✅ |
| FT | 2 571 133 | 2 571 133 | 0 | ✅ |
| TT | 676 961 | 676 961 | 0 | ✅ |
| SL | 878 732 | 878 732 | 0 | ✅ |
| ML | 11 240 990 | 11 240 990 | 0 | ✅ |
| MS / MTS | 1 436 026 | 1 436 026 | 0 | ✅ |
| CA / Carris | 9 623 386 | 9 623 386 | 0 | ✅ |
| TB / TCB | 1 096 311 | 1 096 311 | 0 | ✅ |
| CAP / AT Cascais | 513 811 | 513 811 | 0 | ✅ |
| BQ / BT Oeste | 65 332 | 65 332 | 0 | ✅ |
| **CM / AT TML - CM** | **17 765 042** | **17 766 274** | **-1 232** | 🔍 **Em investigação** |

---

## 2. Questões Resolvidas

### TT e SL: Separação por validações Oracle
* **Causa**: O Recibo B de TT agrega TT + SL (`1 555 693`). O Recibo B de SL tem valores parciais duplicados.
* **Resolução**: 
  - Os totais oficiais continuam ancorados ao Recibo B de TT.
  - A separação de passageiros é feita via query 2b de [`query_SL_TT.sql`](file:///c:/GIS/Compensacoes/code/query_SL_TT.sql), aplicando a fórmula exata da colega:
    - `TICKET_OPERATOR_CODE = 31`
    - `VALID_TYPE_ID = 0`
    - `VALBYPROF = 0`
    - `RUN_CODE = 7` → **SL** (Soflusa)
    - Outros `RUN_CODE` (ou `!= 7`) → **TT** (Transtejo)
* **Resultado**: TT = 676 961, SL = 878 732 (diferença: **0**).

### CA e TB: Linha `ticket_code = -1`
* **Causa**: Passageiros de títulos gratuitos (VaT) que o sistema não associou a um ticket específico eram descartados pelo filtro `ticket_code > 0`.
* **Resolução**: Recodificação da linha `ticket_operator_code == -1 & ticket_code == -1` para `ticket_operator_code = 31` e `ticket_code = 1020` (Navegante 12 Criança).
* **Resultado**: CA (+64 593) e TB (+12 521) batem a 100% com o Excel (diferença: **0**).

---

## 3. Em Investigação: Carris Metropolitana (CM)

* **Diferença**: **-1 232 PT** (Excel colega tem 17 766 274, R tem 17 765 042).
* **Hipótese**: Validações da aba `entity ID 23` (Portal VIVA — validadores móveis) distribuídas pelas sub-áreas da CM, ou diferenças em títulos específicos.
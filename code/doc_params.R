# =============================================================================
# doc_params.R — Parâmetros de emissão dos documentos oficiais (mês a mês)
# Distribuição de Receitas Navegante — TML
#
# Editar este ficheiro a cada nova emissão mensal.
# É automaticamente carregado por informacao1.qmd, oficio1.qmd,
# oficio1_alt.qmd, oficio2.qmd e metodologia.qmd via source().
# =============================================================================

# ---- Dados de bilhética ------------------------------------------------------
# Datas em que foram disponibilizados os dados DITS e ITS para este mês
data_dados_dits <- "24 de agosto de 2026"   # data de disponibilização dos dados DITS
data_dados_its  <- "24 de agosto de 2026"   # data de disponibilização dos dados ITS

# ---- Financiamento Incentiva +TP (Fundo Ambiental) ---------------------------
# TRUE  = verba ainda NÃO transferida à data de emissão → faturação parcelar
# FALSE = verba já disponível → faturação imediata total
incentiva_tp_pendente <- TRUE

# ---- Referências oficiais ----------------------------------------------------
numero_informacao <- "TML-XXXX-XXXX-INF-XXXX-DEP"   # Nº da Informação Técnica
numero_oficio     <- "TML-XXXX-XXXX-OF-XXXX-DEP"    # Nº do Ofício 1
numero_oficio2    <- "TML-YYYY-YYYY-OF-YYYY-DEP"    # Nº do Ofício 2 (Incentiva +TP)
data_documento    <- format(Sys.Date(), "%d/%m/%Y")  # ou fixar manualmente: "24/09/2026"

# ---- Autores / Intervenientes ------------------------------------------------
de_pessoa1_nome  <- "Ana Isabel Capote Fernandes Rosado"
de_pessoa1_cargo <- "Técnica Superior"

de_pessoa2_nome  <- "Luísa Salomé Freixo Lopes de Castro Nogueira"
de_pessoa2_cargo <- "Técnica Superior"

de_pessoa3_nome  <- "António Sérgio Vaz Rei Manso Pinheiro"
de_pessoa3_cargo <- "Diretor do Departamento de Estudos e Planeamento"

de_divisao       <- "Estudos e Planeamento - Sistemas de Transportes"

# ---- Destinatário (interno) --------------------------------------------------
para_pessoa_nome <- "Helena Catarina Mota Ferreira Tavares Marcelino"
para_cargo       <- "Coordenadora"
para_divisao     <- "Estudos e Planeamento - Sistemas de Transportes"


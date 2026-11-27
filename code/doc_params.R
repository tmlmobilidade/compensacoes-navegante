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
data_dados_its  <- "27 de novembro de 2026"              # data de disponibilização dos dados distâncias médias

# ---- Financiamento Incentiva +TP (Fundo Ambiental) ---------------------------
# TRUE  = verba ainda NÃO transferida à data de emissão → faturação parcelar
# FALSE = verba já disponível → faturação imediata total
incentiva_tp_pendente <- TRUE

# ---- Garantir que config.R (ANO, MES, DATA_DIR) está carregado ---------------
if (!exists("ANO") || !exists("MES") || !exists("DATA_DIR")) {
  source(here::here("code", "config.R"))
}

format_date_pt <- function(date_str, default = "XX de XXXX de 2026") {
  if (is.na(date_str) || !nzchar(date_str)) return(default)
  d_obj <- tryCatch(as.Date(date_str), error = function(e) NA)
  if (is.na(d_obj)) return(default)
  meses_nm <- c("janeiro", "fevereiro", "março", "abril", "maio", "junho",
                "julho", "agosto", "setembro", "outubro", "novembro", "dezembro")
  sprintf("%d de %s de %d",
          as.integer(format(d_obj, "%d")),
          meses_nm[as.integer(format(d_obj, "%m"))],
          as.integer(format(d_obj, "%Y")))
}

get_recibos_b_date <- function(recibos_dir = file.path(DATA_DIR, "Recibos B")) {
  items <- list.files(recibos_dir, pattern = "^reg_.*_reciboB_[0-9]{6}_20[0-9]{6}",
                      ignore.case = TRUE, include.dirs = TRUE)
  if (length(items) == 0) return(NA_character_)
  dates <- sub("^reg_.*_reciboB_[0-9]{6}_(20[0-9]{6}).*$", "\\1", items, ignore.case = TRUE)
  dates <- dates[grepl("^20[0-9]{6}$", dates)]
  if (length(dates) == 0) return(NA_character_)
  oldest <- min(dates)
  sprintf("%s-%s-%s", substr(oldest, 1, 4), substr(oldest, 5, 6), substr(oldest, 7, 8))
}

## Data de disponibilização dos dados DITS (distâncias médias) para este mês
data_dados_dits <- format_date_pt(get_recibos_b_date())  # extraída automaticamente dos ficheiros Recibos B (data mais antiga)
# we can overwrite it manually if needed, e.g.:
# data_dados_dits <- "27 de novembro de 2026"  # data

# ---- Referências oficiais ----------------------------------------------------
docs_nr_path <- here::here("lists", "documents_nr.csv")
df_docs <- if (file.exists(docs_nr_path)) {
  utils::read.csv2(docs_nr_path, stringsAsFactors = FALSE, na.strings = c("", "NA"))
} else {
  data.frame()
}

get_doc_nr <- function(doc_type, default, grp = "navegante") {
  if (nrow(df_docs) > 0 && all(c("group", "ano", "mes", "type", "numero") %in% names(df_docs))) {
    doc_type <- sub("^numero_", "", doc_type)
    row <- df_docs[df_docs$group == grp & df_docs$ano == ANO & df_docs$mes == MES & df_docs$type == doc_type, ]
    if (nrow(row) > 0) {
      val <- trimws(as.character(row$numero[1]))
      if (!is.na(val) && nzchar(val)) return(val)
    }
  }
  default
}

get_doc_date <- function(doc_type, default = NA_character_, grp = "navegante", num_fallback = "") {
  doc_type <- sub("^numero_", "", doc_type)
  if (nrow(df_docs) > 0 && all(c("group", "ano", "mes", "type") %in% names(df_docs))) {
    row <- df_docs[df_docs$group == grp & df_docs$ano == ANO & df_docs$mes == MES & df_docs$type == doc_type, ]
    if (nrow(row) > 0) {
      if ("date" %in% names(row)) {
        val <- trimws(as.character(row$date[1]))
        if (!is.na(val) && nzchar(val)) return(val)
      }
      if ("numero" %in% names(row) && !nzchar(num_fallback)) {
        num_fallback <- trimws(as.character(row$numero[1]))
      }
    }
  }
  m <- regmatches(num_fallback, regexpr("\\b20\\d{6}\\b", num_fallback))
  if (length(m) == 1 && nzchar(m)) {
    return(sprintf("%s-%s-%s", substr(m, 1, 4), substr(m, 5, 6), substr(m, 7, 8)))
  }
  default
}

# fallback defaults for document numbers if not found in documents_nr.csv
numero_informacao1 <- get_doc_nr("informacao1", "TML-XXXX-XXXX-INF-XXXX-DEP")  # Nº da Informação Técnica 1
numero_oficio1     <- get_doc_nr("oficio1",     "TML-XXXX-XXXX-OF-XXXX-DEP")   # Nº do Ofício 1
numero_oficio2     <- get_doc_nr("oficio2",     "TML-YYYY-YYYY-OF-YYYY-DEP")   # Nº do Ofício 2 (Incentiva +TP)
data_documento     <- format(Sys.Date(), "%d/%m/%Y")  # ou fixar manualmente: "24/09/2026"
data_oficio1       <- format_date_pt(get_doc_date("oficio1", grp = "navegante", num_fallback = numero_oficio1))


# ---- Autores / Intervenientes ------------------------------------------------
de_pessoa1_nome  <- "Ana Isabel Capote Fernandes Rosado"
de_pessoa1_cargo <- "Técnica Superior"

# de_pessoa2_nome  <- "Luísa Salomé Freixo Lopes de Castro Nogueira"
de_pessoa2_nome  <- "Rosa Melo Félix"
de_pessoa2_cargo <- "Técnica Superior"

de_pessoa3_nome  <- "António Sérgio Vaz Rei Manso Pinheiro"
de_pessoa3_cargo <- "Diretor do Departamento de Estudos e Planeamento"

de_divisao       <- "Estudos e Planeamento - Sistemas de Transportes"

# ---- Destinatário (interno) --------------------------------------------------
para_pessoa_nome <- "Helena Catarina Mota Ferreira Tavares Marcelino"
para_cargo       <- "Coordenadora"
para_divisao     <- "Estudos e Planeamento - Sistemas de Transportes"


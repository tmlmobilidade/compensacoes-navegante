# =============================================================================
# utils_extenso.R — Conversão de montantes em euros por extenso (Português de Portugal)
# Distribuição de Receitas Navegante — TML
# =============================================================================

#' Converte um valor numérico em euros para a sua representação por extenso em PT-PT.
#'
#' Exemplos:
#'   numero_por_extenso(20121710.17)
#'   # -> "vinte milhões cento e vinte e um mil setecentos e dez euros e dezassete cêntimos"
#'   numero_por_extenso(13657120.00)
#'   # -> "treze milhões seiscentos e cinquenta e sete mil cento e vinte euros"
#'
#' @param n Valor numérico (positivo)
#' @return String com o texto por extenso
numero_por_extenso <- function(n) {
  if (is.na(n) || !is.numeric(n)) return("")

  unidades  <- c("", "um", "dois", "três", "quatro", "cinco", "seis", "sete", "oito", "nove")
  especiais <- c("dez", "onze", "doze", "treze", "catorze", "quinze", "dezasseis", "dezassete", "dezoito", "dezanove")
  dezenas   <- c("", "", "vinte", "trinta", "quarenta", "cinquenta", "sessenta", "setenta", "oitenta", "noventa")
  centenas  <- c("", "cento", "duzentos", "trezentos", "quatrocentos", "quinhentos", "seiscentos", "setecentos", "oitocentos", "novecentos")

  converter_grupo <- function(num) {
    if (num == 0) return("")
    if (num == 100) return("cem")
    c <- num %/% 100
    d <- (num %% 100) %/% 10
    u <- num %% 10
    res <- character(0)
    if (c > 0) res <- c(res, centenas[c + 1])
    if (d == 1) {
      res <- c(res, especiais[u + 1])
    } else {
      if (d > 1) res <- c(res, dezenas[d + 1])
      if (u > 0) res <- c(res, unidades[u + 1])
    }
    paste(res, collapse = " e ")
  }

  converter_inteiro <- function(val) {
    if (val == 0) return("zero")
    milhoes  <- val %/% 1000000
    resto    <- val %% 1000000
    milhares <- resto %/% 1000
    unids    <- resto %% 1000

    partes <- character(0)
    if (milhoes > 0) {
      m_str <- converter_grupo(milhoes)
      if (milhoes == 1) partes <- c(partes, paste(m_str, "milhão"))
      else partes <- c(partes, paste(m_str, "milhões"))
    }
    if (milhares > 0) {
      k_str <- converter_grupo(milhares)
      if (milhares == 1 && length(partes) == 0) partes <- c(partes, "mil")
      else partes <- c(partes, paste(k_str, "mil"))
    }
    if (unids > 0) {
      u_str <- converter_grupo(unids)
      partes <- c(partes, u_str)
    }
    if (length(partes) == 1) return(partes[1])
    paste(partes, collapse = " ")
  }

  eur  <- floor(round(n, 2))
  cent <- round((round(n, 2) - eur) * 100)

  eur_str <- converter_inteiro(eur)
  res <- paste(eur_str, ifelse(eur == 1, "euro", "euros"))

  if (cent > 0) {
    cent_str <- converter_grupo(cent)
    res <- paste(res, "e", cent_str, ifelse(cent == 1, "cêntimo", "cêntimos"))
  }
  res
}


# =============================================================================
# 00_setup.R — Instalação e carregamento de pacotes
# Distribuição de Receitas Navegante — TML
# =============================================================================

pkgs_needed <- c(
  "tidyverse",   # dplyr, tidyr, readr, ggplot2, ...
  "readxl",      # ler ficheiros Excel (.xlsx)
  "writexl",     # escrever ficheiros Excel
  "janitor",     # clean_names, tabyl
  "glue",        # interpolação de strings
  "here",        # caminhos relativos robustos
  "lubridate",   # datas
  "scales",      # formatação de números
  "openxlsx"     # criação e formatação avançada de Excel (.xlsx)
)

pkgs_missing <- pkgs_needed[!sapply(pkgs_needed, requireNamespace, quietly = TRUE)]

if (length(pkgs_missing) > 0) {
  message("A instalar pacotes em falta: ", paste(pkgs_missing, collapse = ", "))
  install.packages(pkgs_missing, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
  library(writexl)
  library(janitor)
  library(glue)
  library(here)
  library(lubridate)
  library(scales)
  library(openxlsx)
})

message("Pacotes carregados com sucesso.")

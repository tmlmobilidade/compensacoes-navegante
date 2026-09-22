// =============================================================================
// Estilos personalizados Typst (TML)
// Ficheiro: custom_styles.typ
// =============================================================================

// 1. Cabeçalho de página (Logo TML) e numeração de páginas (romana)
#set page(
  header: align(left)[
    #image("logo_tml.svg", width: 4cm)
  ],
  //numbering: "I",
  number-align: right,
  footer: context align(right)[
    #text(fill: luma(120))[
      #counter(page).display("I")
    ]
  ]
)

// 2. Tabelas
#set table(
  inset: (x: 2.5pt, y: 6pt)   // Margem interna das células
)

// Legendas de tabelas e figuras a 9pt
#show figure.caption: set text(size: 9pt)

// Ativar numeração dos cabeçalhos
#set heading(numbering: "1.1")

// 3. Parágrafos e Texto normal
// Garantir tamanho 10pt e peso de forma global
#set text(
  font: ("Greycliff CF", "Lexend"), // primeiro usa a Graycliff CF, se não existir usa a Graycliff, se não existe usa a Lexend (open source font)
  size: 10pt,
  weight: "light", // ou "extralight"
)

// Se o Quarto/template estiver a sobrepor, force com show rule:
// #show text: set text(size: 10pt)

#set par(
  spacing: 18pt,
  leading: 0.65em,
  justify: true,
)
// #show par: set block(spacing: 12pt) // overwrite rules do Quarto/template

// 4. Tipografia de cada nível
#show heading.where(level: 1): set text(size: 14pt, weight: "bold")
#show heading.where(level: 2): set text(size: 12pt, weight: "bold")
#show heading.where(level: 3): set text(size: 11pt, weight: "semibold")
#show heading.where(level: 4): set text(size: 10pt, weight: "semibold")

// 5. Espaçamento (passando o 'it' completo para preservar a numeração)
#show heading.where(level: 1): it => block(above: 2em, below: 1em, it)
#show heading.where(level: 2): it => block(above: 20pt, below: 16pt, it)
#show heading.where(level: 3): it => block(above: 16pt, below: 12pt, it)
#show heading.where(level: 4): it => block(above: 14pt, below: 10pt, it)
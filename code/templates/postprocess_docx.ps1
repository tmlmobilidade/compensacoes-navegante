param([string]$DocxPath)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not $DocxPath -or -not (Test-Path $DocxPath)) {
    $envTarget = $env:QUARTO_PROJECT_OUTPUT_FILES
    if ($envTarget -and (Test-Path $envTarget)) {
        $files = @(Get-Item $envTarget)
    } else {
        $files = Get-ChildItem -Path "code/*.docx" -Exclude "*template*", "*pandoc*", "*TML-I*"
    }
} else {
    $files = @(Get-Item $DocxPath)
}

foreach ($f in $files) {
    if ($f.Extension -ne ".docx") { continue }
    try {
        $zip = [System.IO.Compression.ZipFile]::Open($f.FullName, [System.IO.Compression.ZipArchiveMode]::Update)
        $entry = $zip.GetEntry('word/document.xml')
        if (-not $entry) { $zip.Dispose(); continue }
        
        $reader = New-Object System.IO.StreamReader($entry.Open())
        $xml = $reader.ReadToEnd()
        $reader.Close()
        
        $matches = [regex]::Matches($xml, '<w:tbl[ >].*?</w:tbl>')
        $modified = $false
        
        for ($i = $matches.Count - 1; $i -ge 0; $i--) {
            $tbl = $matches[$i].Value
            $tblNew = $tbl
            
            if ($tbl.Contains('Passageiros') -and $tbl.Contains('Receitas') -and $tbl.Contains('jan/25')) {
                # Table 7: TabelaTextoPequeno e margens compactas
                $tblNew = $tbl.Replace('w:val="Compact"', 'w:val="TabelaTextoPequeno"')
                $tightMar = '<w:tblCellMar><w:top w:w="15" w:type="dxa"/><w:left w:w="40" w:type="dxa"/><w:bottom w:w="15" w:type="dxa"/><w:right w:w="40" w:type="dxa"/></w:tblCellMar>'
                if ($tblNew.Contains('<w:tblCellMar>')) {
                    $tblNew = [regex]::Replace($tblNew, '<w:tblCellMar>.*?</w:tblCellMar>', $tightMar)
                } else {
                    $tblNew = [regex]::Replace($tblNew, '(<w:tblLayout [^>]*/>)', "`$1$tightMar")
                }
            } elseif ($tbl.Contains('De:') -and $tbl.Contains('Para:')) {
                # Tabela de cabecalho (De e Para): 2 colunas sem bordas
                $tblNew = $tbl.Replace('w:val="Compact"', 'w:val="BlocoPequeno"')
                $tblNew = $tblNew.Replace('w:val="TabelaTexto"', 'w:val="BlocoPequeno"')
                $tblNew = [regex]::Replace($tblNew, '<w:tr[ >].*?<w:tblHeader/>.*?</w:tr>', '')
                $tblNew = [regex]::Replace($tblNew, '<w:tblStyle [^>]*/>', '')
                $tblNew = [regex]::Replace($tblNew, '<w:tcBorders>.*?</w:tcBorders>', '<w:tcBorders><w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/></w:tcBorders>')
                $noBrd = '<w:tblW w:type="pct" w:w="5000"/><w:tblBorders><w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/><w:insideH w:val="none"/><w:insideV w:val="none"/></w:tblBorders><w:tblLayout w:type="fixed"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="0" w:type="dxa"/><w:bottom w:w="140" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tblCellMar><w:tblLook w:val="0000"/>'
                $tblNew = [regex]::Replace($tblNew, '<w:tblPr>.*?</w:tblPr>', "<w:tblPr>$noBrd</w:tblPr>")
            } else {
                # Tabelas normais: TabelaTexto (Calibri 8.5 pt)
                $tblNew = $tbl.Replace('w:val="Compact"', 'w:val="TabelaTexto"')
            }

            # Centrar tabelas de conteudo (nao cabecalho De/Para)
            if (-not ($tbl.Contains('De:') -and $tbl.Contains('Para:'))) {
                $tblNew = [regex]::Replace($tblNew, '(<w:tblPr[^>]*>)(.*?)(</w:tblPr>)', {
                    param($tm)
                    $tblPrContent = $tm.Groups[2].Value
                    if ($tblPrContent.Contains('<w:jc ')) {
                        $tblPrContent = [regex]::Replace($tblPrContent, '<w:jc [^>]*/>', '<w:jc w:val="center"/>')
                    } else {
                        $tblPrContent = '<w:jc w:val="center"/>' + $tblPrContent
                    }
                    return $tm.Groups[1].Value + $tblPrContent + $tm.Groups[3].Value
                }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
            }
            
            if ($tblNew -ne $tbl) {
                $xml = $xml.Substring(0, $matches[$i].Index) + $tblNew + $xml.Substring($matches[$i].Index + $matches[$i].Length)
                $modified = $true
            }
        }

        # Centrar paragrafos que contem imagens/desenhos (<w:drawing>)
        $xmlNew = [regex]::Replace($xml, '(<w:p[ >].*?</w:p>)', {
            param($m)
            $p = $m.Groups[1].Value
            if ($p.Contains('<w:drawing>') -or $p.Contains('<w:drawing ')) {
                if ($p.Contains('<w:jc ')) {
                    return [regex]::Replace($p, '<w:jc [^>]*/>', '<w:jc w:val="center"/>')
                } elseif ($p.Contains('<w:pPr>')) {
                    return $p.Replace('<w:pPr>', '<w:pPr><w:jc w:val="center"/>')
                } elseif ($p.Contains('<w:pPr ')) {
                    return [regex]::Replace($p, '(<w:pPr [^>]*>)', '$1<w:jc w:val="center"/>')
                } else {
                    return [regex]::Replace($p, '(<w:p[ >])', '$1<w:pPr><w:jc w:val="center"/></w:pPr>')
                }
            }
            return $p
        }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if ($xmlNew -ne $xml) {
            $xml = $xmlNew
            $modified = $true
        }

        # Redimensionar fig-1 para a largura da pagina landscape (~9.5 pol = 8686800 EMU, 3.8 pol = 3474720 EMU)
        # apenas quando fig-1 se encontra dentro de uma seccao landscape (ex.: PasseJovem)
        $xmlBeforeFig = $xml
        $xml = [regex]::Replace($xml, '(</w:sectPr>(?:(?!</w:sectPr>).)*?<w:drawing[ >](?:(?!</w:drawing>).)*?fig-1(?:(?!</w:drawing>).)*?</w:drawing>(?:(?!</w:sectPr>).)*?w:orient="landscape")', {
            param($m)
            return [regex]::Replace($m.Groups[1].Value, 'cx="\d+" cy="\d+"', 'cx="8686800" cy="3474720"')
        }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if ($xml -ne $xmlBeforeFig) {
            $modified = $true
        }

        # Espacamento vertical apos tabelas (no primeiro paragrafo a seguir a </w:tbl>)
        $xmlBeforeTblSpace = $xml
        $xml = [regex]::Replace($xml, '(</w:tbl>(?:\s*<w:bookmarkEnd[^>]*>)*\s*(?:<w:bookmarkStart[^>]*>)*\s*<w:p[ >][^>]*?<w:pPr[^>]*>)(.*?)(</w:pPr>)', {
            param($m)
            $pPr = $m.Groups[2].Value
            if ($pPr.Contains('BlocoPequeno')) {
                return $m.Value
            }
            if ($pPr.Contains('TabelaNota')) {
                if ($pPr.Contains('w:after="')) {
                    $pPr = [regex]::Replace($pPr, 'w:after="\d+"', 'w:after="200"')
                } else {
                    $pPr = $pPr + '<w:spacing w:before="60" w:after="200" w:line="240" w:lineRule="auto"/>'
                }
            } else {
                if ($pPr.Contains('w:before="')) {
                    $pPr = [regex]::Replace($pPr, 'w:before="\d+"', 'w:before="240"')
                } else {
                    $pPr = $pPr + '<w:spacing w:before="240" w:after="240" w:line="288" w:lineRule="auto"/>'
                }
            }
            return $m.Groups[1].Value + $pPr + $m.Groups[3].Value
        }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if ($xml -ne $xmlBeforeTblSpace) {
            $modified = $true
        }

        # Limpar w:pPr duplicados em paragrafos que receberam pPr customizado via Lua (sem cruzar fronteira de paragrafo)
        $xmlBeforeCleanPpr = $xml
        $xml = [regex]::Replace($xml, '(<w:p[ >][^>]*?)<w:pPr>(?:(?!</w:p>).)*?</w:pPr><w:pPr>', '$1<w:pPr>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if ($xml -ne $xmlBeforeCleanPpr) {
            $modified = $true
        }

        # Substituir estilos nativos que colidem no file-doc (Heading1..3, BodyText, FirstParagraph, Compact, PargrafodaLista)
        # por estilos customizados TML isolados (TMLTitulo1..3 com numPr explicito, TMLCorpo, TMLCompacto, TMLLista)
        $xmlBeforeStyles = $xml
        $xml = [regex]::Replace($xml, '<w:pStyle w:val="Heading1"\s*/>', '<w:pStyle w:val="TMLTitulo1"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="5"/></w:numPr>')
        $xml = [regex]::Replace($xml, '<w:pStyle w:val="Heading2"\s*/>', '<w:pStyle w:val="TMLTitulo2"/><w:numPr><w:ilvl w:val="1"/><w:numId w:val="5"/></w:numPr>')
        $xml = [regex]::Replace($xml, '<w:pStyle w:val="Heading3"\s*/>', '<w:pStyle w:val="TMLTitulo3"/><w:numPr><w:ilvl w:val="2"/><w:numId w:val="5"/></w:numPr>')
        $xml = [regex]::Replace($xml, '<w:pStyle w:val="(BodyText|FirstParagraph)"\s*/>', '<w:pStyle w:val="TMLCorpo"/>')
        $xml = [regex]::Replace($xml, '<w:pStyle w:val="Compact"\s*/>', '<w:pStyle w:val="TMLCompacto"/>')
        $xml = [regex]::Replace($xml, '<w:pStyle w:val="PargrafodaLista"\s*/>', '<w:pStyle w:val="TMLLista"/>')
        # Paragrafos de listas ordenadas espacadas (<w:pPr><w:numPr> sem <w:pStyle>) recebem TMLCorpo
        $xml = [regex]::Replace($xml, '<w:pPr><w:numPr>', '<w:pPr><w:pStyle w:val="TMLCorpo"/><w:numPr>')
        if ($xml -ne $xmlBeforeStyles) {
            $modified = $true
        }

        # Limpar w:tcPr duplicados em celulas que receberam tcPr customizado via Lua
        if ($xml.Contains('<w:tcPr /><w:tcPr>') -or $xml.Contains('<w:tcPr/><w:tcPr>')) {
            $xml = $xml.Replace('<w:tcPr /><w:tcPr>', '<w:tcPr>')
            $xml = $xml.Replace('<w:tcPr/><w:tcPr>', '<w:tcPr>')
            $modified = $true
        }

        # Garantir cabecalhos e rodapes oficiais TML e numeracao romana (upperRoman) nas Informacoes/Metodologias,
        # evitando que ao colar no file-doc os cabecalhos/rodapes desaparecam na 1.a seccao portrait.
        # Nos Oficios (que tem cabecalhos/rodapes proprios no file-doc e nao tem quebras de seccao landscape),
        # removemos qualquer referencia a cabecalhos/rodapes de Informacao.
        if ($f.Name -like "*oficio*") {
            $xmlBeforeOficio = $xml
            $xml = [regex]::Replace($xml, '<w:(header|footer)Reference[^/>]*/>', '')
            if ($xml -ne $xmlBeforeOficio) {
                $modified = $true
            }
        } else {
            $refDocPath = Join-Path $PSScriptRoot "TML_Informacao_pandoc.docx"
            if (-not (Test-Path $refDocPath)) {
                $refDocPath = Join-Path $PSScriptRoot "TML_Informacao_template.docx"
            }
            if (Test-Path $refDocPath) {
                $refZip = [System.IO.Compression.ZipFile]::OpenRead($refDocPath)
                foreach ($entryName in @('word/header1.xml','word/header2.xml','word/header3.xml','word/footer1.xml','word/footer2.xml','word/footer3.xml','word/_rels/header2.xml.rels','word/media/tml_logo_header.jpeg')) {
                    $srcEntry = $refZip.GetEntry($entryName)
                    if ($srcEntry) {
                        $existing = $zip.GetEntry($entryName)
                        if ($existing) { $existing.Delete() }
                        $newE = $zip.CreateEntry($entryName)
                        $sIn = $srcEntry.Open()
                        $sOut = $newE.Open()
                        $sIn.CopyTo($sOut)
                        $sOut.Close()
                        $sIn.Close()
                    }
                }
                $refZip.Dispose()

                # Atualizar [Content_Types].xml
                $ctE = $zip.GetEntry('[Content_Types].xml')
                if ($ctE) {
                    $srCt = New-Object System.IO.StreamReader($ctE.Open())
                    $ct = $srCt.ReadToEnd()
                    $srCt.Close()
                    $ctBefore = $ct
                    if (-not $ct.Contains('Extension="jpeg"')) {
                        $ct = $ct.Replace('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">', '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="jpeg" ContentType="image/jpeg"/>')
                    }
                    foreach ($part in @('header1','header2','header3')) {
                        if (-not $ct.Contains("/word/$part.xml")) {
                            $ct = $ct.Replace('</Types>', "<Override PartName=`"/word/$part.xml`" ContentType=`"application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml`"/></Types>")
                        }
                    }
                    foreach ($part in @('footer1','footer2','footer3')) {
                        if (-not $ct.Contains("/word/$part.xml")) {
                            $ct = $ct.Replace('</Types>', "<Override PartName=`"/word/$part.xml`" ContentType=`"application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml`"/></Types>")
                        }
                    }
                    if ($ct -ne $ctBefore) {
                        $ctE.Delete()
                        $swCt = New-Object System.IO.StreamWriter($zip.CreateEntry('[Content_Types].xml').Open(), [System.Text.Encoding]::UTF8)
                        $swCt.Write($ct)
                        $swCt.Close()
                    }
                }

                # Atualizar word/_rels/document.xml.rels
                $relsE = $zip.GetEntry('word/_rels/document.xml.rels')
                if ($relsE) {
                    $srRels = New-Object System.IO.StreamReader($relsE.Open())
                    $rels = $srRels.ReadToEnd()
                    $srRels.Close()
                    if (-not $rels.Contains('Id="rIdHdr1"')) {
                        $hdrRels = '<Relationship Id="rIdHdr1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/><Relationship Id="rIdHdr2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header2.xml"/><Relationship Id="rIdHdr3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header3.xml"/><Relationship Id="rIdFtr1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/><Relationship Id="rIdFtr2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer2.xml"/><Relationship Id="rIdFtr3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer3.xml"/>'
                        $rels = $rels.Replace('</Relationships>', "$hdrRels</Relationships>")
                        $relsE.Delete()
                        $swRels = New-Object System.IO.StreamWriter($zip.CreateEntry('word/_rels/document.xml.rels').Open(), [System.Text.Encoding]::UTF8)
                        $swRels.Write($rels)
                        $swRels.Close()
                    }
                }

                # Atualizar blocos <w:sectPr> em word/document.xml
                $hdrRefs = '<w:headerReference w:type="even" r:id="rIdHdr1"/><w:headerReference w:type="default" r:id="rIdHdr2"/><w:footerReference w:type="even" r:id="rIdFtr1"/><w:footerReference w:type="default" r:id="rIdFtr2"/><w:headerReference w:type="first" r:id="rIdHdr3"/><w:footerReference w:type="first" r:id="rIdFtr3"/>'
                $script:sectIdx = 0
                $xmlBeforeSect = $xml
                $xml = [regex]::Replace($xml, '(<w:sectPr[^>]*>)(.*?)(</w:sectPr>)', {
                    param($m)
                    $script:sectIdx++
                    $openTag = $m.Groups[1].Value
                    $inner = $m.Groups[2].Value
                    $closeTag = $m.Groups[3].Value

                    # Remover headerReference/footerReference existentes para evitar duplicados
                    $inner = [regex]::Replace($inner, '<w:(header|footer)Reference[^/>]*/>', '')

                    # Na 1.a seccao, definir explicitamente os cabecalhos e rodapes; nas seguintes, herdar (LinkToPrevious)
                    if ($script:sectIdx -eq 1) {
                        $inner = $hdrRefs + $inner
                    }

                    # Garantir margens oficiais TML nas seccoes portrait (nao landscape)
                    if (-not $inner.Contains('w:orient="landscape"')) {
                        $inner = [regex]::Replace($inner, '<w:pgSz[^/>]*/>', '<w:pgSz w:w="11906" w:h="16838"/>')
                        $inner = [regex]::Replace($inner, '<w:pgMar[^/>]*/>', '<w:pgMar w:top="2410" w:right="1701" w:bottom="1417" w:left="1701" w:header="708" w:footer="708" w:gutter="0"/>')
                    }

                    # Garantir numeracao de pagina em algarismos romanos (upperRoman) como no file-doc
                    if ($inner.Contains('<w:pgNumType')) {
                        $inner = [regex]::Replace($inner, '<w:pgNumType[^/>]*/>', '<w:pgNumType w:fmt="upperRoman"/>')
                    } else {
                        $inner = $inner + '<w:pgNumType w:fmt="upperRoman"/>'
                    }

                    return $openTag + $inner + $closeTag
                }, [System.Text.RegularExpressions.RegexOptions]::Singleline)

                if ($xml -ne $xmlBeforeSect) {
                    $modified = $true
                }
            }
        }
        
        if ($modified) {
            $entry.Delete()
            $newEntry = $zip.CreateEntry('word/document.xml')
            $writer = New-Object System.IO.StreamWriter($newEntry.Open(), [System.Text.Encoding]::UTF8)
            $writer.Write($xml)
            $writer.Close()
        }

        # Atualizar word/numbering.xml para garantir que as listas numeradas geradas pelo Pandoc (i), ii), 1), 2))
        # trazem a fonte Greycliff CF Light 11pt nos proprios marcadores, nao herdando Cambria do file-doc
        $numEntry = $zip.GetEntry('word/numbering.xml')
        if ($numEntry) {
            $nReader = New-Object System.IO.StreamReader($numEntry.Open())
            $numXml = $nReader.ReadToEnd()
            $nReader.Close()

            $numXmlBefore = $numXml
            $rPrList = '<w:rPr><w:rFonts w:ascii="Greycliff CF Light" w:hAnsi="Greycliff CF Light" w:cs="Greycliff CF Light"/><w:color w:val="000000"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>'
            $numXml = [regex]::Replace($numXml, '(<w:abstractNum w:abstractNumId="99\d+">.*?</w:abstractNum>)', {
                param($m)
                $abs = $m.Groups[1].Value
                $abs = [regex]::Replace($abs, '(<w:lvl w:ilvl="\d+">(?:(?!</w:lvl>).)*?)(</w:lvl>)', {
                    param($lm)
                    $lvlContent = $lm.Groups[1].Value
                    if (-not $lvlContent.Contains('<w:rPr>')) {
                        return $lvlContent + $rPrList + $lm.Groups[2].Value
                    }
                    return $lm.Value
                }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
                return $abs
            }, [System.Text.RegularExpressions.RegexOptions]::Singleline)

            if ($numXml -ne $numXmlBefore) {
                $numEntry.Delete()
                $newNumEntry = $zip.CreateEntry('word/numbering.xml')
                $nWriter = New-Object System.IO.StreamWriter($newNumEntry.Open(), [System.Text.Encoding]::UTF8)
                $nWriter.Write($numXml)
                $nWriter.Close()
                $modified = $true
            }
        }

        if ($modified) {
            Write-Host ("[OK] Pos-processamento concluido para: " + $f.Name)
        }
        $zip.Dispose()
    } catch {
        Write-Warning ("Aviso ao processar " + $f.Name + ": " + $_.Exception.ToString())
    }
}

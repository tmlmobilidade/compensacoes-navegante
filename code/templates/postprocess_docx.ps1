param([string]$DocxPath)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not $DocxPath -or -not (Test-Path $DocxPath)) {
    $envTarget = $env:QUARTO_PROJECT_OUTPUT_FILES
    if ($envTarget -and (Test-Path $envTarget)) {
        $files = @(Get-Item $envTarget)
    } else {
        $files = Get-ChildItem -Path "code/*.docx" -Exclude "*template*", "*pandoc*"
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
            
            if ($tblNew -ne $tbl) {
                $xml = $xml.Substring(0, $matches[$i].Index) + $tblNew + $xml.Substring($matches[$i].Index + $matches[$i].Length)
                $modified = $true
            }
        }
        
        if ($modified) {
            $entry.Delete()
            $newEntry = $zip.CreateEntry('word/document.xml')
            $writer = New-Object System.IO.StreamWriter($newEntry.Open(), [System.Text.Encoding]::UTF8)
            $writer.Write($xml)
            $writer.Close()
            Write-Host ("[OK] Pos-processamento concluido para: " + $f.Name)
        }
        $zip.Dispose()
    } catch {
        Write-Warning ("Aviso ao processar " + $f.Name + ": " + $_.Exception.Message)
    }
}


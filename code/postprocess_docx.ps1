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
        
        for ($i = 0; $i -lt $matches.Count; $i++) {
            $tbl = $matches[$i].Value
            if ($tbl.Contains('Passageiros') -and $tbl.Contains('Receitas') -and $tbl.Contains('jan/25')) {
                # Apply TabelaTextoPequeno to Table 7 cells
                $tblNew = $tbl.Replace('w:val="Compact"', 'w:val="TabelaTextoPequeno"')
                
                # Apply compact margins
                $tightMar = '<w:tblCellMar><w:top w:w="15" w:type="dxa"/><w:left w:w="40" w:type="dxa"/><w:bottom w:w="15" w:type="dxa"/><w:right w:w="40" w:type="dxa"/></w:tblCellMar>'
                if ($tblNew.Contains('<w:tblCellMar>')) {
                    $tblNew = [regex]::Replace($tblNew, '<w:tblCellMar>.*?</w:tblCellMar>', $tightMar)
                } else {
                    $tblNew = [regex]::Replace($tblNew, '(<w:tblLayout [^>]*/>)', "`$1$tightMar")
                }
                
                $xml = $xml.Substring(0, $matches[$i].Index) + $tblNew + $xml.Substring($matches[$i].Index + $matches[$i].Length)
                $modified = $true
                break
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


[CmdletBinding()]
param(
    [string]$WorkbookPath,
    [string]$OutputDirectory,
    [string]$ImagesDirectory
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not $WorkbookPath) { $WorkbookPath = Join-Path $projectRoot 'update.xlsx' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'data' }
if (-not $ImagesDirectory) { $ImagesDirectory = Join-Path $projectRoot 'images' }

$WorkbookPath = [IO.Path]::GetFullPath($WorkbookPath)
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$ImagesDirectory = [IO.Path]::GetFullPath($ImagesDirectory)

if (-not (Test-Path -LiteralPath $WorkbookPath -PathType Leaf)) {
    throw "Classeur introuvable : $WorkbookPath"
}

if (-not (Test-Path -LiteralPath $ImagesDirectory -PathType Container)) {
    throw "Dossier d'images introuvable : $ImagesDirectory"
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

try { Add-Type -AssemblyName System.IO.Compression } catch { }
try { Add-Type -AssemblyName System.IO.Compression.FileSystem } catch { }

$mainNamespace = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
$documentRelationshipNamespace = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
$packageRelationshipNamespace = 'http://schemas.openxmlformats.org/package/2006/relationships'
$fileStream = $null
$archive = $null
$warnings = [Collections.Generic.List[string]]::new()

function Read-ZipXml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EntryName
    )

    $entry = $archive.GetEntry($EntryName)
    if ($null -eq $entry) { throw "Entrée XLSX introuvable : $EntryName" }

    $entryStream = $entry.Open()
    $reader = [IO.StreamReader]::new($entryStream, [Text.Encoding]::UTF8, $true)
    try {
        $document = [Xml.XmlDocument]::new()
        $document.PreserveWhitespace = $false
        $document.LoadXml($reader.ReadToEnd())
        return $document
    }
    finally {
        $reader.Dispose()
        $entryStream.Dispose()
    }
}

function New-NamespaceManager {
    param(
        [Parameter(Mandatory = $true)]
        [Xml.XmlDocument]$Document,
        [Parameter(Mandatory = $true)]
        [hashtable]$Namespaces
    )

    $manager = [Xml.XmlNamespaceManager]::new($Document.NameTable)
    foreach ($key in $Namespaces.Keys) {
        $manager.AddNamespace($key, $Namespaces[$key])
    }
    return ,$manager
}

function Get-RichText {
    param(
        [Parameter(Mandatory = $true)]
        [Xml.XmlNode]$Node,
        [Parameter(Mandatory = $true)]
        [Xml.XmlNamespaceManager]$NamespaceManager
    )

    $parts = foreach ($textNode in $Node.SelectNodes('.//m:t', $NamespaceManager)) {
        $textNode.InnerText
    }
    return ($parts -join '')
}

function Get-ColumnIndex {
    param([Parameter(Mandatory = $true)][string]$CellReference)

    $letters = [regex]::Match($CellReference, '^[A-Za-z]+').Value.ToUpperInvariant()
    $index = 0
    foreach ($character in $letters.ToCharArray()) {
        $index = ($index * 26) + ([int][char]$character - [int][char]'A' + 1)
    }
    return $index
}

function Get-CellValue {
    param(
        [Parameter(Mandatory = $true)]
        [Xml.XmlNode]$Cell,
        [Parameter(Mandatory = $true)]
        [Xml.XmlNamespaceManager]$NamespaceManager,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$SharedStrings
    )

    $type = $Cell.GetAttribute('t')
    if ($type -eq 'inlineStr') {
        $inline = $Cell.SelectSingleNode('m:is', $NamespaceManager)
        if ($null -eq $inline) { return '' }
        return Get-RichText -Node $inline -NamespaceManager $NamespaceManager
    }

    $valueNode = $Cell.SelectSingleNode('m:v', $NamespaceManager)
    if ($null -eq $valueNode) { return '' }
    $rawValue = $valueNode.InnerText

    if ($type -eq 's') {
        $sharedIndex = [int]$rawValue
        if ($sharedIndex -lt 0 -or $sharedIndex -ge $SharedStrings.Count) {
            throw "Index de chaîne partagée invalide : $sharedIndex"
        }
        return $SharedStrings[$sharedIndex]
    }
    if ($type -eq 'b') { return $(if ($rawValue -eq '1') { 'true' } else { 'false' }) }
    return $rawValue
}

function Read-WorksheetRows {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EntryName,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$SharedStrings
    )

    $sheetDocument = Read-ZipXml -EntryName $EntryName
    $sheetNamespaces = New-NamespaceManager -Document $sheetDocument -Namespaces @{ m = $mainNamespace }
    $result = [Collections.Generic.List[object]]::new()

    foreach ($row in $sheetDocument.SelectNodes('//m:sheetData/m:row', $sheetNamespaces)) {
        $values = @{}
        foreach ($cell in $row.SelectNodes('m:c', $sheetNamespaces)) {
            $column = Get-ColumnIndex -CellReference $cell.GetAttribute('r')
            $values[$column] = Get-CellValue -Cell $cell -NamespaceManager $sheetNamespaces -SharedStrings $SharedStrings
        }
        if ($values.Count -gt 0) { $result.Add($values) }
    }
    return ,$result
}

function Convert-ImagePath {
    param([AllowEmptyString()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    if ($Value -notmatch '^https://storage\.googleapis\.com/[^/]+/(.+)$') { return $Value }

    $filename = [Uri]::UnescapeDataString($Matches[1])
    $localPath = Join-Path $ImagesDirectory $filename
    if (Test-Path -LiteralPath $localPath -PathType Leaf) {
        return ('images/' + $filename.Replace('\', '/'))
    }

    $warnings.Add("Image locale absente, URL distante conservée : $filename")
    return $Value
}

function Convert-RowsToItems {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SheetName,
        [Parameter(Mandatory = $true)]
        [Collections.Generic.List[object]]$Rows,
        [Parameter(Mandatory = $true)]
        [string[]]$RequiredHeaders
    )

    if ($Rows.Count -lt 1) { throw "L'onglet '$SheetName' est vide." }

    $headerRow = $Rows[0]
    $maxColumn = ($headerRow.Keys | Measure-Object -Maximum).Maximum
    $headers = for ($column = 1; $column -le $maxColumn; $column++) {
        [string]$headerRow[$column]
    }

    foreach ($requiredHeader in $RequiredHeaders) {
        if ($headers -notcontains $requiredHeader) {
            throw "Colonne obligatoire '$requiredHeader' absente de l'onglet '$SheetName'."
        }
    }

    $items = [Collections.Generic.List[object]]::new()
    for ($rowIndex = 1; $rowIndex -lt $Rows.Count; $rowIndex++) {
        $row = $Rows[$rowIndex]
        $hasContent = $false
        foreach ($column in $row.Keys) {
            if (-not [string]::IsNullOrWhiteSpace([string]$row[$column])) {
                $hasContent = $true
                break
            }
        }
        if (-not $hasContent) { continue }

        $item = [ordered]@{}
        for ($column = 1; $column -le $headers.Count; $column++) {
            $header = $headers[$column - 1]
            if ([string]::IsNullOrWhiteSpace($header)) { continue }
            $value = [string]$row[$column]

            if ($header -eq 'technologies') {
                $item[$header] = @($value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            }
            elseif ($header -eq 'image') {
                $item[$header] = Convert-ImagePath -Value $value
            }
            else {
                $item[$header] = $value
            }
        }
        $items.Add([PSCustomObject]$item)
    }
    return ,$items
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object]$Data
    )

    $json = ConvertTo-Json -InputObject $Data -Depth 10
    $utf8WithoutBom = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8WithoutBom)
}

try {
    $fileStream = [IO.File]::Open($WorkbookPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $archive = [IO.Compression.ZipArchive]::new($fileStream, [IO.Compression.ZipArchiveMode]::Read, $false)

    $sharedStrings = @()
    if ($null -ne $archive.GetEntry('xl/sharedStrings.xml')) {
        $sharedDocument = Read-ZipXml -EntryName 'xl/sharedStrings.xml'
        $sharedNamespaces = New-NamespaceManager -Document $sharedDocument -Namespaces @{ m = $mainNamespace }
        $sharedStrings = @($sharedDocument.SelectNodes('//m:si', $sharedNamespaces) | ForEach-Object {
            Get-RichText -Node $_ -NamespaceManager $sharedNamespaces
        })
    }

    $workbookDocument = Read-ZipXml -EntryName 'xl/workbook.xml'
    $workbookNamespaces = New-NamespaceManager -Document $workbookDocument -Namespaces @{
        m = $mainNamespace
        r = $documentRelationshipNamespace
    }
    $relationshipsDocument = Read-ZipXml -EntryName 'xl/_rels/workbook.xml.rels'
    $relationshipNamespaces = New-NamespaceManager -Document $relationshipsDocument -Namespaces @{ p = $packageRelationshipNamespace }
    $relationships = @{}
    foreach ($relationship in $relationshipsDocument.SelectNodes('//p:Relationship', $relationshipNamespaces)) {
        $relationships[$relationship.GetAttribute('Id')] = $relationship.GetAttribute('Target')
    }

    $sheetDefinitions = [ordered]@{
        website = @{ File = 'websites.json'; Required = @('title', 'description', 'link', 'category', 'technologies', 'image', 'highlight') }
        design  = @{ File = 'designs.json'; Required = @('image', 'category', 'description') }
        video   = @{ File = 'videos.json'; Required = @('url', 'category', 'description', 'platform') }
        photo   = @{ File = 'photos.json'; Required = @('image', 'category', 'description') }
    }
    $datasets = @{}

    foreach ($sheetName in $sheetDefinitions.Keys) {
        $sheetNode = $workbookDocument.SelectSingleNode("//m:sheet[@name='$sheetName']", $workbookNamespaces)
        if ($null -eq $sheetNode) { throw "Onglet obligatoire absent : $sheetName" }

        $relationshipId = $sheetNode.GetAttribute('id', $documentRelationshipNamespace)
        $target = [string]$relationships[$relationshipId]
        if ([string]::IsNullOrWhiteSpace($target)) { throw "Relation introuvable pour l'onglet '$sheetName'." }
        $entryName = if ($target.StartsWith('/')) {
            $target.TrimStart('/')
        }
        else {
            'xl/' + $target.TrimStart('/')
        }
        $entryName = $entryName.Replace('\', '/')

        $rows = Read-WorksheetRows -EntryName $entryName -SharedStrings $sharedStrings
        $items = Convert-RowsToItems -SheetName $sheetName -Rows $rows -RequiredHeaders $sheetDefinitions[$sheetName].Required
        $datasets[$sheetName] = @($items)
        Write-JsonFile -Path (Join-Path $OutputDirectory $sheetDefinitions[$sheetName].File) -Data @($items)
    }

    $allData = [ordered]@{
        websites = @($datasets.website)
        designs = @($datasets.design)
        videos = @($datasets.video)
        photos = @($datasets.photo)
    }
    Write-JsonFile -Path (Join-Path $OutputDirectory 'all.json') -Data $allData

    Write-Host ''
    Write-Host 'JSON générés avec succès :' -ForegroundColor Green
    Write-Host "  Sites web : $($datasets.website.Count)"
    Write-Host "  Designs    : $($datasets.design.Count)"
    Write-Host "  Vidéos     : $($datasets.video.Count)"
    Write-Host "  Photos     : $($datasets.photo.Count)"
    Write-Host "  Dossier    : $OutputDirectory"

    if ($warnings.Count -gt 0) {
        Write-Host ''
        Write-Host 'Avertissements :' -ForegroundColor Yellow
        $warnings | Sort-Object -Unique | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }
}
finally {
    if ($null -ne $archive) { $archive.Dispose() }
    if ($null -ne $fileStream) { $fileStream.Dispose() }
}

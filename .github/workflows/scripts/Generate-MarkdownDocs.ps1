# Generate-MarkdownDocs.ps1
# Script to extract help from public functions and generate markdown documentation for each

$publicFunctions = Get-ChildItem -Path "GitIdentities/Public" -Filter "*.ps1"
foreach ($funcFile in $publicFunctions) {
    $funcName = [System.IO.Path]::GetFileNameWithoutExtension($funcFile.Name)
    Write-Host "Processing: $funcName"
    # Extract help from function file (basic extraction)
    $content = Get-Content $funcFile.FullName -Raw
    if ($content -match '(?s)<#(.+?)#>') {
        $helpContent = $matches[1].Trim()
        $mdContent = """
# $funcName

```powershell
$helpContent
```

## Examples

See README.md for usage examples.
"""
        $mdPath = "docs/$funcName.md"
        $mdContent | Out-File -FilePath $mdPath -Encoding UTF8
        Write-Host "  ✓ Generated: $mdPath"
    }
}
Write-Host '✓ Documentation generation completed'

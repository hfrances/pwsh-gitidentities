# Module: GitIdentities
# Carga funciones públicas y privadas
# Comentarios en español, mensajes runtime en inglés

# Importar funciones privadas
Get-ChildItem -Path $PSScriptRoot/Private -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
# Importar funciones públicas
Get-ChildItem -Path $PSScriptRoot/Public -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }

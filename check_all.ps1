$files = Get-ChildItem -Path lib/translations/translations_*.dart

foreach ($file in $files) {
    $content = Get-Content $file.FullName | Select-String "purchase_windows_web_or_mobile"
    $content2 = Get-Content $file.FullName | Select-String "buy_from_web"
    Write-Host "--- $($file.Name) ---"
    Write-Host $content
    Write-Host $content2
}

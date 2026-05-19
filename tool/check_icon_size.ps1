Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile('d:\UserData\Desktop\my_proj\mooknote\assets\icon\app_icon.png')
Write-Host ('app_icon: ' + $img.Width + 'x' + $img.Height)
$img.Dispose()
$img2 = [System.Drawing.Image]::FromFile('d:\UserData\Desktop\my_proj\mooknote\assets\icon\app_icon2.png')
Write-Host ('app_icon2: ' + $img2.Width + 'x' + $img2.Height)
$img2.Dispose()

$sizes = @(48, 72, 96, 144, 192)
foreach ($size in $sizes) {
    $f = [System.Drawing.Image]::FromFile('d:\UserData\Desktop\my_proj\mooknote\android\app\src\main\res\mipmap-mdpi\ic_launcher2.png')
    Write-Host ('ic_launcher2 mdpi: ' + $f.Width + 'x' + $f.Height)
    $f.Dispose()
    break
}

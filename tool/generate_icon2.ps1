$source = 'd:\UserData\Desktop\my_proj\mooknote\assets\icon\app_icon2.png'
$sizes = @{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
}

Add-Type -AssemblyName System.Drawing
$original = [System.Drawing.Image]::FromFile($source)

foreach ($dir in $sizes.Keys) {
    $size = $sizes[$dir]
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($original, 0, 0, $size, $size)
    $graphics.Dispose()
    
    $output = "d:\UserData\Desktop\my_proj\mooknote\android\app\src\main\res\$dir\ic_launcher2.png"
    $bitmap.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    
    Write-Host "Generated $output (${size}x${size})"
}

$original.Dispose()
Write-Host "Done!"

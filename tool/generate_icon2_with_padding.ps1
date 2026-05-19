Add-Type -AssemblyName System.Drawing

$source = 'd:\UserData\Desktop\my_proj\mooknote\assets\icon\app_icon2.png'
$original = [System.Drawing.Image]::FromFile($source)

# 目标尺寸（和 flutter_launcher_icons 一致）
$sizes = @{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
}

foreach ($dir in $sizes.Keys) {
    $size = $sizes[$dir]
    
    # 创建带透明背景的画布
    $bitmap = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    
    # 计算缩放比例，保持宽高比并添加内边距（模拟 flutter_launcher_icons 的行为）
    $padding = [math]::Round($size * 0.1)  # 10% padding
    $drawSize = $size - 2 * $padding
    
    # 居中绘制
    $x = $padding
    $y = $padding
    $graphics.DrawImage($original, $x, $y, $drawSize, $drawSize)
    
    $graphics.Dispose()
    
    $output = "d:\UserData\Desktop\my_proj\mooknote\android\app\src\main\res\$dir\ic_launcher2.png"
    $bitmap.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    
    Write-Host "Generated $output (${size}x${size}) with padding"
}

$original.Dispose()
Write-Host "Done!"

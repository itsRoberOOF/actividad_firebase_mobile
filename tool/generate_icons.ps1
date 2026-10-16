Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$sky = [System.Drawing.ColorTranslator]::FromHtml('#37BCE8')
$ink = [System.Drawing.ColorTranslator]::FromHtml('#102B3C')
$white = [System.Drawing.Color]::White

function New-VideotecaIcon {
    param([int]$size, [string]$destination)

    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear($sky)

    $x = $size * 0.20
    $y = $size * 0.20
    $side = $size * 0.60
    $radius = $size * 0.15
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddArc($x, $y, $radius * 2, $radius * 2, 180, 90)
    $path.AddArc($x + $side - $radius * 2, $y, $radius * 2, $radius * 2, 270, 90)
    $path.AddArc($x + $side - $radius * 2, $y + $side - $radius * 2, $radius * 2, $radius * 2, 0, 90)
    $path.AddArc($x, $y + $side - $radius * 2, $radius * 2, $radius * 2, 90, 90)
    $path.CloseFigure()
    $whiteBrush = [System.Drawing.SolidBrush]::new($white)
    $inkBrush = [System.Drawing.SolidBrush]::new($ink)
    $graphics.FillPath($whiteBrush, $path)

    $points = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new($size * 0.44, $size * 0.37),
        [System.Drawing.PointF]::new($size * 0.44, $size * 0.63),
        [System.Drawing.PointF]::new($size * 0.65, $size * 0.50)
    )
    $graphics.FillPolygon($inkBrush, $points)

    $directory = Split-Path -Parent $destination
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    $inkBrush.Dispose()
    $whiteBrush.Dispose()
    $path.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

$icons = @{
    'web\favicon.png' = 32
    'web\icons\Icon-192.png' = 192
    'web\icons\Icon-512.png' = 512
    'web\icons\Icon-maskable-192.png' = 192
    'web\icons\Icon-maskable-512.png' = 512
    'android\app\src\main\res\mipmap-mdpi\ic_launcher.png' = 48
    'android\app\src\main\res\mipmap-hdpi\ic_launcher.png' = 72
    'android\app\src\main\res\mipmap-xhdpi\ic_launcher.png' = 96
    'android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png' = 144
    'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png' = 192
}

foreach ($entry in $icons.GetEnumerator()) {
    New-VideotecaIcon -size $entry.Value -destination (Join-Path $projectRoot $entry.Key)
}

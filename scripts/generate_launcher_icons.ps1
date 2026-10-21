$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$workspace = Split-Path -Parent $PSScriptRoot
$logo = [System.Drawing.Image]::FromFile((Join-Path $workspace 'assets/images/logo.png'))
try {
    $densities = @{ 'mdpi' = 1; 'hdpi' = 1.5; 'xhdpi' = 2; 'xxhdpi' = 3; 'xxxhdpi' = 4 }
    foreach ($density in $densities.GetEnumerator()) {
        $directory = Join-Path $workspace "android/app/src/main/res/mipmap-$($density.Key)"
        foreach ($adaptive in @($false, $true)) {
            $size = [int]($(if ($adaptive) { 108 } else { 48 }) * $density.Value)
            $bitmap = [System.Drawing.Bitmap]::new($size, $size)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $background = if ($adaptive) { [System.Drawing.Color]::Transparent } else { [System.Drawing.Color]::FromArgb(255, 255, 248, 244) }
                $graphics.Clear($background)
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                # Keep the logo within the safe area of circular and squircle launchers.
                $extent = $size * $(if ($adaptive) { 2 / 3 } else { .88 })
                $scale = $extent / [Math]::Max($logo.Width, $logo.Height)
                $width = [single]($logo.Width * $scale)
                $height = [single]($logo.Height * $scale)
                $graphics.DrawImage($logo, [single](($size - $width) / 2), [single](($size - $height) / 2), $width, $height)
                $name = if ($adaptive) { 'ic_launcher_foreground.png' } else { 'ic_launcher.png' }
                $bitmap.Save((Join-Path $directory $name), [System.Drawing.Imaging.ImageFormat]::Png)
            } finally {
                $graphics.Dispose()
                $bitmap.Dispose()
            }
        }
    }
} finally {
    $logo.Dispose()
}

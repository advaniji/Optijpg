# OptiJPG - Smart JPEG Optimizer
# Credits: Developed by Advaniji

$TMP_DIR = "$env:TEMP\jpeg_optimizer"
$QUALITY = 100                # Maximum quality setting
$PRESERVE_METADATA = $true    # Keep EXIF/GPS data by default
$KEEP_ORIGINAL = $false       # Replaces originals by default

# Visual Feedback
$SUCCESS = "✅"
$INFO = "ℹ️"
$WARNING = "⚠️"
$ERROR = "❌"

# Display Script Header
Write-Host "`n----- OptiJPG - Smart JPEG Optimizer -----"
Write-Host "Developed by Advaniji`n"

# Setup environment
if (Test-Path $TMP_DIR) {
    Remove-Item -Recurse -Force $TMP_DIR
}
New-Item -ItemType Directory -Force -Path $TMP_DIR

# Check for mozjpeg
if (-not (Get-Command mozjpeg -ErrorAction SilentlyContinue)) {
    Write-Host "$ERROR 'mozjpeg' not found. Please install it first."
    exit 1
}

# Function to test compression with different parameters
function Test-Compression {
    param (
        [string]$input
    )

    $R0 = [System.IO.Path]::GetTempFileName()

    $best_size = [Int64]::MaxValue
    $best_params = ""

    # Define parameter sets for compression
    $param_sets = @(
        "-dct float -quant-table 1 -nojfif -dc-scan-opt 2",
        "-dct float -quant-table 2 -nojfif -dc-scan-opt 2",
        "-dct float -quant-table 3 -nojfif -dc-scan-opt 2",
        "-dct float -tune-ms-ssim -nojfif -dc-scan-opt 2",
        "-dct float -tune-ms-ssim -quant-table 3 -nojfif -dc-scan-opt 2",
        "-dct float -tune-ssim -nojfif -dc-scan-opt 2",
        "-dct float -tune-ssim -quant-table 3 -nojfif -dc-scan-opt 2"
    )

    foreach ($param in $param_sets) {
        try {
            $cmd = "mozjpeg -memdst $param `"$input`" > $R0 2>&1"
            Invoke-Expression $cmd

            $compressed_size = (Get-Item $R0).Length

            if ($compressed_size -lt $best_size) {
                $best_size = $compressed_size
                $best_params = $param
            }
        }
        catch {
            Write-Host "$ERROR Compression failed for $input with parameters: $param"
        }
    }

    Remove-Item $R0 -Force
    return $best_params
}

# Function to optimize a single image
function Optimize-Image {
    param (
        [string]$input
    )
    
    Write-Host "$INFO Processing: $(Split-Path -Leaf $input)"
    
    $best_params = Test-Compression -input $input
    $temp_output = "$TMP_DIR\$(Split-Path -Leaf $input)"
    
    try {
        $cmd = "mozjpeg -memdst $best_params `"$input`" > `"$temp_output`""
        Invoke-Expression $cmd
        
        $original_size = (Get-Item $input).length
        $new_size = (Get-Item $temp_output).length
        
        if ($new_size -lt $original_size) {
            Write-Host "$SUCCESS Size reduced: $([math]::Round($original_size / 1KB))KB → $([math]::Round($new_size / 1KB))KB"
            
            # Replace original file
            Move-Item $temp_output $input -Force
        } else {
            Write-Host "$WARNING No optimization needed - file already optimal"
            Remove-Item $temp_output -Force
        }
    }
    catch {
        Write-Host "$ERROR Error processing image: $input"
    }
}

# Handle drag-and-drop input
$FILES = @()
foreach ($arg in $args) {
    if (Test-Path $arg -PathType Container) {
        Get-ChildItem $arg -Recurse -Include *.jpg,*.jpeg | ForEach-Object {
            $FILES += $_.FullName
        }
    }
    elseif (Test-Path $arg -PathType Leaf) {
        $FILES += $arg
    }
}

# Main processing
if ($FILES.Count -eq 0) {
    Write-Host "$WARNING No valid files/folders provided"
    exit 1
}

Write-Host "$INFO Found $($FILES.Count) files to process"
foreach ($file in $FILES) {
    Optimize-Image -input $file
}

Write-Host "$SUCCESS All optimizations complete! Original files were replaced.`n"
Write-Host "----- End of Optijpg -----"

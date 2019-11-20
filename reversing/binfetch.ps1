param (
    [parameter(Mandatory=$true)][string]$inFile,
    [parameter(Mandatory=$true)][string]$outPath
)
$filePath = Resolve-Path $inFile
$fileName = Split-Path -Path $filePath -Leaf
$modules = Start-Process -PassThru $filePath | Get-Process -Module 
echo "Found the following modules:"
echo ($modules).FileName
$compress = @{
    LiteralPath = ($modules).FileName
    CompressionLevel = "Fastest"
    DestinationPath = $outPath + $fileName + "_packed.zip"
}
Compress-Archive @compress
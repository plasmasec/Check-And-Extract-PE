#Function that Receives input directory with zip files (archive files). extract the files, specific PE files. creating a folder for each archive.
# Function to delete non-PE files and empty directories after extraction

function Check-And-Extract-PE {
    param (
        [Parameter(Mandatory=$true)]
        [string]$directoryPath,
        [int]$timeoutInSeconds = 300  # Timeout limit in seconds
    )

    # Full path to 7z executable
    $sevenZipPath = "C:\Program Files\7-Zip\7z.exe"

    if (-not (Test-Path $sevenZipPath)) {
        Write-Host "7-Zip not found at $sevenZipPath. Please check the path."
        return
    }

    # Get all compressed files (ZIP, RAR, and 7z) in the directory
    $compressedFiles = Get-ChildItem -Path $directoryPath -Recurse -Include *.zip, *.rar, *.7z

    foreach ($compressedFile in $compressedFiles) {
        try {
            Write-Host "Processing archive: $($compressedFile.FullName)"

            # Start a stopwatch to track the extraction time
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            # List the contents of the archive using 7z's 'l' command
            $archiveList = & $sevenZipPath l $compressedFile.FullName 2>&1

            # Adjust the regex to properly capture valid file paths ending in PE extensions
            $peExtensions = "\.(exe|dll|cpl|com|msi|ocx|sys|scr)$"
            $peFilesToExtract = @($archiveList | Where-Object { $_ -match $peExtensions } | ForEach-Object {
                # Improved line parsing to ensure correct file paths are captured
                $line = $_ -replace '\s+', ' '  # Normalize multiple spaces in the output
                $filePath = $line -split ' ', 6 | Select-Object -Last 1  # Get the last part, which is the file path
                if ($filePath -match $peExtensions) {
                    return $filePath
                }
            })

            if ($peFilesToExtract.Count -gt 0) {
                # Create a folder for the archive based on the archive's name
                $extractedParentFolder = Join-Path $directoryPath ([System.IO.Path]::GetFileNameWithoutExtension($compressedFile.FullName))
                if (-not (Test-Path $extractedParentFolder)) {
                    Write-Host "Creating folder: $extractedParentFolder"
                    New-Item -ItemType Directory -Path $extractedParentFolder -Force | Out-Null
                }

                # Extract only the PE files (ignore others)
                foreach ($peFile in $peFilesToExtract) {
                    if (-not [string]::IsNullOrWhiteSpace($peFile)) {
                        

                        $fileNameOnly = [System.IO.Path]::GetFileName($peFile)
                        $outputFilePath = Join-Path $extractedParentFolder $fileNameOnly
                        if (-not (Test-Path $outputFilePath)) {
                            Write-Host "Extracting PE file: $peFile"
                            Write-Host "New-Path: $outputFilePath"

                            # Extract the specific PE file
                            $command = "& `"$sevenZipPath`" e `"$($compressedFile.FullName)`" `"$peFile`" -o`"$extractedParentFolder`" -y"
                            Write-Host "Running command: $command"

                            # Execute the extraction command
                            $extractCommand = Invoke-Expression $command 2>&1

                            # Verify if the PE file was successfully extracted
                            if (Test-Path $outputFilePath) {
                                Write-Host "Extraction successful for: $fileNameOnly"
                            } else {
                                Write-Host "Error: File not found after extraction: $outputFilePath"
                            }

                            # Check for timeout and skip if exceeded
                            if ($stopwatch.Elapsed.TotalSeconds -ge $timeoutInSeconds) {
                                Write-Host "Timeout reached for archive $($compressedFile.FullName), skipping to next."
                                break
                            }
                        }
                        
                    }
                }
            } else {
                Write-Host "No PE files found in $($compressedFile.FullName). Skipping..."
                Remove-Item $compressedFile -Force
                if(-not (Test-Path $compressedFile)) {
                    Write-Host "Deleted $compressedFile"
                }
            }

        } catch {
            Write-Host "Error processing $($compressedFile.FullName): $_"
        }
    }
}

# Function to delete non-PE files and empty directories after extraction
function Remove-NonPEFiles-AndEmptyDirectories {
    param (
        [string]$directoryPath
    )

    $peExtensions = "\.(exe|dll|cpl|com|msi|ocx|sys|scr)$"
    $directories = Get-ChildItem -Path $directoryPath -Directory -Recurse

    foreach ($dir in $directories) {
        # Check for non-PE files and delete them
        $files = Get-ChildItem -Path $dir.FullName -Recurse | Where-Object { -not ($_.FullName -match $peExtensions) }
        foreach ($file in $files) {
            Write-Host "Deleting non-PE file: $($file.FullName)"
            Remove-Item $file.FullName -Force
        }

        # Delete empty directories
        if (-not (Get-ChildItem $dir.FullName -Recurse | Where-Object { $_.PSIsContainer -eq $false })) {
            Write-Host "Deleting empty directory: $($dir.FullName)"
            Remove-Item $dir.FullName -Recurse -Force
        }
    }
}

# Example usage
$directoryPath = "E:\malware_datalake_abuse.ch_urlhaus\githubDownload-old"
Check-And-Extract-PE -directoryPath $directoryPath

# Remove non-PE files and any empty directories
Remove-NonPEFiles-AndEmptyDirectories -directoryPath $directoryPath

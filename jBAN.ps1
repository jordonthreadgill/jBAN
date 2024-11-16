#jBAN = jordon's Boot And Nuke
#created: 03/17/2018
#last modified: 11/9/2024
#
#Must run PowerShell as Admin!
#PowerShell 2-5 friendly.  Works in 7, however, 7 is non-default for Windows.
#Using a Professional version of Windows OS allows for this script to use Bitlocker.
#Using a Server version of Windows OS allows for ReFS file systems to be used.  See Readme.md for notes.
#
#It's probably a good idea to remove any prior disk encryptions to have an easier start,
#however, not required.
#
#!!! DISCLAIMER: !!!
#I offer NO warranty, support, or liability.  If you run this script, you are doing so at your own risk.
#This disclaimer lives in perpetuity throughout the Universe and Multiverse.
#!!!!
#
#
#region EXAMPLES:
<#
Example 1) Wont spam or format anything yet - just shows you what's available.
-showDriveLetters is a Switch.  No input received.  Shouldn't be combined with other Switches or Parameters.

jBAN -showDriveLetters


Example 2) Spams and formats the drive indicated, and will output the original drive details for record to your desktop.
-keepOriginalDeets is a Switch.  No input received.  Can be combined with other Switches and Parameters.

jBAN -keepOriginalDeets -driveLetter b


Example 3) Spams and formats the drive designated without saving any logs to your desktop.
-driveLetter is a String input Parameter.  For wiping techniques to execute, you must input a driveLetter.

jBAN -driveLetter b


Example 4) Make things look more complicated by using a unique guid for each file name instead of a numbered count increment.
-usGuidsForNames is a Switch.  No input received.  Can be combined with other Switches and Parameters.

jBAN -driveLetter b -useGuidsForNames


Example 5) Corruption pass will wildy destroy your files one at a time.
-corruptionPass is a Switch.  No input received.  Can be combined with other Switches and Parameters.

jBAN -driveLetter b -useGuidsForNames -corruptionPass


Example 6) Turns this Pwsh session into a listener for newly attached drives.  If detected, it will perform a quick format unless you spam Ctrl-C to cancel.
Threshold creates a 2-second buffer to warn me before the new drive is formated.
-instantDriveDeath is a Switch.  No input received.  Shouldn't be combined with other Switches.
-threshold is a String input Parameter.  If nothing is input here, there is a 6-second default coded in.  However, you can input your prefered second-tollerance.
For fastest results, set it 0 or 1.

jBAN -instantDriveDeath -threshold 2


Example 7) Using a period symbol before running a function allows the variables of that function to be retained a bit more.  This is helpful when troubleshooting.

. jBan -driveLetter b -useGuidsForNames -corruptionPass
#>
#endregion

function jBAN {
    param(
        #[parameter(mandatory=$true)]
        [string]$driveLetter,
        [switch]$keepOriginalDeets,
        [switch]$addEncryptionPass,
        [switch]$useGuidsForNames,
        [switch]$showDriveLetters,
        [switch]$instantDriveDeath,
        [int]$threshold,
        [switch]$corruptionPass
    )

    $duration=[system.diagnostics.stopwatch]::startnew()
    write-host -f c "Started at $((get-date).tostring('MM/dd/yyyy hh:mm:ss tt'))"

    #region Pre-reqs check
    $osVersionCheck = (get-ciminstance -classname Win32_operatingsystem).caption
    if ($osVersionCheck -notlike "*pro*" -and $osVersionCheck -notlike "*server*" -and $addEncryptionPass){
        $bitlockerCheckPassed = $false
        write-host ""
        write-host -f yellow "This OS is not a Professional version with Bitlocker."
        write-host "Current OS: $osVersionCheck"
        break
        return{}
    }
    elseif ($osVersionCheck -like "*pro*" -and $addEncryptionPass -and $osVersionCheck -notlike "*server*"){
        $bitlockerCheckPassed = $true
    }
    if ($osVersionCheck -like "*server*"){
        $refsAllowed = $true
    }

    $fatDiskCheck = (get-volume -driveletter $driveletter -erroraction silentlycontinue).size
    $fat32Allow = 34359738368
    $fatAllow = 4294967295
    $noFAT32=$false
    $noFAT=$false
    if ($fatDiskCheck -gt $fat32Allow){
        $noFAT32 = $true
    }
    if ($fatDiskCheck -gt $fatAllow){
        $noFAT = $true
    }

    #Initial Drives Inspection
    $initialDisks = get-disk
    $initialVolumes = get-partition | ? {$_.isBoot -ne $true -and $_.type -ne 'system' -and $_.type -ne 'reserved' -and $_.type -ne 'recovery'} | % { get-volume -driveletter $($_.driveletter) -erroraction silentlycontinue }
    foreach ($iv in $initialVolumes){
        if ($iv.filesystemtype -like "*unknown*" -or $iv.filesystemtype -like "*raw*"){
            write-host ''
            write-host -f y 'Just a note - be aware:'
            write-host -f y "Drive Letter '$($iv.driveletter)' has a File System that is not ready..."
            write-host -f y "Drive Letter '$($iv.driveletter)' File System Type = $($iv.filesystemtype)"
            write-host ''
        }
    }
    #endregion

    #region internal functions and variables
    function show-Letters{
        $drives = get-psdrive | select name,description | % { $_ | ? {$_.name.length -eq 1 -and $_.name -notlike "*c*"} }
        $drives = get-disk | select name,description | % { $_ | ? {$_.name.length -eq 1 -and $_.name -notlike "*c*"} }
        write-host "Letters:  Descriptions:"
        $drives | % { write-host "$($_.name)         $($_.description)" }
        write-host ''
    }
    function get-fileName{
        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
        $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $OpenFileDialog.initialDirectory = "$($env:userprofile)\desktop"
        $OpenFileDialog.filter = "All files (*.*)| *.*"
        $OpenFileDialog.ShowDialog() | out-null
        $OpenFileDialog.filename
    }
    function cat-Spam{
        write-host ''
        write-host -f magenta "Cat Spamming..."

        $pass++
        $i=0 #file name number
        $ii=0 #directories count
        $iii=0 #file count in the directories

        #make the cat pics locally available to the drive for fastest resuse
        $startCopy1 = copy-item -path $($pic1.FullName) -destination $nameLane1 -force -confirm:$false -erroraction silentlycontinue -errorvariable copyLogs
        if (!($startCopy1) -and $copyLogs[0].message -like "*The volume does not contain a recognized file system*"){
            try{
                . bump-FileSystem
                start-sleep -s 30
            }
            catch{}

            $startCopy1 = copy-item -path $($pic1.FullName) -destination $nameLane1 -force -confirm:$false -erroraction silentlycontinue -errorvariable copyLogs
        }
        $filesCount++
        [int64]$dataSize = $dataSize + $($pic1.length)
        $startCopy2 = copy-item -path $($pic2.FullName) -destination $nameLane2 -force -confirm:$false -erroraction silentlycontinue -errorvariable copyLogs
        $filesCount++
        [int64]$dataSize = $dataSize + $($pic2.length)

        #Loop of work
        $pics=@()
        $obj = [pscustomobject]@{cat = $($pic1.length)}; $pics+=$obj
        $obj = [pscustomobject]@{cat = $($pic2.length)}; $pics+=$obj
        [int]$largest = $pics.cat | sort | select -last 1
        [int64]$used = $($volume.size) - $($volume.SizeRemaining)
        [int64]$full = $($volume.size) - ($largest * 3)  ##THIS LINE DEALS IN THE REMAINING FILL SIZE 'BUFFER'  Try not to let the drive get too full...
        while ($used -lt $full){
            $i++; $iii++

            if ($iii -eq 1){
                $ii++; $dirsCount++

                $dirRoot = "$driveLetter`:" 
                $dirName = "fatcatpants_$ii"
                $outFolder = "$dirRoot\$dirName"
                if (!(test-path $outFolder)){
                    new-item -itemtype directory -path $outFolder # | out-null
                }
            }

            # UseGuidsForNames -- controls the file names
            if ($useGuidsForNames -like $true){
                $nameA = "$((new-guid).guid).jpg"
                $nameB = "$((new-guid).guid).jpg"

                $name1 = "$outFolder\$nameA"
                $name2 = "$outFolder\$nameB"
            }
            elseif ($useGuidsForNames -notlike $true){
                $number = '{0:d24}' -f $i
                $nameA = "A$number.jpg"
                $nameB = "B$number.jpg"

                $name1 = "$outFolder\$nameA"
                $name2 = "$outFolder\$nameB"
            }

            #spam cat copies
            try{
                $copy = copy-item -path $nameLane1 -destination $name1 -force -confirm:$false -errorvariable copyLogs
            }
            catch{
                if ((!($copy)) -and $copyLogs[0].message -like "*There is not enough space on the disk*"){
                    write-host -f magenta 'Disk full of cat pics...'
                    
                    break #breaking to move to formatting
                }
                if ((!($copy)) -and $copyLogs[0].message -like "*Cannot find path*"){
                    write-host -f y "Source files lost."
                    
                    break
                }
            }
            $filesCount++
            [int64]$dataSize = $dataSize + $($pic1.length)
            [int64]$used = $used + $($pic1.length)

            try{
                $copy = copy-item -path $nameLane2 -destination $name2 -force -confirm:$false -errorvariable copyLogs
            }
            catch{
                if (!($copy) -and $copyLogs[0].message -like "*There is not enough space on the disk*"){
                    write-host -f magenta 'Disk full of cat pics...'
                    
                    break #breaking to move to formatting
                }
                if (!($copy) -and $copyLogs[0].message -like "*Cannot find path*"){
                    write-host -f y "Source files lost."
                    
                    break
                }
            }
            $filesCount++
            [int64]$dataSize = $dataSize + $($pic2.length)
            [int64]$used = $used + $($pic2.length)

            #folder full.  reset counter and start new Dir
            if ($iii -gt 1999){
                $iii=0
            }
        }

        #attempts to clean up YOUR local memory
        [system.gc]::collect()
    }
    function add-Bitlocker{
        
        $blCheck = get-bitlockervolume -mountpoint $driveLetter
        if (!($blCheck)){
            #TPM checking
            $tpmStatus = get-wmiobject -namespace 'Root\CIMv2\Security\MicrosoftTpm' -class Win32_Tpm -erroraction silentlycontinue
            if ($tpmStatus){
                $tpmIsActive = $($tpmStatus.isactivated_initialvalue)
                $tpmIsEnabled = $($tpmStatus.isenabled_initialvalue)
                $tpmIsOwned = $($tpmStatus.isowned_initialvalue)
                if ($tpmIsEnabled -and $tpmIsActive -and $tpmIsOwned){
                    write-host -f green "TPM is Enabled, Activated, and Owned.  It is ready for Bitlocker Encryption."
                }
                elseif(-not $tpmIsEnabled){
                    write-host "TPM Present, but NOT Enabled in BIOS/UEFI."
                    $encryptmethod = 'XtsAes256'
                }
                elseif(-not $tpmIsActive){
                    write-host "TPM is Present, but NOT Activated."
                    $encryptmethod = 'XtsAes256'
                }
                elseif(-not $tpmIsOwned){
                    write-host "TPM is Present, but Ownership has not been taken."
                    $encryptmethod = 'XtsAes256'
                }
                else{
                    write-host -f yellow "TPM is Present but not configured."
                    $encryptmethod = 'XtsAes256'
                }
            }

            #Bitlocker recovery password
            $blFileName = "$($env:temp)\$((get-date).tostring('MM-dd-yyyy')) - $driveLetter - BitLocker Encryption Recovery Password.txt"
            $recPwd = (new-bitLockerkeyprotector -mountpoint $driveLetter -recoverypasswordprotector).recoverypassword
            $recPwd | out-file -filepath $blFileName -confirm:$false -force

            #Enable Bitlocker
            write-host "Enabling Bitlocker Full Disk Encryption on $driveletter"
            $enableBitlocker = enable-bitlocker -mountpoint $driveletter -encryptionmethod $encryptmethod -tpmprotector

            # Wait until encryption completes
            do {
                $status = (get-bitLockervolume -MountPoint "$driveletter`:").EncryptionPercentage
                write-host "Encryption progress: $status%"
                Start-Sleep -Seconds 10
            } while ($status -lt 100)
            Write-Host "BitLocker encryption completed."
            start-sleep -s 10
            write-host 'Bitlocker enabled.'
            write-host -f cyan "In case of a Bitlocker emergency, Bitlocker Recovery password here:"
            write-host -f cyan $blFileName
            write-host ''
        }
    }
    function DP{
        # PowerShell to invoke CMD for Diskpart
# Prepare a diskpart script - this is a here-string.  it needs to stay far-left on the wall.
$dpScript = @"
select disk $diskNumber
clean all
"@
#OR
#$diskpartScript = "select disk $diskNumber`n" +
#                  "clean all`n"
        
        #Export script
        $dpScriptPath = "$($env:temp)\$((new-guid).guid).txt"
        $dpScript | out-file -filepath $dpScriptPath -encoding ASCII

        #Start DiskPart.exe process, Wait, and Delete temp script
        write-host -f cyan "Starting DiskPart job..."
        write-host "DiskPart can take a while to run.  If you think this process might be frozen, "
        write-host 'please Open your Task Manager and go to Performance.  If the drive is operating near 100% DiskPart is still working.'
        write-host 'IF the disk is operating near 0% and the console hasnt changed, maybe try pressing an Arrow-key in the console window.'
        write-host ''
        start-process "diskpart.exe" -wait -argumentlist "/s `"$dpScriptPath`"" -nonewwindow
        start-sleep -s 1
        #remove-item $dpScriptPath -confirm:$false -force
        write-host -f cyan "DiskPart job finished."
        write-host -f cyan ""
        
        #Update drive
        update-disk -number $diskNumber
        start-sleep -s 10
        initialize-disk -number $diskNumber -partitionstyle MBR
        $newPart = new-partition -disknumber $diskNumber -usemaximumsize -driveletter $driveLetter
        if ($newPart.driveletter -ne $driveLetter){
            set-partition -partitionnumber $($newPart.partitionnumber) -disknumber $disknumber -newdriveletter $driveLetter -confirm:$false
        }
        start-sleep -s 10
        format-volume -filesystem NTFS -driveletter $driveLetter -newfilesystemlabel $($psdrive.description) -confirm:$false
        $volumeCheck = get-volume -driveletter $driveLetter -erroraction silentlycontinue
        while (!($volumeCheck)){
            write-host 'Waiting for Volume to initialize.'
            start-sleep -s 10
            $volumeCheck = get-volume -driveletter $driveLetter -erroraction silentlycontinue
        }

        write-host 'Format complete.'
        write-host ''

        cat-spam
    }
    function custom-Patterns{
        write-host ''
        write-host 'Custom Random Patterns'
        $patterns=@()
        #$obj = [pscustomobject]@{Name = 'All Zeros'; Pattern = '0x00'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'All Ones'; Pattern = '0xFF'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Alternating Bits'; Pattern = '0xAA'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Inverted Alternating'; Pattern = '0x55'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'First Half Set'; Pattern = '0xF0'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Last Half Set'; Pattern = '0x0F'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Middle Set'; Pattern = '0xC3'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Upper Nibble Set'; Pattern = '0x8F'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Lower Nibble Set'; Pattern = '0x0F'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Maximum Negative'; Pattern = '0x80'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Minimum Positive'; Pattern = '0x01'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Endian Mark'; Pattern = '0xFE'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Data Separator'; Pattern = '0x1C'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Checksum Value'; Pattern = '0x7E'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Patterned Data'; Pattern = '0x93'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Escape Character'; Pattern = '0x1B'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Null Character'; Pattern = '0x00'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'Start of Text'; Pattern = '0x02'}; $patterns+=$obj
        $obj = [pscustomobject]@{Name = 'End of Transmission'; Pattern = '0x04'}; $patterns+=$obj
        foreach ($incr in 1..255){
            $obj = [pscustomobject]@{Name = "custom_$incr"; Pattern = "$("0x" + $('{0:x2}' -f $incr))"}
            $patterns+=$obj
        }
        $patterns = $patterns | sort {get-random}
        $n=0
        $breakInnerLoop = 'waiting'
        while (0 -lt 1 -or $breakInnerLoop -ne 'bing0'){
            $n++
            $fileTypes = "docx,pptx,xlsx,bin,odt,ods,odp,one,onepkg,pfile,xlsm,xlsb,pptm,docm,xml,rtf,csv,txt,md,json,yml,html,xml,vsd,vsdx,vst,vsdm,vsx,vsdx,zip,7z,tar,gz,bz2,rar,iso,img,cue,mkv,avi,mp4,mp3,mpg,mov,wav,flac,webm,ogg,jpg,jpeg,png,gif,bmp,tiff,psd,ai,eps,svg,raw,dng,heif,heic,flv,swf,mpg,3gp,wmv,webp,apk,dmg,exe,deb,rpm,iso,vhd,vhdx,ova,vmdk,sql,mdf,ldf,bak,dmp,dbf,pdb,sqlite,mdb,accdb"
    
            foreach ($ft in $fileTypes.split(',')){
                if ($breakInnerLoop -eq 'bing0'){
                    break
                }
                #Open disk file path in a way that aims to retain consistent access
                #$diskPath = "$driveletter`:\blackHole$($n).$ft"
                $diskPath = "$driveletter`:\$((new-guid).guid).$ft"
                $handle = [system.io.file]::openwrite($diskPath)

                try {
                    foreach ($p in ($patterns | ? {$_.pattern -ne '0x00'})) {
                        if ($breakInnerLoop -eq 'bing0'){
                            break
                        }
                        if (![string]::isnullorempty($p.pattern) -and $p.pattern.startswith("0x")) {
                            try{
                                $blockSize = 700KB  # 1 MB block size for testing
                                $hex = [convert]::tobyte($p.pattern.trimstart('0x'), 16)
                            }
                            catch{
                                write-host "Warning: Could not parse pattern $($p.pattern) - skipping."
                                continue
                            }

                            if ($hex){
                                # Build the buffer with the hex pattern
                                $buffer = new-object byte[] $blockSize
                                for ($i = 0; $i -lt $buffer.length; $i++) {
                                    $buffer[$i] = $hex
                                }

                                # Stream pattern to file
                                $totalBytesWritten = 0
                                $targetSize = 10MB  # 10MB = turns out to be 2.7GB when $blockSize is 1024KB
                                
                                $volumeWatch = get-volume -driveletter $driveletter
                                $used = ($volumeWatch.size -$volumeWatch.sizeremaining)
                                while ($totalBytesWritten -lt $targetSize -and $breakInnerLoop -ne 'bing0') {
                                    if ($used -gt ($volumeWatch.Size - 25389440)){
                                        $breakInnerLoop = 'bing0'
                                        write-host "Disk is full."
                                        $handle.close()
                                        return{}
                                    }
                                    $bytesToWrite = [math]::min($buffer.length, $targetSize - $totalBytesWritten)
                                    try {
                                        $handle.write($buffer, 0, $bytesToWrite)
                                    } 
                                    catch {
                                        break
                                    }
                                    $totalBytesWritten += $bytesToWrite

                                    write-progress -activity "writting CustomPatterns" -status "Writing Pattern" -percentcomplete (($totalBytesWritten / $targetSize) * 100)
                                    $volumeWatch = get-volume -driveletter $driveletter
                                    $used = ($volumeWatch.size -$volumeWatch.sizeremaining)
                                }
                                if ($used -gt ($volumeWatch.Size - 45389440)){
                                    $handle.close()
                                    return {}
                                }
                            }

                        } else {
                            write-host "Warning: Pattern $($p.pattern) is invalid - skipping."
                            continue
                        }
                    }
                }
                catch {
                    write-host "Disk is full"

                    break
                }
                finally {
                    if ($handle -ne $null) {
                        $handle.close()
                    }
                }

            }
        }
    }  
    function corruption-Pass  {
        function corrupt-File {
            param (
                [parameter(mandatory=$true)]
                [string]$filePath
            )
            #Define corruption range as 75% to 100%
            [double]$injectionFractionMin = 0.75
            [double]$injectionFractionMax = 1.0 

            # Get file info and open a file stream
            $fileInfo = get-item -path $filePath
            $fileSize = $fileInfo.length
            $fileStream = [system.io.file]::openwrite($filePath)
    
            try {
                #Calculate a random corruption size as 75% to 100% of the file size
                $injectionRatio = get-random -minimum $injectionFractionMin -maximum $injectionFractionMax
                $injectionSize = [math]::floor($fileSize * $injectionRatio)

                #Choose a random start position to inject corruption data
                $startOffset = get-random -minimum 0 -maximum ($fileSize - $injectionSize)

                #Generate random cryptographic bytes for corruption
                $rng = [system.security.cryptography.randomnumbergenerator]::create()
                $corruptData = new-object byte[] $injectionSize
                $rng.getbytes($corruptData)

                #Position the file stream and write corruption data
                $fileStream.position = $startOffset
                $fileStream.write($corruptData, 0, $corruptData.length) | out-null
                
                #write-host ""
                #write-host "Corruption complete: Injected $injectionSize random bytes starting at offset $startOffset"
            }
            finally {
                #Close the file stream
                $fileStream.close()
            }
        }

        write-host "Working on the Corruption Pass"  #""
        $files = get-childitem -force -recurse -file -path "$driveLetter`:" -erroraction silentlycontinue | select -expand fullname
        write-host "Files found:  $($files.count)"
        $f0 = 0
        foreach ($f in $files){
            $f0++; write-progress -activity "Corruption Pass" -status "$f0 of $($files.count)"

            corrupt-file -FilePath $f
        }
        write-host ''
        write-host 'Corruption pass complete.'
    }
    function instantDriveDeath {
        $dDisks = get-disk
        $osDisk = $dDisks | ? {$_.issystem -eq $true}
        $currentDrives = $dDisks | ? {$_.number -ne $($osDisk.number)}
        while (0 -lt 1){
            $checkDisks = get-disk | ? {$_.number -ne $($osDisk.number)}
            foreach ($check in $checkDisks){
                $newCheck = $currentDrives | ? {$_.number -eq $($check.number)}
                if (!($newCheck)){
                    $dDriveLetter = get-partition -disknumber $($check.DiskNumber) | select -expand driveletter
                    $dVolume = get-psdrive | ? {$_.name -eq $dDriveLetter}
                    write-host ''
                    write-host -f cyan "Found a new drive to kill!"
                    write-host "Disk Number: $($check.DiskNumber)"
                    write-host "Disk Friendly Name: $($check.FriendlyName)"
                    write-host "Drive Letter: $dDriveLetter"
                    write-host "Volume Name: $($dVolume.description)"
                    write-host ''
                    write-host ''
                    write-warning "You have less than $threshold`-seconds to spam Ctrl-C to Cancel the Kill."
                    start-sleep -m ($threshold * 1000)
                    #format-volume -driveletter $dDriveLetter -filesystem NTFS -confirm:$false -force
                    #$volumeCheck = get-volume -driveletter $driveLetter -erroraction silentlycontinue
                    #while (!($volumeCheck)){
                        #write-host 'Waiting for Volume to initialize.'
                        #start-sleep -s 10
                        #$volumeCheck = get-volume -driveletter $driveLetter -erroraction silentlycontinue
                    #}
                    write-host ''
                    write-host -f green "$dDriveLetter`:\ should be safe for further use."
                    $currentDrives += $check 
                }
            }
        }
    }
    function bump-FileSystem{
        try{
            if ($volume.filesystemtype -like "*raw*"){
                $initDisk = initialize-disk -number $diskNumber -erroraction silentlycontinue -errorvariable initErrors
            }
        }
        catch{
            start-sleep -m 2000
            update-disk -number $diskNumber 
            start-sleep -m 2000

            continue
            
        }
        if ($volume.filesystemtype -like "*unknown*"){
            update-disk -number $diskNumber 
            start-sleep -m 2000
        }

        $checkPartitions = get-partition -disknumber $diskNumber
        if (($checkPartitions) -and ($($checkPartitions.driveletter) -ne $driveLetter)){
            try{
                $fixPart = set-partition -disknumber $diskNumber -newdriveletter $driveLetter -confirm:$false -partitionnumber $($checkPartitions.PartitionNumber)
            }
            catch{
                if ((!($fixPart)) -and $partErrors[0].message -like "*access path is already in use*"){
                    continue
                }
                else{
                    write-host ''
                    write-host 'bump-FileSystem Function failed to create a partition.'
                }

                $fixPart = $true
            }
        }
        if (($checkPartitions)  -and ($($checkPartitions.driveletter) -eq $driveLetter)){
            $pVolume = get-volume -driveletter $driveLetter
            
            $fixpart=$true
        }
        if ($fixPart){
            $fixFormat = format-volume -driveletter $driveLetter -filesystem NTFS -confirm:$false
            if ($fixFormat){
                write-host ''
                write-host 'bump-FileSystem Function fixed the volume.'

                $volume = get-volume -driveletter $driveLetter 
                $psDrive = get-psdrive -name $driveletter -erroraction silentlycontinue
                $diskPart = get-partition -driveletter $driveletter
                $diskNumber = $diskPart | select -expand disknumber

            }
            if (!($fixFormat)){
                write-host ''
                write-host 'bump-FileSystem Function failed to format the volume.'
                write-host ''
                return {}
            }
        }
    }

    #Sort out the file systems and custom functions to work
    $fileSystemsString = 'NTFS,exFat,Bitlocker,DP,customPatterns,corruptionPass'
    if ($corruptionPass -like $false){
        $fileSystemsString = $fileSystemsString.replace(',corruptionPass','')
    }
    if ($bitlockerCheckPassed -eq $false){
        $fileSystemsString = $fileSystemsString.replace(',Bitlocker','')
    }
    #if ($refsAllowed -ne $true){
        #$fileSystemsString = $fileSystemsString.replace(',ReFS','')
    #}
    if ($noFAT32 -eq $false){
        $fileSystemsString += ",FAT32" 
    }
    else {
        $fileSystemsString += ",NTFS" 
    }
    if ($noFAT -eq $false){
        $fileSystemsString += ",FAT"
    }
    else {
        $fileSystemsString += ",exFat" 
    }
    $fileSystems = $fileSystemsString.split(',') | sort {get-random}
    while ($fileSystems[0] -like "*corruptionPass*" -or $fileSystems[0] -like "*DP*"){
            $fileSystems = $fileSystemsString.split(',') | sort {get-random}
    }
    $fsCount = $fileSystems.count
    #endregion

    #region ShowDriveLetters
    if ($showDriveLetters -like $true){
        . show-letters
        break
    }
    #endregion

    #region Instant Drive Death
    if ($instantDriveDeath -like $true){
        if ($threshold -like $null){
            $threshold = 6
        }
        instantDriveDeath -threshold $threshold
        break
    }
    #endregion

    #region BLOCK C drive wiping
    if ($driveLetter -like "*c*" -or $driveLetter -like $null -or (get-partition -driveletter $driveLetter).isboot -like $true){
        write-warning "I will not let you wipe a C drive (boot disk).  Pick a different Drive."
        show-letters

        break
    }
    $driveLetter = $driveLetter.trim()
    if ($driveLetter.length -gt 1){
        write-warning "Your DriveLetter entry exceeds the string limit of 1 character.  Please retry entering a single drive letter."
        show-letters 

        break
    }

    [string]$filter = "DeviceId=" + "'" + $driveLetter + ":" + "'"
    #endregion

    #region keepOriginalDeets -- current drive info/state + current file system state evaluation and repair
    $volume = get-volume -driveletter $driveLetter 
    $psDrive = get-psdrive -name $driveletter -erroraction silentlycontinue
    $diskPart = get-partition -driveletter $driveletter
    $diskNumber = $diskPart | select -expand disknumber
    if ($volume.filesystemtype -like "*unknown*" -or $volume.filesystemtype -like "*raw*"){
        write-host ''
        write-host -f c 'The Drive has no usuable file system.  Attempting correction.'
        
        start-sleep -s 4
        . bump-FileSystem
    }
    if ($keepOriginalDeets){
        $thisDrive=@{
            volumeObjectId = $($volume.ObjectId)
            passThroughClass = $($volume.PassThroughClass)
            passThroughIds = $($volume.PassThroughIds)
            passThroughNamespace = $($volume.PassThroughNamespace)
            passThroughServer = $($volume.PassThroughServer)
            uniqueId = $($volume.UniqueId)
            allocationUnitSize = $($volume.AllocationUnitSize)
            dedupMode = $($volume.DedupMode)
            driveLetter = $($volume.DriveLetter)
            fileSystem = $($volume.FileSystem)
            fileSystemLabel = $($volume.FileSystemLabel)
            fileSystemType = $($volume.FileSystemType)
            healthStatus = $($volume.HealthStatus)
            operationStatus = $($volume.OperationalStatus)
            path = $($volume.Path)
            size = $($volume.Size)
            sizeRemaining = $($volume.SizeRemaining)
            psComputerName = $($volume.PSComputerName)
            root = $($psDrive.Root)
            description = $($psDrive.Description)
            name = $($psDrive.Name)
            currentLocation = $($psDrive.CurrentLocation)
            partitionOperationalStatus = $($diskPart.OperationalStatus) 
            partitionType = $($diskPart.Type) 
            partitionDiskPath = $($diskPart.DiskPath) 
            partitionObjectId = $($diskPart.ObjectId) 
            partitionPassThroughClass = $($diskPart.PassThroughClass) 
            partitionPassThroughIds = $($diskPart.PassThroughIds) 
            partitionPassThrouhgNamesapce = $($diskPart.PassThroughNamespace) 
            partitionPassThroughServer = $($diskPart.PassThroughServer) 
            partitionUniqueId = $($diskPart.UniqueId) 
            partitionAccessPaths = $($diskPart.AccessPaths) 
            partitionDiskId = $($diskPart.DiskId) 
            partitionDiskNumber = $($diskPart.DiskNumber) 
            partitionDriveLeter = $($diskPart.DriveLetter) 
            partitionGptType = $($diskPart.GptType) 
            partitionGuid = $($diskPart.Guid) 
            partitionIsActive = $($diskPart.IsActive) 
            partitionIsBoot = $($diskPart.IsBoot) 
            partitionIsDAX = $($diskPart.IsDAX) 
            partitionIsHidden = $($diskPart.IsHidden) 
            partitionIsOffline = $($diskPart.IsOffline) 
            partitionIsReadOnly = $($diskPart.IsReadOnly) 
            partitionIsShadowCopy = $($diskPart.IsShadowCopy) 
            partitionIsSystem = $($diskPart.IsSystem) 
            partitionMbrType = $($diskPart.MbrType) 
            partitionNoDefaultDriveLetter = $($diskPart.NoDefaultDriveLetter) 
            partitionOffset = $($diskPart.Offset) 
            partitionPartitionNumber = $($diskPart.PartitionNumber) 
            partitionSize = $($diskPart.Size) 
            partitionTransitionState = $($diskPart.TransitionState) 
            partitionPSComputerName = $($diskPart.PSComputerName) 
            partitionCimClass = $($diskPart.CimClass) 
            partitionCimInstanceProperties = $($diskPart.CimInstanceProperties) 
            partitionCimSystemProperties = $($diskPart.CimSystemProperties) 
        }
        $thisDrive | convertto-json -depth 4 | out-file -filepath "$($env:userprofile)\desktop\$((get-date).tostring('MM-dd-yyyy')) - jBAN - $driveLetter drive info - noProvider.json"
        $thisDrive2=@{
            volumeObjectId = $($volume.ObjectId)
            passThroughClass = $($volume.PassThroughClass)
            passThroughIds = $($volume.PassThroughIds)
            passThroughNamespace = $($volume.PassThroughNamespace)
            passThroughServer = $($volume.PassThroughServer)
            uniqueId = $($volume.UniqueId)
            allocationUnitSize = $($volume.AllocationUnitSize)
            dedupMode = $($volume.DedupMode)
            driveLetter = $($volume.DriveLetter)
            fileSystem = $($volume.FileSystem)
            fileSystemLabel = $($volume.FileSystemLabel)
            fileSystemType = $($volume.FileSystemType)
            healthStatus = $($volume.HealthStatus)
            operationStatus = $($volume.OperationalStatus)
            path = $($volume.Path)
            size = $($volume.Size)
            sizeRemaining = $($volume.SizeRemaining)
            psComputerName = $($volume.PSComputerName)
            root = $($psDrive.Root)
            description = $($psDrive.Description)
            provider = $($psDrive.Provider)
            name = $($psDrive.Name)
            currentLocation = $($psDrive.CurrentLocation)
            partitionOperationalStatus = $($diskPart.OperationalStatus) 
            partitionType = $($diskPart.Type) 
            partitionDiskPath = $($diskPart.DiskPath) 
            partitionObjectId = $($diskPart.ObjectId) 
            partitionPassThroughClass = $($diskPart.PassThroughClass) 
            partitionPassThroughIds = $($diskPart.PassThroughIds) 
            partitionPassThrouhgNamesapce = $($diskPart.PassThroughNamespace) 
            partitionPassThroughServer = $($diskPart.PassThroughServer) 
            partitionUniqueId = $($diskPart.UniqueId) 
            partitionAccessPaths = $($diskPart.AccessPaths) 
            partitionDiskId = $($diskPart.DiskId) 
            partitionDiskNumber = $($diskPart.DiskNumber) 
            partitionDriveLeter = $($diskPart.DriveLetter) 
            partitionGptType = $($diskPart.GptType) 
            partitionGuid = $($diskPart.Guid) 
            partitionIsActive = $($diskPart.IsActive) 
            partitionIsBoot = $($diskPart.IsBoot) 
            partitionIsDAX = $($diskPart.IsDAX) 
            partitionIsHidden = $($diskPart.IsHidden) 
            partitionIsOffline = $($diskPart.IsOffline) 
            partitionIsReadOnly = $($diskPart.IsReadOnly) 
            partitionIsShadowCopy = $($diskPart.IsShadowCopy) 
            partitionIsSystem = $($diskPart.IsSystem) 
            partitionMbrType = $($diskPart.MbrType) 
            partitionNoDefaultDriveLetter = $($diskPart.NoDefaultDriveLetter) 
            partitionOffset = $($diskPart.Offset) 
            partitionPartitionNumber = $($diskPart.PartitionNumber) 
            partitionSize = $($diskPart.Size) 
            partitionTransitionState = $($diskPart.TransitionState) 
            partitionPSComputerName = $($diskPart.PSComputerName) 
            partitionCimClass = $($diskPart.CimClass) 
            partitionCimInstanceProperties = $($diskPart.CimInstanceProperties) 
            partitionCimSystemProperties = $($diskPart.CimSystemProperties) 
        }
        $thisDrive2 | convertto-json -depth 4 | out-file -filepath "$($env:userprofile)\desktop\$((get-date).tostring('MM-dd-yyyy')) - jBAN - $driveLetter drive info - Provider.json"
    }
    #endregion
    
    #region Counters
    $pass=0
    [int64]$dirsCount=0
    [int64]$filesCount=0
    [int64]$dataSize=0
    #endregion

    #region Select the cat pics
    ##local example to reuse cat pictures without being prompted each time
    <#
    if ($($env:computername -eq 'desktop-0015')){  ## My machine name
        $cat1 = 'C:\cat_Two.jpg'
        $cat2 = 'C:\cat_One.jpg'
        $pic1 = get-childitem -path $cat1
        $pic2 = get-childitem -path $cat2
        $nameLane1 = "$driveLetter`:\fatCatPants_A.jpg"
        $nameLane2 = "$driveLetter`:\FATcAtpAnts__B.jpg"
    }
    elseif ($($env:computername) -ne 'desktop-0015'){  ## Not My Machine = prompts
        write-host -f yellow "Select your first cat picture..."
        $cat1 = get-fileName
        write-host ''
        write-host -f cyan "Select your second cat picture..."
        $cat2 = get-fileName
        $pic1 = get-childitem -path $cat1
        $pic2 = get-childitem -path $cat2
        $nameLane1 = "$driveLetter`:\fatCatPants_A.jpg"
        $nameLane2 = "$driveLetter`:\FATcAtpAnts__B.jpg"
    }
    #>

    ##for the public
    write-host -f yellow "Select your first cat picture..."
    $cat1 = get-fileName
    write-host ''
    write-host -f cyan "Select your second cat picture..."
    $cat2 = get-fileName
    $pic1 = get-childitem -path $cat1
    $pic2 = get-childitem -path $cat2
    $nameLane1 = "$driveLetter`:\fatCatPants_A.jpg"
    $nameLane2 = "$driveLetter`:\FATcAtpAnts__B.jpg"
    #endregion 

    #region (1st pass) fills up the drive as-is, no pre-formatting done here yet
    . cat-spam
    #endregion

    #region fomatting + bigger Looping of cat-spam and other chaos
    $fsCount=0
    foreach ($fs in $fileSystems){
        $fsCount++
        #Bitlocker
        if ($fs -eq 'Bitlocker'){
            . add-Bitlocker
            start-sleep -s 60

            #if corruptionPass selected
            if ($corruptionPass -like $true -and $fsCount -eq 4){
                . corruption-Pass
            }

            #format the drive
            write-host ''
            write-host "Formatting $driveLetter to NTFS..."
            format-volume -driveletter $driveletter -force -confirm:$false -full -filesystem NTFS
            write-host 'Format complete.'
            write-host ''

            $volumeCheck = get-volume -driveletter $driveLetter -erroraction silentlycontinue
            while (!($volumeCheck)){
                write-host 'Waiting for Volume to initialize.'
                start-sleep -s 10
                $volumeCheck = get-volume -driveletter $driveLetter -erroraction silentlycontinue
            }

            . cat-spam
        }
        
        #standard file systems
        if ($fs -eq 'NTFS' -or $fs -eq 'FAT' -or $fs -eq 'exFAT' -or $fs -eq 'FAT32' -or $fs -eq 'ReFS'){
            #if corruptionPass selected
            if ($corruptionPass -like $true -and $fsCount -eq 4){
                . corruption-Pass
            }

            write-host ''
            write-host "Formatting $driveLetter to $fs..."
            
            format-volume -driveletter $driveletter -force -confirm:$false -full -filesystem $fs
            
            write-host 'Format complete.'
            write-host ''

            $volumeCheck = get-volume -driveletter $driveLetter -erroraction silentlycontinue
            while (!($volumeCheck)){
                write-host 'Waiting for Volume to initialize.'
                start-sleep -s 10
                $volumeCheck = get-volume -driveletter $driveLetter -erroraction silentlycontinue
            }

            . cat-spam
        }

        #Custom Patterns
        if ($fs -eq 'customPatterns'){
            #if corruptionPass selected
            if ($corruptionPass -like $true -and $fsCount -eq 4){
                . corruption-Pass
            }

            start-sleep -s 60

            #format the drive
            write-host ''
            write-host "Formatting $driveLetter to exFAT..."
            format-volume -driveletter $driveletter -force -confirm:$false -full -filesystem exFAT
            write-host 'Format complete.'
            write-host ''

            $volumeCheck = get-volume -driveletter $driveLetter -erroraction silentlycontinue
            while (!($volumeCheck)){
                write-host 'Waiting for Volume to initialize.'
                start-sleep -s 10
                $volumeCheck = get-volume -driveletter $driveLetter -erroraction silentlycontinue
            }

            . custom-Patterns
        }

        #DiskPart
        if ($fs -eq 'DP'){
            . DP

            . cat-spam
        }
    }

    write-host ''
    write-host -f green "All cat spamming loops complete."
    #endregion

    #region wrap up
    #now that all loops are done, final format to NTFS
    write-host ''
    write-host "Final Formatting $driveLetter to NTFS..."
    $pass++
    format-volume -driveletter $driveletter -force -confirm:$false -full -filesystem NTFS
    write-host 'Format complete.'
    write-host ''

    write-host -f green "$driveLetter is ready for you to eject and use."
    write-host ''
    write-host 'Duration:'
    $duration
    write-host ''
    write-host "Passes:  $pass"
    write-host "TotalDirectories:  $dirsCount"
    write-host "TotalFiles:  $filesCount"
    write-host "TotalDataMoved:  $($dataSize * 1GB)GB"
    write-host ''
    write-host -f c "Ended at $((get-date).tostring('MM/dd/yyyy hh:mm:ss tt'))"
    write-host ''
    #endregion    
}


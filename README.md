# About jBAN:
This repo offers a couple of versions of a solution I've been developing over the years. Inspired by the old-school DBAN application, I call this function jBAN. I've added custom features, including writing cat pics to the drive, so that if recovery is attempted, the person will be swarmed with billions of cat pics. :)

The goal was to share a fast and lightweight method to wipe drives so that data from original usage cannot be recovered. Drilling holes in drives is ineffective. Drive reuse has financial and environmental benefits.

With patience and proper technique, I believe original data can be wiped beyond recovery from hard drives, allowing them to be repurposed.  Before someone hits me with "but a super computer can unwrite it.." I will share that I have added as much randomization as possible to ensure that each time this script is run, the order is never the same.  And then where you might call out the limited number of systems to cycle through, there are multiple other custom functions that assure random data is continually iterated to exhaust my effort toward the goal.  Unless you are watching the console of the workstation that this took place on (and performed memory dumps over hours or days), it is safe to assume that any one person or system cannot reverse/un-write the data.  This script completely wipes the data from beyond repair or recovery, per my testing.

I hope it serves you well.

# WHY did I make this when there are other tools available?
- This is a lightweight script that can be run on most versions of Windows (7+).
- It doesn't require booting into an isolated OS or having a dedicated machine.
- There's no cost or licensing fees here—it's low rent, "living off the land."
- Any end user who can plug in a storage device to a Windows machine can sanitize their data.
- Users/admins/enthusiasts can explore multiple methods to wipe data, broken down into reusable steps using PowerShell code.

# Disclaimer:
!!!
I offer NO warranty, support, or liability. By running this script, you are doing so at your own risk.
This disclaimer lives in perpetuity throughout the Universe and Multiverse.
!!!

# Notes:
You must run PowerShell as admin!

This script is compatible with PowerShell 2-5 and also runs on PowerShell 7 (though not coded for multi-threaded jobs). PowerShell 7 is a non-default package, whereas versions 2-5 are typically default.

If you want to go further, try parallel jobs on cat-Spam, corruptionPass, and customPatterns. This single-threaded script already works the drive hard; multi-threading will ensure maximum disk usage (for better or worse). If you add parallel jobs, I suggest no more than three write jobs at a time.

When running on Windows Server, you can add ReFS to the FileSystemsString line. Several code segments already support it, so you’ll just need to complete any missing parts, or check back later for a ReFS function update.

Run examples are commented out in the PS1 file.

This scripts works great on USB and Memory Card storage devices that consume non-Unix file systems.  Typically non-Unix file systems show up as mounted drives when connected to a Windows environment (PNP) - they have drive letters, and/or can be seen from Computer Management > Disk Management.  A vwey popular example of a Unix-type file system that could be connected to a computer are iOS devices - Apple's APFS file system.  This file system does not allow for a script like this to be successful wiping iOS storage.  Apple's file system there just isn't fully seen to be engaged the same way - per Apple's proprietary design.  Some Android devices allow you to attach/mount the storage as a USB drive to computers.  That mount would allow this script to wipe that storage card, if that makes sense.
Works on USB Drives, Memory Cards (SD, microSD, etc), SATA or Serial connected drives, or Android mounted storage devices.
Does Not work on: Unix systems and iOS

Rumor has it that SSD drives stand a greater chance of data recovery than 'spinners,' and I mostly believe that.  However, I'm 5-for-5 on killing a SSD - was not being able to "capture the flag" in recovery testing.  Time will tell.

# About the internal functions:
Some switches and parameter patterns combinations achieve different outcomes.  See run examples are in the PS1 file.

- showDriveLetters is a Switch that simply outputs the currently detected drives/disks and how they are named.  You need a driveLetter to begin any life changing work.
- keepOriginalDeets is a Switch that captures 3 aspects of current state about the drive you selected.  The files are saved to your Desktop for your own records.  These are not logs or restoration related.
- driveLetter is a String Parameter that tells the script which Drive to work on throughout the loops.  I have tried my hardest to SAVE you from wiping your Boot disk, but please be careful.
- addEncryptionPass is a Switch that tells the script to add a loop pass which encrypts the drive with Bitlocker as another layer of data-write to the drive, additionally another layer of data to be removed.
- useGuidsForNames is a Switch that tells the script to use random guids for file names instead of allowing the default behavior to occur.  By default files are named in a numeric increment.  useGuidsForNames is more fun.
- corruptionPass is a Switch that tells the script the add a loop pass which corrupts the data it finds before formatting.  It randomly changes the bits of a file.
- instantDriveDeath is a function that turns your PowerShell session into a listener for new USB devices/drives.  Any new drives that are plugged into the machine running the script during that time are formated within moments.  This only makes one format pass making the drive less likely to execute unintended code or apps.  You should take additional steps to further wipe the device thoroughly, if that was your goal.
- threshold is a Integer Parameter that supports the instantDriveDeath switch.  If you choose not to input a threshold represented in seconds, my default is 6-seconds.  That means you have 6-seconds to spam the Ctrl-C combination to kill the job, to save the world.  If you set threshold to 0, you'd have no time and the format would be instant.

Inside this script is a function that runs everytime called customPatterns.  CustomPatterns was overthought and has a few goals in mind for the chaos that it performs.  It is the only part of my script that uses common file types.  My thought was, "Maybe someone will stop looking for jpgs..."  I wanted them to find some terribly heavy files of the other file types they might be looking for - docx, xlsx, etc.  IF anyone is going to find one these common file types, it would likely (but not likely) be one of my nightmare files here.  Some 8+ GB docx/xlsx/pptx of random hex patters.  :D 
- blockSize and targetSize are the two variables/parameters you can adjust to adjust the random pattern buffer/file sizes.

DP is an always-On internal function that consumes DiskPart to 'clean all.'

bump-FileSystem is a function that saves the day when a drive has failed to format correctly, or that has been restarted from a previously interupted or corrupted pass.

cat-Spam is the main worker function that loops cat pictures across a drive.


# PowerShell Troubleshooting:
#Freezing or Pausing:

Sometimes PowerShell can lose connection with I/O hosts, causing a session freeze. Clicking inside the console window or pressing an arrow key often resumes the session. This action refreshes PowerShell's connections to native I/O hosts, showing updated statuses and allowing code execution to continue.

I recommend keeping Task Manager open to monitor disk performance as jobs loop. If the console claims an operation is ongoing, but Task Manager shows no activity, try pressing an arrow key to continue to the next line or job.

I do have some start-sleep timers in here too.  Nothing should freeze on my side for more than 60-seconds.  If you see that the disk is non-performant for a few minutes, that is what I mean by no activity.


#Error Handling:

The script handles most known errors, so most displayed errors are not terminating but are intended as visual tracking points. If an error causes the script to break before providing a finishing summary, that is an unhandled error.

#Hardcoding Cat File Locations for Re-Running:

If you plan to re-run this script on the same machine, consider hardcoding the locations of your pictures. In the "Select the cat pics" section, there is an example commented out for guidance.

# Lastly:
If anyone successfully recovers original data from a drive after running this script, I nominate you for a Nobel Prize — You are the Data-Science GOAT!


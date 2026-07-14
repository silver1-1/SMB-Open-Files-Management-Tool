

SMB FILE LOCK MANAGEMENT TOOL - DOCUMENTATION


Author:       Mathias McDowell
Version:      1.0
Context:      Production-Grade SMB Audit Utility
Platform:     Windows Server 2012 R2 / Windows Server 2016+


1. OVERVIEW & DESCRIPTION
--------------------------------------------------------------------------------
This utility provides administrators with an interactive Command Line Interface 
(CLI) to instantly audit and terminate active Server Message Block (SMB) network 
file locks and sessions across local or remote file servers. 

Features include:
  * Dual-Mode Filtering: Seamlessly search for active handles by specific 
    Usernames or by File Name / Path string patterns.
  * Real-Time Telemetry: Tracks and prints an active, synchronized metadata grid 
    displaying Dynamic Index IDs, Client Identities, Open Mode Permissions 
    (Read/Write/Delete), and absolute UNC file system paths.
  * Automatic Ghost Lock Purges: Automatically detects, targets, and erases 
    temporary Microsoft Office/Excel owner files (~$) left behind during force 
    closes to resolve persistent "Read-Only" errors.
  * Infrastructure Session Isolation: Allows administrators to kill an entire 
    SMB connection framework for listed clients to prevent aggressive client-side 
    auto-healing reconnections.


2. SYSTEM REQUIREMENTS
--------------------------------------------------------------------------------
  * Operating System: Windows Server 2012 R2 or newer.
  * PowerShell: Version 4.0 or higher.
  * Permissions: Explicit Local/Domain Administrator privileges are required to 
    interact with underlying SMB server handle APIs.


3. EXECUTION POLICY RUNTIME DEPLOYMENT GUIDE
--------------------------------------------------------------------------------
In strict enterprise environments, execution policies may block users or 
administrators from running raw .ps1 script files directly via a double-click. 
To bypass this security restriction cleanly without altering the global 
security state of the server, deploy a dedicated Management Launcher Shortcut.

Follow these steps to configure the launcher:

STEP 1: CAPTURE THE RUNTIME ARGUMENTS
Copy the following command string to your clipboard:

  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\YourFolder\Smb-Open-Files-Managment-Tool.PS1"

  NOTE: Modify "C:\YourFolder\Smb-Open-Files-Managment-Tool.PS1" to match the 
        exact absolute folder directory where the master script is stored.

STEP 2: BUILD THE MANAGEMENT LAUNCHER
  1. Navigate to the Windows Desktop or your desired administration directory.
  2. Right-click an empty space, hover over 'New', and select 'Shortcut'.
  3. In the text field labeled "Type the location of the item:", paste the 
     complete command string copied from Step 1.
  4. Click 'Next'.
  5. Provide a professional descriptor name for the shortcut 
     (e.g., "SMB File Lock Management Tool").
  6. Click 'Finish'.

STEP 3: ENFORCE PERSISTENT ADMINISTRATIVE PRIVILEGES
Because this utility queries low-level server network handles, it must execute 
within an elevated token space.
  1. Right-click the newly created desktop shortcut and select 'Properties'.
  2. Ensure you are on the 'Shortcut' tab.
  3. Click the 'Advanced...' button located near the bottom right.
  4. Enable the checkbox option next to "Run as administrator".
  5. Click 'OK' on the Advanced window, then click 'Apply' and 'OK' on the 
     primary properties display to save configurations.


4. HOW TO RUN THE UTILITY
--------------------------------------------------------------------------------
Simply double-click your newly deployed Management Launcher Shortcut. Accept 
the standard Windows User Account Control (UAC) authorization prompt when it 
appears. The tool will initialize and print out the master engine options console 
instantly.


END OF DOCUMENTATION


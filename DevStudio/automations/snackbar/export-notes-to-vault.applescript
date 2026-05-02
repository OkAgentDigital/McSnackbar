-- export-notes-to-vault.applescript
-- Snackbar Automation Script
--
-- Created by DevStudio Integration
--
-- This script exports all notes to the vault using VAULTRUN

use framework "Foundation"
use scripting additions

-- Main handler
on run
    tell application "Snackbar"
        activate
        
        try
            -- Get all notes
            set allNotes to get notes
            
            -- Process each note and export to vault
            repeat with currentNote in allNotes
                set noteTitle to title of currentNote
                set noteContent to content of currentNote
                
                -- Use VAULTRUN to export to vault
                set resultText to trigger devstudio skill skill name "VAULTRUN" arguments ("inbox " & noteTitle)
                
                -- You could also write the content to a file in the vault
                -- This is just an example of the integration
            end repeat
            
            display notification "" & (count of allNotes) & " notes exported to vault!" with title "Snackbar"
            
            return "Exported " & (count of allNotes) & " notes to vault successfully!"
            
        on error errMsg
            display notification "Error exporting notes: " & errMsg with title "Snackbar"
            return "Error: " & errMsg
        end try
    end tell
end run

-- Handler for direct calls
on exportNotesToVault()
    tell application "Snackbar"
        activate
        
        try
            -- Get all notes
            set allNotes to get notes
            
            -- Process each note and export to vault
            repeat with currentNote in allNotes
                set noteTitle to title of currentNote
                set noteContent to content of currentNote
                
                -- Use VAULTRUN to export to vault
                set resultText to trigger devstudio skill skill name "VAULTRUN" arguments ("inbox " & noteTitle)
            end repeat
            
            return "Exported " & (count of allNotes) & " notes to vault successfully!"
            
        on error errMsg
            return "Error: " & errMsg
        end try
    end tell
end exportNotesToVault
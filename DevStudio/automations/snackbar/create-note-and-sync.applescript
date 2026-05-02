-- create-note-and-sync.applescript
-- Snackbar Automation Script
--
-- Created by DevStudio Integration
--
-- This script creates a new note and syncs it with iCloud

use framework "Foundation"
use scripting additions

-- Main handler
on run
    display dialog "Create New Note" default answer "" buttons {"Cancel", "Continue"} default button 2
    copy the result as list to {buttonPressed, textReturned}
    
    if buttonPressed is "Continue" then
        set noteTitle to textReturned
        
        display dialog "Note Content" default answer "" buttons {"Cancel", "Continue"} default button 2
        copy the result as list to {buttonPressed, textReturned}
        
        if buttonPressed is "Continue" then
            set noteContent to textReturned
            
            tell application "Snackbar"
                activate
                
                try
                    -- Create the note
                    set newNote to create note title noteTitle content noteContent tags {}
                    
                    -- Sync with iCloud
                    sync notes
                    
                    display notification "Note '" & noteTitle & "' created and synced!" with title "Snackbar"
                    
                    return "Note created and synced successfully!"
                    
                on error errMsg
                    display notification "Error: " & errMsg with title "Snackbar"
                    return "Error: " & errMsg
                end try
            end tell
        end if
    end if
end run

-- Handler for direct calls
on createNoteAndSync(titleText, contentText)
    tell application "Snackbar"
        activate
        
        try
            -- Create the note
            set newNote to create note title titleText content contentText tags {}
            
            -- Sync with iCloud
            sync notes
            
            return "Note '" & titleText & "' created and synced successfully!"
            
        on error errMsg
            return "Error: " & errMsg
        end try
    end tell
end createNoteAndSync
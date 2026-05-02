-- tidy-vault.applescript
-- Snackbar Automation Script
--
-- Created by DevStudio Integration
--

use framework "Foundation"
use scripting additions

-- Main handler
on run
    tell application "Snackbar"
        activate
        
        -- Trigger vault tidy via DevStudio
        try
            do shell script "/usr/local/bin/vibe vault-tidy"
            display notification "Vault tidied successfully!" with title "Snackbar"
        on error errMsg
            display notification "Error tidying vault: " & errMsg with title "Snackbar"
        end try
    end tell
end run

-- Handler for direct calls
on tidyVault()
    tell application "Snackbar"
        activate
        
        try
            do shell script "/usr/local/bin/vibe vault-tidy"
            return "Vault tidied successfully!"
        on error errMsg
            return "Error: " & errMsg
        end try
    end tell
end tidyVault

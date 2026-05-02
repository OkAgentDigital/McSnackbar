-- daily-vault-tidy.applescript
-- Snackbar Automation Script
--
-- Created by DevStudio Integration
--
-- This script runs the daily vault tidy routine

use framework "Foundation"
use scripting additions

-- Main handler
on run
    tell application "Snackbar"
        activate
        
        try
            -- Trigger the vault tidy skill
            set resultText to trigger devstudio skill skill name "vault-tidy" arguments "--dry-run"
            
            -- Show notification with result
            display notification "Vault tidy completed: " & resultText with title "Snackbar"
            
            return "Vault tidy completed successfully!"
            
        on error errMsg
            display notification "Error running vault tidy: " & errMsg with title "Snackbar"
            return "Error: " & errMsg
        end try
    end tell
end run

-- Handler for direct calls
on runDailyVaultTidy()
    tell application "Snackbar"
        activate
        
        try
            -- Trigger the vault tidy skill
            set resultText to trigger devstudio skill skill name "vault-tidy" arguments "--dry-run"
            
            return "Vault tidy completed: " & resultText
            
        on error errMsg
            return "Error: " & errMsg
        end try
    end tell
end runDailyVaultTidy
-- test-applescript-integration.applescript
-- Snackbar Automation Test Script
--
-- Created by DevStudio Integration
--
-- This script tests all AppleScript functionality

use framework "Foundation"
use scripting additions

-- Main test function
on run
    set testResults to {}
    set allPassed to true
    
    tell application "Snackbar"
        activate
        
        try
            -- Test 1: Create a note
            set testName to "Create Note Test"
            set noteResult to create note title "Test Note" content "This is a test note" tags {"test", "applescript"}
            
            if noteResult is not equal to missing value then
                copy testName & " - PASSED" to end of testResults
            else
                copy testName & " - FAILED" to end of testResults
                set allPassed to false
            end if
            
            -- Test 2: Get notes
            set testName to "Get Notes Test"
            set notesList to get notes
            
            if notesList is not equal to missing value and (count of notesList) > 0 then
                copy testName & " - PASSED (Found " & (count of notesList) & " notes)" to end of testResults
            else
                copy testName & " - FAILED" to end of testResults
                set allPassed to false
            end if
            
            -- Test 3: Update note (using the first note)
            if (count of notesList) > 0 then
                set testName to "Update Note Test"
                set firstNote to item 1 of notesList
                set noteId to id of firstNote
                
                set updateResult to update note id noteId new content "Updated content via AppleScript"
                
                if updateResult is not equal to missing value then
                    copy testName & " - PASSED" to end of testResults
                else
                    copy testName & " - FAILED" to end of testResults
                    set allPassed to false
                end if
            else
                copy "Update Note Test - SKIPPED (no notes)" to end of testResults
            end if
            
            -- Test 4: Sync notes
            set testName to "Sync Notes Test"
            set syncResult to sync notes
            
            if syncResult is not equal to missing value then
                copy testName & " - PASSED" to end of testResults
            else
                copy testName & " - FAILED" to end of testResults
                set allPassed to false
            end if
            
            -- Test 5: Get sync status
            set testName to "Get Sync Status Test"
            set syncStatus to get sync status
            
            if syncStatus is not equal to missing value then
                copy testName & " - PASSED" to end of testResults
            else
                copy testName & " - FAILED" to end of testResults
                set allPassed to false
            end if
            
            -- Test 6: Trigger DevStudio skill
            set testName to "Trigger DevStudio Skill Test"
            set skillResult to trigger devstudio skill skill name "vault-tidy" arguments "--dry-run"
            
            if skillResult is not equal to missing value then
                copy testName & " - PASSED" to end of testResults
            else
                copy testName & " - FAILED" to end of testResults
                set allPassed to false
            end if
            
            -- Summary
            set summaryMessage to "AppleScript Integration Tests Completed:\n\n"
            repeat with testResult in testResults
                set summaryMessage to summaryMessage & testResult & "\n"
            end repeat
            
            if allPassed then
                set summaryMessage to summaryMessage & "\n✅ All tests passed!"
                display notification "All AppleScript tests passed!" with title "Snackbar"
            else
                set summaryMessage to summaryMessage & "\n❌ Some tests failed!"
                display notification "Some AppleScript tests failed!" with title "Snackbar"
            end if
            
            -- Show results
            display dialog summaryMessage buttons {"OK"} default button 1
            
            return "Tests completed: " & (length of testResults) & " tests, " & (if allPassed then "all passed" else "some failed")
            
        on error errMsg
            display notification "Test error: " & errMsg with title "Snackbar"
            display dialog "AppleScript test error: " & errMsg buttons {"OK"} default button 1
            return "Error: " & errMsg
        end try
    end tell
end run

-- Individual test handlers for direct calling
on testCreateNote()
    tell application "Snackbar"
        activate
        try
            set noteResult to create note title "Direct Test Note" content "Created via direct AppleScript call" tags {"direct", "test"}
            return "Note created successfully"
        on error errMsg
            return "Error: " & errMsg
        end try
    end tell
end testCreateNote

on testTriggerSkill()
    tell application "Snackbar"
        activate
        try
            set skillResult to trigger devstudio skill skill name "VAULTRUN" arguments "inbox test"
            return "Skill triggered successfully: " & skillResult
        on error errMsg
            return "Error: " & errMsg
        end try
    end tell
end testTriggerSkill
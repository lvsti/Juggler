script ScriptingBridge
	
	property parent : class "NSObject"
	
    on closeAllSourcetreeWindows()
        delay 0.2
        tell application "System Events"
            keystroke "w" using {command down, option down}
        end tell
    end closeAllSourcetreeWindows

    on doCloseAllXcodeProjectsWithExcept_(projectPath)
        repeat with doc in documents of application "Xcode"
            if file of doc as text is not projectPath then
                tell doc to close
            end if
        end repeat
    end doCloseAllXcodeProjectsWithExcept_
    
end script

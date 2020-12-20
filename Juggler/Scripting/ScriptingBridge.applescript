script ScriptingBridge
	
	property parent : class "NSObject"
	
    on closeAllSourcetreeWindows()
        delay 0.2
        tell application "System Events"
            keystroke "w" using {command down, option down}
        end tell
    end closeAllSourcetreeWindows

    on doCloseAllXcodeProjectsWithExcept_xcodePath_(projectPath, xcodePath)
        set wsDocs to {}
        repeat with doc in documents of application (xcodePath as text)
            set cls to class of doc as text
            if cls is "workspace document" and file of doc as text is not projectPath then
                set wsDocs to wsDocs & {doc}
            end if
        end repeat

        repeat with doc in wsDocs
            tell doc to close
        end repeat
    end doCloseAllXcodeProjectsWithExcept_xcodePath_
    
    on doGetActiveXcodeProjectPath()
        set p to ""
        tell application "Xcode"
            set p to file of document of the front window as text
        end tell
        
        return p as text
    end doGetActiveXcodeProjectPath
    
end script

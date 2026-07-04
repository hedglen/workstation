#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce

; =============================================================================
;   main.ahk — hedglen
;   AutoHotkey v2 master script
;   Tracked in dotfiles: https://github.com/hedglen/dotfiles
;
;   Loaded on startup via registry Run key (set by install.ps1).
;   To reload: right-click the AHK tray icon → Reload Script
; =============================================================================

; =============================================================================
;   App Launchers  (Win + key)
; =============================================================================

; Win+T → Windows Terminal
#t:: Run "wt"

; Win+E → Directory Opus (winget), else File Pilot, else Explorer
#e:: {
    if FileExist(A_ProgramFiles "\GPSoftware\Directory Opus\dopus.exe")
        Run A_ProgramFiles "\GPSoftware\Directory Opus\dopus.exe"
    else if FileExist(A_ProgramFiles "\File Pilot\FilePilot.exe")
        Run A_ProgramFiles "\File Pilot\FilePilot.exe"
    else
        Run "explorer.exe"
}

; Win+B → Chrome (primary browser in winget manifest)
#b:: Run "chrome.exe"

; Win+N → Firefox Nightly (winget manifest)
#n:: Run "firefox.exe"

; Win+C → VS Code
#c:: Run "code"

; =============================================================================
;   Window Management
; =============================================================================

; Win+Alt+Left → Move window to left monitor
#!Left:: {
    WinGetPos &x, &y, &w, &h, "A"
    monitors := []
    count := MonitorGetCount()
    loop count
        monitors.Push(A_Index)
    MonitorGet(MonitorGetPrimary(), &ml, &mt, &mr, &mb)
    if (x >= ml)
        WinMove mr - w, y,,,, "A"
    else
        WinMove ml, y,,,, "A"
}

; Win+Alt+Right → Move window to right monitor
#!Right:: {
    WinGetPos &x, &y, &w, &h, "A"
    MonitorGet(MonitorGetPrimary(), &ml, &mt, &mr, &mb)
    if (x < mr - w)
        WinMove mr, y,,,, "A"
    else
        WinMove ml, y,,,, "A"
}

; Win+Alt+F → Toggle maximise
#!f:: {
    if WinGetMinMax("A") = 1
        WinRestore "A"
    else
        WinMaximize "A"
}

; =============================================================================
;   Clipboard
; =============================================================================

; Ctrl+Shift+V → Paste as plain text (strips formatting)
^+v:: {
    txt := A_Clipboard
    A_Clipboard := ""
    A_Clipboard := txt
    ClipWait 1
    Send "^v"
}

; =============================================================================
;   Text Expanders
;   Syntax: :*:trigger::replacement
; =============================================================================

:*:@@::hedglen@pm.me
:*:/shrug::¯\_(ツ)_/¯
:*:/check::✓
:*:/arr::→
:*:/date:: {
    SendInput FormatTime(, "yyyy-MM-dd")
}

; =============================================================================
;   Remaps
; =============================================================================

; CapsLock → Ctrl (tap CapsLock alone to toggle CapsLock)
*CapsLock:: {
    Send "{Blind}{Ctrl Down}"
    KeyWait "CapsLock"
    if (A_TimeSinceThisHotkey < 200)
        SetCapsLockState !GetKeyState("CapsLock", "T")
    Send "{Blind}{Ctrl Up}"
}

; =============================================================================
;   Helpers
; =============================================================================

GetHdrSwitcherPath() {
    userProfile := EnvGet("USERPROFILE")
    candidates := [
        userProfile "\workstation\tools\mpv\portable_config\hdrswitch.exe",
        userProfile "\workstation\tools\HdrSwitcher\HdrSwitcher.exe"
    ]
    for exePath in candidates {
        if FileExist(exePath)
            return exePath
    }
    return ""
}

InvokeHdrSwitcher(mode) {
    exePath := GetHdrSwitcherPath()
    if (exePath = "") {
        TrayTip "HDR switcher missing", "Install via dotfiles mpv-config installer", 2500
        return
    }
    Run A_ComSpec ' /c ""' exePath '" ' mode '"',, "Hide"
}

; Win+Alt+H → Toggle HDR on/off
#!h:: InvokeHdrSwitcher("toggle")

; =============================================================================
;   HDR Auto-Toggle for Games
;   Enables HDR when a supported game launches, disables when it exits.
; =============================================================================

global g_hdrGames := ["Diablo IV.exe", "PathOfExile2.exe", "LastEpoch.exe"]
global g_hdrEnabledByGame := false

SetTimer GameHDRWatch, 5000

GameHDRWatch() {
    global g_hdrGames, g_hdrEnabledByGame
    gameRunning := false
    for game in g_hdrGames {
        if ProcessExist(game) {
            gameRunning := true
            break
        }
    }
    if (gameRunning && !g_hdrEnabledByGame) {
        g_hdrEnabledByGame := true
        InvokeHdrSwitcher("enable")
    } else if (!gameRunning && g_hdrEnabledByGame) {
        g_hdrEnabledByGame := false
        InvokeHdrSwitcher("disable")
    }
}

; Win+Alt+R → Reload this script
#!r:: Reload

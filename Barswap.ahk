#Requires AutoHotkey v2.0
#SingleInstance Force

; 1. ENFORCE ADMINISTRATOR PRIVILEGES
if not A_IsAdmin {
    Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"')
    ExitApp()
}

; ==========================================
; CONFIGURATION
; ==========================================
config := {}
config.keyBar1 := "{NumpadDiv}"   ; Key bound to Bar 1 (/ on Numpad)
config.keyBar2 := "{NumpadMult}"  ; Key bound to Bar 2 (* on Numpad)
config.cooldownTime := 500

; HUD-Overlay Settings
config.hudX := 100                
config.hudY := 100                
config.fontSize := 90             
config.textColor := "cWhite"      
; ==========================================

; Global state tracking variables
global isLocked := false
global releasedEarly := false
global currentBar := 1             
global hudText := ""
global esoHud := ""

; 1. CREATE HUD WINDOW
esoHud := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20") 
esoHud.BackColor := "111111" 

; 2. ADD TEXT COMPONENT
esoHud.SetFont("S" config.fontSize " Bold", "Arial")
hudText := esoHud.Add("Text", config.textColor " w300 h200 X0 Y0", "1")

; 3. DISPLAY HUD WINDOW
esoHud.Show("X" config.hudX " Y" config.hudY " w300 h200 NoActivate") 

; 4. INVISIBLE WINDOW BACKGROUND EFFECT
WinSetTransColor("111111", "ahk_id " esoHud.Hwnd)

; Permanent background timers
SetTimer(CheckBarStatus, 250)
SetTimer(WatchEsoWindow, 300)

; Only execute hotkeys when Elder Scrolls Online is the active window
#HotIf WinActive("ahk_exe eso64.exe")

; [PRESS MOUSE 4] - Immediately switch to Bar 2 (*)
*XButton1::
{
    global isLocked, releasedEarly
    
    if (isLocked) {
        return
    }
    
    ; Stop any active Bar 1 recovery spam
    SetTimer(SpamBar1, 0)
    
    isLocked := true
    releasedEarly := false
    
    UpdateBarStatus(2)
    
    Send(config.keyBar2) 
    SetTimer(ReleaseCooldown, -config.cooldownTime)
}

; [RELEASE MOUSE 4] - Prepare to switch back to Bar 1 (/)
*XButton1 up::
{
    global isLocked, releasedEarly
    
    if (isLocked) {
        releasedEarly := true 
    } else {
        UpdateBarStatus(1)
        Send(config.keyBar1)
    }
}

#HotIf

; Helper function: Updates the active bar state and visual HUD display
UpdateBarStatus(targetBar)
{
    global currentBar, hudText 
    currentBar := targetBar
    if (IsObject(hudText)) {
        hudText.Value := targetBar
    }
}

; Helper function 1: Triggered when the initial cooldown timer expires
ReleaseCooldown()
{
    global isLocked, releasedEarly
    
    if (releasedEarly) {
        UpdateBarStatus(1)
        releasedEarly := false
        SetTimer(SpamBar1, 65)
    } else {
        isLocked := false
    }
}

; Helper function 2: Spams Bar 1 in rapid succession if button was released early
SpamBar1()
{
    global isLocked
    static counter := 0
    
    if not WinActive("ahk_exe eso64.exe") {
        SetTimer(SpamBar1, 0)
        counter := 0
        isLocked := false
        return
    }
    
    Send(config.keyBar1)
    counter++
    
    if (counter >= 4) {
        SetTimer(SpamBar1, 0)
        counter := 0
        isLocked := false 
    }
}

; Helper function 3: 250ms background safety check to prevent desyncs
CheckBarStatus()
{
    global currentBar, isLocked
    
    if WinActive("ahk_exe eso64.exe") and not GetKeyState("XButton1", "P") and (currentBar == 2) 
    {
        isLocked := false 
        UpdateBarStatus(1)
        Send(config.keyBar1)
    }
}

; Helper function 4: Dynamically hides HUD when alt-tabbing to desktop
WatchEsoWindow()
{
    global esoHud
    if WinActive("ahk_exe eso64.exe") {
        if (IsObject(esoHud)) {
            esoHud.Show("NoActivate") 
        }
    } else {
        if (IsObject(esoHud)) {
            esoHud.Hide()
        }
    }
}

#Requires AutoHotkey v2.0
#SingleInstance Force

; 1. ADMINISTRATORRECHTE ERZWINGEN
if not A_IsAdmin {
    Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"')
    ExitApp()
}

; ==========================================
; KONFIGURATION
; ==========================================
global config := {}
config.swapKey := "XButton1"      ; Taste zum Wechseln (Leiste wechseln)
config.keyBar1 := "{NumpadDiv}"   ; Taste für Leiste 1 (/ auf dem Ziffernblock)
config.keyBar2 := "{NumpadMult}"  ; Taste für Leiste 2 (* auf dem Ziffernblock)
config.cooldownTime := 400        

; HUD-Overlay-Einstellungen
config.hudX := 100                
config.hudY := 100                
config.fontSize := 90             
config.textColor := "cFF0000"
; ==========================================

; Globale Variablen zur Statusverfolgung
global isLocked := false
global releasedEarly := false
global currentBar := 1             
global hudText := ""
global esoHud := ""

; 1. HUD-FENSTER ERSTELLEN
esoHud := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20") 
esoHud.BackColor := "010000" 

; 2. TEXTKOMPONENTE HINZUFÜGEN
esoHud.SetFont("S" config.fontSize " Bold", "Arial")
hudText := esoHud.Add("Text", config.textColor " w300 h200 X0 Y0", "1")

; 3. HUD-FENSTER ANZEIGEN
esoHud.Show("X" config.hudX " Y" config.hudY " w300 h200 NoActivate") 

; 4. EFFEKT FÜR UNSICHTBAREN FENSTERHINTERGRUND
WinSetTransColor("010000", "ahk_id " esoHud.Hwnd)

; Permanente Hintergrund-Timer
SetTimer(CheckBarStatus, 500) ; Auf 500ms erhöht für weniger Systemlast
SetTimer(WatchEsoWindow, 300)

; Dynamische Hotkey-Registrierung
HotIf (*) => WinActive("ahk_exe eso64.exe") and IsEsoCursorHidden()
Hotkey("*" config.swapKey, OnSwapKeyDown)
Hotkey("*" config.swapKey " up", OnSwapKeyUp)
HotIf

; ==========================================
; HOTKEY-FUNKTIONEN
; ==========================================

OnSwapKeyDown(HotkeyName)
{
    global isLocked, releasedEarly, config
    
    if (isLocked) {
        return
    }
    
    SetTimer(SpamBar1, 0) ; Bestehenden Spam abbrechen
    
    isLocked := true
    releasedEarly := false
    
    UpdateBarStatus(2)
    HumanizedSend(config.keyBar2) 
    
    dynamicCooldown := Random(config.cooldownTime - 35, config.cooldownTime + 35)
    SetTimer(ReleaseCooldown, -dynamicCooldown)
}

OnSwapKeyUp(HotkeyName)
{
    global isLocked, releasedEarly, config
    
    if (isLocked) {
        releasedEarly := true 
    } else {
        UpdateBarStatus(1)
        HumanizedSend(config.keyBar1)
    }
}

; ==========================================
; HELFER-FUNKTIONEN
; ==========================================

IsEsoCursorHidden()
{
    if not WinActive("ahk_exe eso64.exe")
        return false

    ; 1. PRÜFUNG: Windows-Systemstatus des Cursors
    ci := Buffer(A_PtrSize = 8 ? 24 : 20, 0)
    NumPut("UInt", ci.Size, ci, 0)
    if DllCall("GetCursorInfo", "Ptr", ci) {
        flags := NumGet(ci, 4, "UInt")
        if (flags == 0)
            return true
    }

    ; 2. PRÜFUNG: Maus im echten Spielzentrum (Client-Koordinaten ignorieren Fensterrahmen)
    try {
        WinGetClientPos(&X, &Y, &W, &H, "ahk_exe eso64.exe")
        centerX := W / 2
        centerY := H / 2
        
        CoordMode("Mouse", "Client")
        MouseGetPos(&mouseX, &mouseY)
        
        if (Abs(mouseX - centerX) <= 10 and Abs(mouseY - centerY) <= 10) {
            return true 
        }
    }
    return false 
}

HumanizedSend(keyToSend)
{
    SetKeyDelay(Random(8, 20), Random(20, 50))
    SendEvent(keyToSend)
}

UpdateBarStatus(targetBar)
{
    global currentBar, hudText 
    currentBar := targetBar
    if (IsObject(hudText)) {
        hudText.Value := targetBar
    }
}

ReleaseCooldown()
{
    global isLocked, releasedEarly
    
    if (releasedEarly) {
        releasedEarly := false
        ; Startet den Rückwechsel-Spam, falls die Taste zu früh losgelassen wurde
        SetTimer(SpamBar1, 65) 
    } else {
        isLocked := false
    }
}

SpamBar1()
{
    global isLocked, config
    static counter := 0
    
    ; Abbruchbedingungen
    if (not WinActive("ahk_exe eso64.exe") or not IsEsoCursorHidden() or GetKeyState(config.swapKey, "P")) {
        SetTimer(SpamBar1, 0)
        counter := 0
        isLocked := false
        return
    }
    
    UpdateBarStatus(1)
    HumanizedSend(config.keyBar1)
    counter++
    
    if (counter >= 3) { ; Auf 3 Versuche reduziert (reicht völlig aus und ist sicherer)
        SetTimer(SpamBar1, 0)
        counter := 0
        isLocked := false 
    }
}

CheckBarStatus()
{
    global currentBar, isLocked, config
    
    ; Korrektur: Wenn die Taste physisch nicht gedrückt ist, wir aber im HUD noch auf Leiste 2 stehen
    if WinActive("ahk_exe eso64.exe") and IsEsoCursorHidden() and not GetKeyState(config.swapKey, "P") and (currentBar == 2) 
    {
        SetTimer(SpamBar1, 0) ; Kollisionen mit aktivem Spam verhindern
        isLocked := false 
        UpdateBarStatus(1)
        HumanizedSend(config.keyBar1)
    }
}

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

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
config := {}
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
SetTimer(CheckBarStatus, 250)
SetTimer(WatchEsoWindow, 300)

; Dynamische Hotkey-Registrierung (Gilt nur, wenn ESO aktiv ist UND der Cursor versteckt ist)
HotIf (*) => WinActive("ahk_exe eso64.exe") and IsEsoCursorHidden()
Hotkey("*" config.swapKey, OnSwapKeyDown)
Hotkey("*" config.swapKey " up", OnSwapKeyUp)
HotIf

; ==========================================
; HOTKEY-FUNKTIONEN
; ==========================================

OnSwapKeyDown(HotkeyName)
{
    global isLocked, releasedEarly
    
    if (isLocked) {
        return
    }
    
    SetTimer(SpamBar1, 0)
    
    isLocked := true
    releasedEarly := false
    
    UpdateBarStatus(2)
    HumanizedSend(config.keyBar2) 
    
    dynamicCooldown := Random(config.cooldownTime - 35, config.cooldownTime + 35)
    SetTimer(ReleaseCooldown, -dynamicCooldown)
}

OnSwapKeyUp(HotkeyName)
{
    global isLocked, releasedEarly
    
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

; Mathematische ESO-Cursorerkennung via Windows-API
IsEsoCursorHidden()
{
    if not WinActive("ahk_exe eso64.exe")
        return false

    ; 1. PRÜFUNG: Windows-Systemstatus des Cursors auslesen
    ; CURSORINFO-Struktur anfordern
    ci := Buffer(A_PtrSize = 8 ? 24 : 20, 0)
    NumPut("UInt", ci.Size, ci, 0)
    if DllCall("GetCursorInfo", "Ptr", ci) {
        flags := NumGet(ci, 4, "UInt")
        ; Wenn flags == 0 ist, ist der Cursor im Windows-System komplett unsichtbar geschaltet
        if (flags == 0)
            return true
    }

    ; 2. PRÜFUNG: Ist die Maus exakt im Zentrum des Spiels gefangen (ESO Kampf-Modus)?
    WinGetPos(&X, &Y, &W, &H, "ahk_exe eso64.exe")
    centerX := X + (W / 2)
    centerY := Y + (H / 2)
    
    ; Aktuelle physische Mausposition ermitteln
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY)
    
    ; Erlaubt eine minimale Toleranz von 5 Pixeln im Zentrum
    if (Abs(mouseX - centerX) <= 5 and Abs(mouseY - centerY) <= 5) {
        return true ; Maus ist im Zentrum fixiert -> Spieler ist im Kampf/Gameplay
    }

    return false ; Maus bewegt sich frei -> Spieler ist im Inventar, Chat oder Menü
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
        UpdateBarStatus(1)
        releasedEarly := false
        SetTimer(SpamBar1, 65)
    } else {
        isLocked := false
    }
}

SpamBar1()
{
    global isLocked
    static counter := 0
    
    ; Bricht ab, wenn der Cursor im Chat sichtbar wird
    if (not WinActive("ahk_exe eso64.exe") or not IsEsoCursorHidden()) {
        SetTimer(SpamBar1, 0)
        counter := 0
        isLocked := false
        return
    }
    
    if (GetKeyState(config.swapKey, "P")) {
        SetTimer(SpamBar1, 0)
        counter := 0
        isLocked := false
        return
    }
    
    HumanizedSend(config.keyBar1)
    counter++
    
    if (counter >= 4) {
        SetTimer(SpamBar1, 0)
        counter := 0
        isLocked := false 
    }
}

CheckBarStatus()
{
    global currentBar, isLocked
    
    ; Führt den Sicherheits-Reset nur aus, wenn wir uns im echten Gameplay befinden
    if WinActive("ahk_exe eso64.exe") and IsEsoCursorHidden() and not GetKeyState(config.swapKey, "P") and (currentBar == 2) 
    {
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

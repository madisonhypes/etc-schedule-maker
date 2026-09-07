Option Explicit
' ETC Schedule Maker (Emerald Triangle Cannabis) launcher (Windows)
' On launch: check GitHub for a newer app.html, download if found, then open.
' Offline / unreachable / bad download -> silently run the copy we already have.

Dim UPDATE_BASE
UPDATE_BASE = "https://raw.githubusercontent.com/madisonhypes/etc-schedule-maker/main"

Dim MIN_SIZE
MIN_SIZE = 40000   ' bytes; reject truncated / error-page downloads

Dim fso, shell, scriptDir, support, bundled, bundledVer, live, liveVer
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
bundled = scriptDir & "\app.html"

' working copy lives in LocalAppData so updates never touch the install folder
support = shell.ExpandEnvironmentStrings("%LocalAppData%") & "\ETCScheduleMaker"
If Not fso.FolderExists(support) Then fso.CreateFolder support
live = support & "\app.html"

' create a pinnable Desktop shortcut once (so it can be pinned to the Windows taskbar)
EnsurePinnableShortcut

' optional override file
If fso.FileExists(support & "\update-url.txt") Then
  Dim u : u = Trim(ReadTextFile(support & "\update-url.txt"))
  If Len(u) > 0 Then UPDATE_BASE = u
End If

bundledVer = Trim(ReadTextFile(scriptDir & "\version.txt"))
If Len(bundledVer) = 0 Then bundledVer = "0.0.0"
liveVer = Trim(ReadTextFile(support & "\version.txt"))
If Len(liveVer) = 0 Then liveVer = "0.0.0"

' 1. Seed / restore the working copy from the bundled one
If (Not ValidHtml(live)) Or (VerNum(bundledVer) > VerNum(liveVer)) Then
  On Error Resume Next
  fso.CopyFile bundled, live, True
  If Err.Number = 0 Then WriteTextFile support & "\version.txt", bundledVer
  On Error GoTo 0
  liveVer = bundledVer
End If

' 2. Check GitHub for something newer
If Len(UPDATE_BASE) > 0 Then
  Dim remoteVer
  remoteVer = Trim(HttpGetText(UPDATE_BASE & "/version.txt?nocache=" & CacheBust()))
  If IsVersion(remoteVer) Then
    If VerNum(remoteVer) > VerNum(liveVer) Then
      Dim tmp : tmp = support & "\app.download"
      If HttpGetFile(UPDATE_BASE & "/app.html?nocache=" & CacheBust(), tmp) Then
        If ValidHtml(tmp) Then
          On Error Resume Next
          fso.CopyFile tmp, live, True
          If Err.Number = 0 Then WriteTextFile support & "\version.txt", remoteVer
          On Error GoTo 0
        End If
      End If
      If fso.FileExists(tmp) Then fso.DeleteFile tmp, True
    End If
  End If
End If

' 3. Open whichever copy we ended up with
Dim target
target = live
If Not ValidHtml(target) Then target = bundled

Dim url
url = "file:///" & Replace(target, "\", "/")
url = Replace(url, " ", "%20")

Dim pf, pf86, lad, chrome, edge
pf   = shell.ExpandEnvironmentStrings("%ProgramFiles%")
pf86 = shell.ExpandEnvironmentStrings("%ProgramFiles(x86)%")
lad  = shell.ExpandEnvironmentStrings("%LocalAppData%")

chrome = FirstExisting(Array( _
  pf & "\Google\Chrome\Application\chrome.exe", _
  pf86 & "\Google\Chrome\Application\chrome.exe", _
  lad & "\Google\Chrome\Application\chrome.exe"))
edge = FirstExisting(Array( _
  pf86 & "\Microsoft\Edge\Application\msedge.exe", _
  pf & "\Microsoft\Edge\Application\msedge.exe"))

' The Print button opens the normal print dialog.
Dim flags
flags = " --app=""" & url & """ --window-size=1440,920"

If chrome <> "" Then
  shell.Run """" & chrome & """" & flags, 1, False
ElseIf edge <> "" Then
  shell.Run """" & edge & """" & flags, 1, False
Else
  shell.Run """" & target & """", 1, False
End If

' ───────────────────────── helpers ─────────────────────────

Function CacheBust()
  CacheBust = CStr(DateDiff("s", "01/01/2020 00:00:00", Now))
End Function

Function ReadTextFile(path)
  ReadTextFile = ""
  On Error Resume Next
  If fso.FileExists(path) Then
    Dim f : Set f = fso.OpenTextFile(path, 1)
    If Err.Number = 0 Then
      If Not f.AtEndOfStream Then ReadTextFile = f.ReadAll
      f.Close
    End If
  End If
  On Error GoTo 0
End Function

Sub WriteTextFile(path, txt)
  On Error Resume Next
  Dim f : Set f = fso.CreateTextFile(path, True)
  If Err.Number = 0 Then
    f.Write txt
    f.Close
  End If
  On Error GoTo 0
End Sub

Function IsVersion(v)
  IsVersion = False
  If Len(v) = 0 Then Exit Function
  Dim p : p = Split(v, ".")
  If UBound(p) < 2 Then Exit Function
  If IsNumeric(p(0)) And IsNumeric(p(1)) And IsNumeric(p(2)) Then IsVersion = True
End Function

Function VerNum(v)
  VerNum = 0
  On Error Resume Next
  Dim p : p = Split(v & ".0.0", ".")
  VerNum = CLng(p(0)) * 1000000 + CLng(p(1)) * 1000 + CLng(p(2))
  If Err.Number <> 0 Then VerNum = 0
  On Error GoTo 0
End Function

Function ValidHtml(path)
  ValidHtml = False
  On Error Resume Next
  If Not fso.FileExists(path) Then Exit Function
  Dim f : Set f = fso.GetFile(path)
  If f.Size < MIN_SIZE Then Exit Function
  Dim txt : txt = ReadTextFile(path)
  If InStr(txt, "</html>") > 0 Then ValidHtml = True
  On Error GoTo 0
End Function

Function HttpGetText(url)
  HttpGetText = ""
  On Error Resume Next
  Dim x : Set x = CreateObject("MSXML2.ServerXMLHTTP.6.0")
  If Err.Number <> 0 Then Exit Function
  x.setTimeouts 5000, 5000, 10000, 15000
  x.open "GET", url, False
  x.setRequestHeader "Cache-Control", "no-cache"
  x.send
  If Err.Number = 0 Then
    If x.status = 200 Then HttpGetText = x.responseText
  End If
  On Error GoTo 0
End Function

Function HttpGetFile(url, destPath)
  HttpGetFile = False
  On Error Resume Next
  Dim x : Set x = CreateObject("MSXML2.ServerXMLHTTP.6.0")
  If Err.Number <> 0 Then Exit Function
  x.setTimeouts 5000, 5000, 15000, 90000
  x.open "GET", url, False
  x.setRequestHeader "Cache-Control", "no-cache"
  x.send
  If Err.Number <> 0 Then Exit Function
  If x.status <> 200 Then Exit Function

  Dim s : Set s = CreateObject("ADODB.Stream")
  If Err.Number <> 0 Then Exit Function
  s.Type = 1            ' binary — preserves exact bytes / UTF-8
  s.Open
  s.Write x.responseBody
  s.SaveToFile destPath, 2
  s.Close
  If Err.Number = 0 Then HttpGetFile = True
  On Error GoTo 0
End Function

Function FirstExisting(paths)
  Dim p
  FirstExisting = ""
  For Each p In paths
    If fso.FileExists(p) Then
      FirstExisting = p
      Exit Function
    End If
  Next
End Function

' Create a Desktop shortcut that Windows will let you PIN to the taskbar.
' Trick: the target is wscript.exe running this launcher (a .vbs itself can't be pinned).
' Runs once per computer (a marker prevents it coming back after the user deletes it).
Sub EnsurePinnableShortcut()
  On Error Resume Next
  Dim marker : marker = support & "\shortcut.created"

  Dim desktop : desktop = shell.SpecialFolders("Desktop")
  If Len(desktop) = 0 Then Exit Sub

  Dim lnkPath : lnkPath = desktop & "\ETC Schedule Maker.lnk"
  Dim iconPath : iconPath = scriptDir & "\icon.ico"

  ' Already made once and since removed by the user -> leave it alone.
  ' Still on the Desktop -> rebuild it so a new icon.ico or a moved folder is picked up.
  If fso.FileExists(marker) Then
    If Not fso.FileExists(lnkPath) Then Exit Sub
    fso.DeleteFile lnkPath, True
  End If

  Dim lnk : Set lnk = shell.CreateShortcut(lnkPath)
  If Err.Number <> 0 Then Exit Sub
  lnk.TargetPath = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\wscript.exe"
  lnk.Arguments = """" & WScript.ScriptFullName & """"
  lnk.WorkingDirectory = scriptDir
  If fso.FileExists(iconPath) Then lnk.IconLocation = iconPath & ",0"
  lnk.Description = "ETC Schedule Maker - Emerald Triangle Cannabis"
  lnk.Save

  ' remember we've done it, so a launch after the user deletes/pins it won't recreate it
  If Err.Number = 0 Then WriteTextFile marker, "1"
  On Error GoTo 0
End Sub

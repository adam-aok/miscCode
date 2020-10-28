VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Sheet1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = True
Private Sub CommandButton1_Click()
Dim StartTime As Double, SecondsElapsed As Double

'Remember time when macro starts
StartTime = Timer

'run main function
refreshReportMain

'Determine how many seconds code took to run
SecondsElapsed = Round(Timer - StartTime, 2)

If Err.Number > 0 Then
MsgBox "Unable to process report. Please check name/location of Access file and rerun. Error No. " & vbCritical
Else

'Display if report was a success, and display amount of time it took to run
MsgBox "Report was a success. It ran in " & SecondsElapsed & " seconds from Source File: " & Application.ActiveWorkbook.Path & "\" & Cells(3, 4) & fNamevbInformation
End If

End Sub

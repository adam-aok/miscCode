Attribute VB_Name = "Module1"
Sub CopyAndPaste()
Dim ar As Range, cel As Range, rg As Range
Set rg = Selection
On Error Resume Next
Set cel = Application.InputBox("Please select first cell in destination range", "Select first cell in destination", Type:=8)
On Error GoTo 0
 
If Not cel Is Nothing Then
    For Each ar In rg.Areas
        ar.Copy cel
        Set cel = cel.Offset(ar.Rows.Count, 0)
    Next
End If
End Sub

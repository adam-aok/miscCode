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
Function GetMatch(rng1 As Range, searchVal As String) As String
Dim MyRange As Range
Dim Cell As Object
'Dim Result As String
'Dim i As Integer
'Dim colSplit() As String

For Each Cell In rng1
    If InStr(1, Cell.Value, searchVal) <> 0 Then
        GetMatch = Trim(Cell.Value)
    End If
Next

End Function

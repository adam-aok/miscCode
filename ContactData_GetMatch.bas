 'function which searches for strings in a range, i.e. phone number or address data in a field
 'premise is to identify which key features are unique to each data type
 
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

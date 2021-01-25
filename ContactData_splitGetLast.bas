'generic function to get the last value in a sentence. i.e. splitGetLast("this;is;a;setence",";") outputs "sentence"
Function splitGetLast(text As String, splitVal As String) As String
Dim textArr() As String

If text <> "" Then
textArr = Split(Trim(text), splitVal)
splitGetLast = textArr(UBound(textArr))
End If

End Function

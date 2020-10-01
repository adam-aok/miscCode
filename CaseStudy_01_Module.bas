Attribute VB_Name = "Module1"
Sub refreshReportMain()
'Case Study for XXXX role, by Adam Keefe. X-XX-2020
'If this code is being imported into another workbook, make sure to reference Microsoft ActiveX Data Objects v6.1 or any other applicable for ADO connection --AOK
Dim sourceFile As String

'set sourceFile name to be different if it happens to be different
'by default, the code will look in the same directory first. MS Acccess need not be open. user may change if needed here.
sourceFile = "SampleDatabase.mdb"

With Worksheets("SampleReport")
'fill out Report Run On date on sheet
.Range("D3") = Hy
.Range("D4") = Date
.Range("D4").NumberFormat = "dd-mmm-yyyy"

'fill out Source File cell with a hyperlink to the file itself
.Hyperlinks.Add Anchor:=Range("D3"), Address:=Application.ActiveWorkbook.Path & "\" & sourceFile, TextToDisplay:=sourceFile
.Range("D3").Font.Size = 8
.Range("D3").Font.Name = "Tahoma"

'fill out three lists throughout the sheet. pass along sourceFile name
FindAndFillQuarters (sourceFile)
SummarizeSectors (sourceFile)
SalesTargetList (sourceFile)
End With

End Sub
Sub FindAndFillQuarters(fName As String)

'I intentionally separated out the quarters portion for the purpose of flexibility. Rather than superimposing all fields at once, this sub takes a look at each one of the rows under "Quarter"
'and matches the

Dim rngFound As Range
Dim r As Range

With Worksheets("SampleReport").Cells
'Find the quarter title row to work downwards
    Set rngFound = .Find("Quarter", LookIn:=xlValues)
    If Not rngFound Is Nothing Then
        'MsgBox rngFound.Address
        'something is found
    Else
        'nothing found
    End If
    
    'takes each cell next to a Q* 20** and performs the data pull, outputs to the cell
    For Each r In .Range(rngFound.Offset(1, 0), rngFound.End(xlDown))
        r.Offset(0, 1).value = GetQuarterSums(fName, r.value)
    Next r
    
End With

End Sub
Private Function GetQuarterSums(fName As String, qName As String) As Currency


Dim accessConn As ADODB.Connection
Dim accessRecSet As ADODB.Recordset
Dim aConnString As String, sqlQuery As String

Dim fromTable As String, dbFullPath As String
Dim quarterParse As Integer, yearParse As Integer

'parse the qName into quarter, year integers to act as a condition in the SQL query
quarterParse = Left(Split(qName, "Q")(1), 1)
yearParse = Right(qName, 4)

fromTable = "Loans"

dbFullPath = Application.ActiveWorkbook.Path & "\" & fName

'Create the SQL satement to retrieve the data from the table
'Get the necessary information (original loan amount, etc.) for all customers within a quarter
sqlQuery = "SELECT SUM(OriginalLoanAmount) FROM " & fromTable & " WHERE DATEPART('q',LoanOriginationDate) = " & quarterParse & " AND DATEPART('yyyy',LoanOriginationDate) = " & yearParse & ";"

'ADODB Connection String to initiate connection with MDB ACCESS
aConnString = "Provider=Microsoft.ace.OLEDB.12.0;Data Source=" & dbFullPath & ";"

'Open connection with aConnString
Set accessConn = New ADODB.Connection
accessConn.Open ConnectionString:=aConnString

'Execute SQL Query & get records matching the query to recordset
Set accessRecSet = New ADODB.Recordset
accessRecSet.Open Source:=sqlQuery, ActiveConnection:=accessConn


'If Query Returned Values, pass the value into getquartersums
If accessRecSet.RecordCount <> 0 Then
    GetQuarterSums = nullZero(accessRecSet.Fields(0).value)
End If

'Close Connection & RecordSet
Set accessRecSet = Nothing
accessConn.Close
Set accessConn = Nothing
End Function
Sub SummarizeSectors(fName As String)

'since this list should not need to read any values from the sheet, I opted for a single sub to simply return the query as it will already be organized correctly.
'important to note that although the query properly calculates for Weighted Average Interest Rate, the sheet only appears to have 0.00% across all rows
'if there is some consideration I may have missed which is leading to a WAIR miscalculation, please let me know
Dim accessConn As ADODB.Connection
Dim accessRecSet As ADODB.Recordset
Dim aConnString As String, sqlQuery As String
Dim dbFullPath As String

dbFullPath = Application.ActiveWorkbook.Path & "\" & fName

'Sector summaries sorted by origination volume
'Get the necessary information (original loan amount, average interest rate, ordered by volume. requires ANSI JOIN of the two tables, since the SchoolID values are too long to act as a key for an INNER JOIN
sqlQuery = "SELECT B.Sector, SUM(A.OriginalLoanAmount), SUM(A.OriginalLoanAmount*A.InterestRate)/SUM(A.OriginalLoanAmount)FROM Loans AS A, Schools AS B WHERE A.SchoolID = B.SchoolID GROUP BY B.Sector ORDER BY SUM(A.OriginalLoanAmount) DESC"

'ADODB Connection String to initiate connection with MDB ACCESS
aConnString = "Provider=Microsoft.ace.OLEDB.12.0;Data Source=" & dbFullPath & ";"

'Open Connection
Set accessConn = New ADODB.Connection
accessConn.Open ConnectionString:=aConnString

'Execute SQL Query & Get Records matching the query to recordset
Set accessRecSet = New ADODB.Recordset
accessRecSet.Open Source:=sqlQuery, ActiveConnection:=accessConn

'simple CopyFromRecordset transposing of data onto the list, since all values fit already
Worksheets("SampleReport").Range("D31").CopyFromRecordset accessRecSet

'Close Connection & RecordSet
Set accessRecSet = Nothing
accessConn.Close
Set accessConn = Nothing
End Sub

Sub SalesTargetList(fName As String)

Dim accessConn As ADODB.Connection
Dim accessRecSet As ADODB.Recordset
Dim aConnString As String, sqlQuery As String
Dim dbFullPath As String
Dim r As Integer

dbFullPath = Application.ActiveWorkbook.Path & "\" & fName

'Get the necessary information (original loan amount, etc.) for all customers within a quarter
sqlQuery = "SELECT A.SchoolID, SUM(A.OriginalLoanAmount), B.LastSalesCycle FROM Loans AS A, Schools AS B WHERE (A.SchoolID = B.SchoolID) AND (B.PaymentPlanEnabled = FALSE) AND (B.LastSalesCycle < DATEADD('yyyy',-1,Date())) AND (A.LoanOriginationDate BETWEEN DateAdd('yyyy', -1, Date()) AND Date()) GROUP BY A.SchoolID, B.LastSalesCycle ORDER BY SUM(A.OriginalLoanAmount) DESC"

'ADODB Connection String to initiate connection with MDB ACCESS
aConnString = "Provider=Microsoft.ace.OLEDB.12.0;Data Source=" & dbFullPath & ";"

'Open Connection
Set accessConn = New ADODB.Connection
accessConn.Open ConnectionString:=aConnString

'Execute SQL Query & Get Records matching the query to recordset
Set accessRecSet = New ADODB.Recordset
accessRecSet.Open Source:=sqlQuery, ActiveConnection:=accessConn

With Worksheets("SampleReport")

'simple CopyFromRecordset transposing of data onto the list, since all values except for Rank fit already
.Range("D44").CopyFromRecordset accessRecSet

'ROW_NUMBER() in the query if possible would be preferred here, but for the sake of convenience I have simply numbered the adjacent column
For r = 1 To .Range("C44", .Range("D44").End(xlDown)).Rows.Count
    .Range("C43").Offset(r, 0) = r
Next r

'If the list has increased beyond those given, code ensures that the formats are all correct for the new list fields
.Range("C44", Range("F44").End(xlDown)).Interior.Color = RGB(255, 255, 204)
.Range("C44", Range("F44").End(xlDown)).Font.Color = RGB(31, 78, 120)
.Range("E44", Range("E44").End(xlDown)).NumberFormat = "_($#,##0_);"
.Range("F44", Range("F44").End(xlDown)).NumberFormat = "d-mmm-yyyy"
End With


'Close Connection & RecordSet
Set accessRecSet = Nothing
accessConn.Close
Set accessConn = Nothing
End Sub

Public Function nullZero(ByVal value As Variant, Optional ByVal value_when_null As Variant = 0) As Variant
'error check to bypass any of the Null retrieve errors potentially being received. ideally this should not be getting used.
    Dim return_value As Variant
    On Error Resume Next 'supress error handling

    If IsEmpty(value) Or IsNull(value) Or (VarType(value) = vbString And value = vbNullString) Then
        return_value = value_when_null
    Else
        return_value = value
    End If

    Err.Clear 'clear any errors that might have occurred
    On Error GoTo 0 'reinstate error handling

    nullZero = return_value

End Function


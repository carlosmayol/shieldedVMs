' --------------------------------------------------------------------------------
' Usage
' --------------------------------------------------------------------------------
Sub ShowUsage
   Wscript.Echo "USAGE: GetBitLockerKeyPackageADDS [Path To Save Key Package] [Optional Computer Name]"
   Wscript.Echo "If no computer name is specified, the local computer is assumed."
   Wscript.Echo
   Wscript.Echo "Example: GetBitLockerKeyPackageADDS E:\bitlocker-ad-key-package mycomputer"
   WScript.Quit
End Sub
' --------------------------------------------------------------------------------
' Parse Arguments
' --------------------------------------------------------------------------------
Set args = WScript.Arguments
Select Case args.Count
  Case 1
    If args(0) = "/?" Or args(0) = "-?" Then
    ShowUsage
    Else
      strFilePath = args(0)
      ' Get the name of the local computer
      Set objNetwork = CreateObject("WScript.Network")
      strComputerName = objNetwork.ComputerName
    End If

  Case 2
    If args(0) = "/?" Or args(0) = "-?" Then
      ShowUsage
    Else
      strFilePath = args(0)
      strComputerName = args(1)
    End If
  Case Else
    ShowUsage
End Select
' --------------------------------------------------------------------------------
' Get path to Active Directory computer object associated with the computer name
' --------------------------------------------------------------------------------
Function GetStrPathToComputer(strComputerName)
    ' Uses the global catalog to find the computer in the forest
    ' Search also includes deleted computers in the tombstone
    Set objRootLDAP = GetObject("LDAP://rootDSE")
    namingContext = objRootLDAP.Get("defaultNamingContext") ' e.g. string dc=fabrikam,dc=com
    strBase = "<GC://" & namingContext & ">"

    Set objConnection = CreateObject("ADODB.Connection")
    Set objCommand = CreateObject("ADODB.Command")
    objConnection.Provider = "ADsDSOOBject"
    objConnection.Open "Active Directory Provider"
    Set objCommand.ActiveConnection = objConnection
    strFilter = "(&(objectCategory=Computer)(cn=" &  strComputerName & "))"
    strQuery = strBase & ";" & strFilter  & ";distinguishedName;subtree"
    objCommand.CommandText = strQuery
    objCommand.Properties("Page Size") = 100
    objCommand.Properties("Timeout") = 100
    objCommand.Properties("Cache Results") = False
    ' Enumerate all objects found.
    Set objRecordSet = objCommand.Execute
    If objRecordSet.EOF Then
      WScript.echo "The computer name '" &  strComputerName & "' cannot be found."
      WScript.Quit 1
    End If
    ' Found object matching name
    Do Until objRecordSet.EOF
      dnFound = objRecordSet.Fields("distinguishedName")
      GetStrPathToComputer = "LDAP://" & dnFound
      objRecordSet.MoveNext
    Loop
    ' Clean up.
    Set objConnection = Nothing
    Set objCommand = Nothing
    Set objRecordSet = Nothing
End Function
' --------------------------------------------------------------------------------
' Securely access the Active Directory computer object using Kerberos
' --------------------------------------------------------------------------------
Set objDSO = GetObject("LDAP:")
strPathToComputer = GetStrPathToComputer(strComputerName)
WScript.Echo "Accessing object: " + strPathToComputer
Const ADS_SECURE_AUTHENTICATION = 1
Const ADS_USE_SEALING = 64 '0x40
Const ADS_USE_SIGNING = 128 '0x80
' --------------------------------------------------------------------------------
' Get all BitLocker recovery information from the Active Directory computer object
' --------------------------------------------------------------------------------
' Get all the recovery information child objects of the computer object
Set objFveInfos = objDSO.OpenDSObject(strPathToComputer, vbNullString, vbNullString, _
                                   ADS_SECURE_AUTHENTICATION + ADS_USE_SEALING + ADS_USE_SIGNING)
objFveInfos.Filter = Array("msFVE-RecoveryInformation")
' Iterate through each recovery information object and saves any existing key packages
nCount = 1
strFilePathCurrent = strFilePath & nCount
For Each objFveInfo in objFveInfos
   strName = objFveInfo.Get("name")
   strRecoveryPassword = objFveInfo.Get("msFVE-RecoveryPassword")
   strKeyPackage = objFveInfo.Get("msFVE-KeyPackage")
   WScript.echo
   WScript.echo "Recovery Object Name: " + strName
   WScript.echo "Recovery Password: " + strRecoveryPassword
   ' Validate file path
   Set fso = CreateObject("Scripting.FileSystemObject")
   If (fso.FileExists(strFilePathCurrent)) Then
 WScript.Echo "The file " & strFilePathCurrent & " already exists. Please use a different path."
WScript.Quit -1
   End If
   ' Save binary data to the file
   SaveBinaryDataText strFilePathCurrent, strKeyPackage

   WScript.echo "Related key package successfully saved to " + strFilePathCurrent
   ' Update next file path using base name
   nCount = nCount + 1
   strFilePathCurrent = strFilePath & nCount
Next
'----------------------------------------------------------------------------------------
' Utility functions to save binary data
'----------------------------------------------------------------------------------------
Function SaveBinaryDataText(FileName, ByteArray)
  'Create FileSystemObject object
  Dim FS: Set FS = CreateObject("Scripting.FileSystemObject")

  'Create text stream object
  Dim TextStream
  Set TextStream = FS.CreateTextFile(FileName)

  'Convert binary data To text And write them To the file
  TextStream.Write BinaryToString(ByteArray)
End Function
Function BinaryToString(Binary)
  Dim I, S
  For I = 1 To LenB(Binary)
    S = S & Chr(AscB(MidB(Binary, I, 1)))
  Next
  BinaryToString = S
End Function
WScript.Quit
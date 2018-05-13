object Form2: TForm2
  Left = 0
  Top = 0
  Caption = 'Form2'
  ClientHeight = 299
  ClientWidth = 635
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object IdHTTPServer1: TIdHTTPServer
    Bindings = <>
    OnConnect = IdHTTPServer1Connect
    OnDisconnect = IdHTTPServer1Disconnect
    OnCommandGet = IdHTTPServer1CommandGet
    Left = 80
    Top = 48
  end
  object ADOConnection: TADOConnection
    ConnectionString = 
      'Provider=SQLOLEDB.1;Integrated Security=SSPI;Persist Security In' +
      'fo=False;Initial Catalog=SDFJakob;Data Source=.\SDF'
    LoginPrompt = False
    Provider = 'SQLOLEDB.1'
    Left = 265
    Top = 40
  end
  object DataSetHelp: TADODataSet
    Connection = ADOConnection
    Parameters = <>
    Left = 312
    Top = 152
  end
end

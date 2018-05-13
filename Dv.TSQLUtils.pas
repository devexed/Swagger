unit Dv.TSQLUtils;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Classes, Variants;

// Conversions
function GUIDToTSQL(AValue: TGUID): String; overload;
function GUIDToTSQL(AValue: String): String; overload;
function DateToTSQL(AValue: TDateTime): String;
function DateTimeToTSQL(AValue: TDateTime): String;
/// <summary>
/// <para>Ge ett datum för första tidpunkten på input-datumets dag.
/// Kan användas för intervall-frågor utan att behöva CASTa kolumner och därmed
/// potentiellt göra dess index oanvändbara.</para>
/// <para>2008-01-04 12:40:01.546 ==> 2008-01-04 00:00:00.000</para>
/// </summary>
function StartDateToTSQL(AValue: TDateTime): string;
/// <summary>
/// <para>Ge ett datum för sista tidpunkten på input-datumets dag.
/// Kan användas för intervall-frågor utan att behöva CASTa kolumner och därmed
/// potentiellt göra dess index oanvändbara.</para>
/// <para>2008-01-04 12:40:01.546 ==> 2008-01-04 24:59:59.997</para>
/// </summary>
function EndDateToTSQL(AValue: TDateTime): string;
function DoubleToTSQL(AValue: Double): String;
function IntToTSQL(AValue: Integer): String;
function BoolToTSQL(AValue: Boolean): String;
function StrToTSQL(AValue: String): String;
function GUIDArrayToTSQL(AValue: TArray<TGUID>): string; overload;
function GUIDArrayToTSQL(AValue: array of string): string; overload;
function FieldToTSQL(AValue: string): string;
function VarToTSQL(AValue: Variant): string;

// Queries
function GetStatusListSQL(const AStatuses: Array of Integer): String;
function GetDateTimeAsDateSQL(ADateSQL: string): string;
function GetDateTimeSQL(ADateSQL, ATimeSQL: String): String;
function GetWithinIntervalSQL(const AStartSQL, AFinishSQL: String; AIntervalStart, AIntervalFinish: TDateTime): String;

/// <summary>
/// Dela upp en textkolumn i tre kommaseparerade värden som kan användas till
/// sortering eller dylikt. Första delen är all text innan första siffran i
/// texten. Om ingen siffra finns är första delen hela texten. Andra delen
/// är första heltalet tolkat i sql som en integer. Integern är 0 om inget
/// heltal fanns, annars max 999999999. Tredje delen är all text efter heltalet,
/// eller tomt om tal saknas.
///
/// Om kolumnen A innehåller 'abc123def' kommer funktionen ge kolumnerna 'abc',
/// '123', 'def'.
/// </summary>
function TSqlSplitAtFirstInteger(AColumn: string): string;

const
  GUID_NULL: TGUID = '{00000000-0000-0000-0000-000000000000}'; // Same as in System.Types
  TSQLDateFormat = 'yyyy"-"mm"-"dd"T00:00:00.000"';
  TSQLDateTimeFormat = 'yyyy"-"mm"-"dd"T"hh":"nn":"ss"."zzz';

implementation

function GUIDToTSQL(AValue: TGUID): String;
begin
  Result := QuotedStr(GuidToString(AValue));
end;

function GUIDToTSQL(AValue: String): String;
begin
  if (AValue = '') then
    AValue := GUIDToString(GUID_NULL);
  Result := QuotedStr(AValue);
end;

function DateToTSQL(AValue: TDateTime): String;
begin
  Result := QuotedStr(FormatDateTime(TSQLDateFormat, AValue));
end;

function DateTimeToTSQL(AValue: TDateTime): String;
begin
  Result := QuotedStr(FormatDateTime(TSQLDateTimeFormat, AValue));
end;

function StartDateToTSQL(AValue: TDateTime): string;
begin
  Result := DateToTSQL(AValue);
end;

function EndDateToTSQL(AValue: TDateTime): string;
begin
  // Sista tidpunkten på datumets dag. -3 millisekunder eftersom DATETIME har
  // maxprecision på 3 millisekunder.
  Result := 'DATEADD(ms, -3, DATEADD(dd, 1, ' + QuotedStr(FormatDateTime(TSQLDateFormat, AValue)) + '))';
end;

function DoubleToTSQL(AValue: Double): String;
begin
  Result := 'CAST(' + QuotedStr(StringReplace(FormatFloat('0.0000000E+00', AValue), ',', '.', [rfReplaceAll])) + ' AS FLOAT)';
end;

function IntToTSQL(AValue: Integer): String;
begin
  Result := IntToStr(AValue);
end;

function BoolToTSQL(AValue: Boolean): String;
begin
  if (AValue) then
    Result := '1'
  else
    Result := '0';
end;

function StrToTSQL(AValue: String): String;
begin
  Result := QuotedStr(AValue);
end;

function GUIDArrayToTSQL(AValue: TArray<TGUID>): string; overload;
var
  I: Integer;
begin
  if Length(AValue) = 0 then
    raise Exception.Create('GUIDArrayToTSQL: Array is empty.');
  Result := '(';
  Result := Result + GUIDToTSQL(AValue[Low(AValue)]);
  for I := Low(AValue) + 1 to High(AValue) do
    Result := Result + ',' + GUIDToTSQL(AValue[I]);
  Result := Result + ')';
end;

function GUIDArrayToTSQL(AValue: array of string): string; overload;
var
  AGuidArray: TArray<TGUID>;
  I: Integer;
begin
  SetLength(AGuidArray, Length(AValue));
  for I := Low(AValue) to High(AValue) do
    AGuidArray[I] := StringToGUID(AValue[I]);
  Result := GUIDArrayToTSQL(AGuidArray);
end;

function FieldToTSQL(AValue: string): string;
begin
  Result := '[' + StringReplace(AValue, ']', ']]', [rfReplaceAll]) + ']';
end;

function VarToTSQL(AValue: Variant): string;
begin
  if VarIsNull(AValue) then
    Result := 'NULL'
  else if VarIsStr(AValue) then
    Result := StrToTSQL(AValue)
  else if VarType(AValue) = varBoolean then
    Result := BoolToTSQL(AValue)
  else if VarType(AValue) = varDate then
    Result := DateTimeToTSQL(AValue)
  else if VarIsOrdinal(AValue) then
    Result := IntToTSQL(AValue)
  else if VarIsFloat(AValue) then
    Result := DoubleToTSQL(AValue)
  else
    raise Exception.Create('VarToTSQL: Ohanterad typ av Variant.');
end;

// Queries

function GetStatusListSQL(const AStatuses: Array of Integer): String;
var
  I: Integer;
begin
  Result := '(' + IntToStr(AStatuses[Low(AStatuses)]);
  for I := Low(AStatuses) + 1 to High(AStatuses) do
    Result := Result + ',' + IntToStr(AStatuses[I]);
  Result := Result + ')';
end;

function GetDateTimeAsDateSQL(ADateSQL: string): string;
begin
  Result := 'DATEADD(day, 0, DATEDIFF(day, 0, ' + ADateSQL + '))';
end;

function GetDateTimeSQL(ADateSQL, ATimeSQL: String): String;
begin
  Result :=
    '(DATEADD(day, 0, DATEDIFF(day, 0, ' + ADateSQL + ')) +' +
    ' DATEADD(day, 0 - DATEDIFF(day, 0, ' + ATimeSQL + '), ' + ATimeSQL + '))';
end;

function GetWithinIntervalSQL(const AStartSQL, AFinishSQL: String; AIntervalStart, AIntervalFinish: TDateTime): String;
var
  AIntervalStartSQL,
  AIntervalFinishSQL: String;
begin
  AIntervalStartSQL  := DateTimeToTSQL(AIntervalStart);
  AIntervalFinishSQL := DateTimeToTSQL(AIntervalFinish);
  Result := ' ((' + AStartSQL + ' >= ' + AIntervalStartSQL + ' AND ' + AStartSQL + ' <= ' + AIntervalFinishSQL + ')' +
    ' OR (' + AFinishSQL + ' >= ' + AIntervalStartSQL + ' AND ' + AFinishSQL + ' <= ' + AIntervalFinishSQL + ')' +
    ' OR (' + AStartSQL + ' < ' + AIntervalStartSQL + ' AND ' + AFinishSQL + ' > ' + AIntervalFinishSQL + '))';
end;

function TSqlSplitAtFirstInteger(AColumn: string): string;
var
  FromIntegerPart, FirstStringPart, IntegerPartStr, IntegerPart, SecondStringPart: string;
  ///  <summary>Hitta offsetet i ASource där pattern matchar, eller ge NULL</summary>
  function PatIndex(APattern, ASource: string): string;
  begin
    Result := 'NULLIF(PATINDEX(' + APattern + ', ' + ASource + '), 0)';
  end;
  ///  <summary>Ta en substring till där pattern matchar eller ge tom sträng</summary>
  function SubstringFromPatIndex(APattern, ASource: string): string;
  begin
    Result := 'ISNULL(SUBSTRING(' + ASource + ', ' + PatIndex(APattern, ASource) + ', LEN(' + ASource + ')), '''')';
  end;
  ///  <summary>Ta en substring till där pattern matchar eller ge resten av strängen</summary>
  function SubstringToPatIndex(APattern, ASource: string): string;
  begin
    Result := 'ISNULL(SUBSTRING(' + ASource + ', 1, ' + PatIndex(APattern, ASource) + ' - 1), ' + ASource + ')';
  end;
begin
  FirstStringPart := SubstringToPatIndex('''%[0-9]%''', AColumn);
  FromIntegerPart := SubstringFromPatIndex('''%[0-9]%''', AColumn);
  IntegerPartStr  := SubstringToPatIndex('''%[^0-9]%''', FromIntegerPart);
  IntegerPart :=
    '(CASE ' +
    ' WHEN LEN(' + IntegerPartStr + ') = 0 THEN 0 ' +
    ' WHEN LEN(' + IntegerPartStr + ') > 9 THEN 999999999 ' + // Maxsiffra på INTEGER är 9 siffror (999999999)
    ' ELSE CAST(' + IntegerPartStr + ' AS INTEGER) ' +
    'END)';
  SecondStringPart := SubstringFromPatIndex('''%[^0-9]%''', FromIntegerPart);
  Result := FirstStringPart + ', ' + IntegerPart + ', ' + SecondStringPart;
end;

end.

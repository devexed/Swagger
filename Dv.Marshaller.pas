unit Dv.Marshaller;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Variants,
  System.SyncObjs,
  System.RTTI,
  System.TypInfo,
  Data.DB,
  System.JSON {för TSDFJsonMarshaller},
  REST.JsonReflect,
  Dv.Rtti.Attributes,
  Dv.Types;

type

  TTypeFormat = string;

  TFieldInfo = class
    TypeName: string;
    TypeInfo: PTypeInfo;
    Format: TTypeFormat;
    Key: Boolean;
    MaxLength: Integer;
    MinLength: Integer;
    Nullable: Boolean;
    ReadOnly: Boolean;
  end;

///  <summary>
///  Viktiga lärdomar som gjorts.
///  Antingen marshallar record eller class
///  class är mer standard, mer som C#.
///  Viktigt då att använda TRttiInstanceType iställer för TRttiType användande av RTTI
///  <T: class> är ett bra sätt att begränsa generic till class.
///  </summary>

type

  TCustomDvMarshaller = class
  protected
    FFieldInfoDict: TDictionary<PTypeInfo, TList<TFieldInfo>>;
    FAllowModifyReadOnlyField: Boolean;

    procedure InitFieldInfo(ATypeInfo: PTypeInfo; AFieldInfoList: TList<TFieldInfo>);
    function GetPropGetterField(AProp: TRttiProperty): TRttiField;

    class function GetNameFromTypeInfo(ATypeInfo: PTypeInfo): string;

    function GetDataTypeFromTypeKind(ATypeKind: TTypeKind): TFieldType;

    function GetFieldInfoFromTypeInfo(ATypeInfo: PTypeInfo): TList<TFieldInfo>;
  public
    constructor Create; reintroduce; virtual;
    destructor Destroy; override;

    class function GetName<T: class>: string;
    function GetKeyFields<T>: TArray<TFieldInfo>;
    function GetFieldInfoFromType<T>: TList<TFieldInfo>;
    function CreateInstance<T: class>: T;
  end;

  TDvDataSetMarshaller = class(TCustomDvMarshaller)
  public
    constructor Create; override;

    function TypeInfoToDataType(ATypeInfo: PTypeInfo): TFieldType;
    procedure AssignFieldDef(AFieldDef: TFieldDef; AFieldInfo: TFieldInfo);

    function GetValueAsVariant(AType: TRttiType; AValue: TValue): Variant;
    function GetFieldAsValue(AType: TRttiType; AField: TField): TValue;

    procedure AssignFieldsFromType<T: class>(ADataSet: TDataSet; AItem: T; AType: TRttiInstanceType);
    procedure AssignTypeFromDataSet<T: class>(AItem: T; ADataSet: TDataSet; AType: TRttiInstanceType);
    procedure TypeToDataSet<T: class>(AItems: TList<T>; ADataSet: TDataSet);
    procedure DataSetToType<T: class>(ADataSet: TDataSet; AItems: TList<T>);

    property AllowModifyReadOnlyField: Boolean read FAllowModifyReadOnlyField write FAllowModifyReadOnlyField;
  end;

  TDvJsonMarshaller = class(TCustomDvMarshaller)
  public
    function GetJSONFromValue(AType: TRttiType; AValue: TValue): TJSONValue;
    function GetValueFromJSON(AType: PTypeInfo; AValue: TJSONValue): TValue;

    procedure AssignObjectFromType(AJSON: TJSONObject; AItem: Pointer; AType: TRttiInstanceType);
    procedure AssignTypeFromObject<T: class>(AItem: T; AJSON: TJSONObject; AType: TRttiInstanceType);

    procedure TypeToJSON<T: class>(AItems: TList<T>; AJSON: TJSONArray);
    procedure JSONToType<T: class>(AJSON: TJSONArray; AItems: TList<T>);
  end;

function PascalToSnakeCase(AValue: string): string;
function SnakeCaseToPascal(AValue: string): string;

function IsNullableType(ATypeInfo: PTypeInfo): Boolean;
function IsNullableNull(ATypeInfo: PTypeInfo; AValue: TValue): Boolean;
function GetNullableActualType(ATypeInfo: PTypeInfo): PTypeInfo;
function GetNullableActualValue(ATypeInfo: PTypeInfo; AData: Pointer): TValue;

implementation

const
{$IF SizeOf(Pointer) = 4}
  PROPSLOT_MASK_F    = $000000FF;
{$ELSEIF SizeOf(Pointer) = 8}
  PROPSLOT_MASK_F    = $00000000000000FF;
{$ENDIF}

///  <summary>
///  https://github.com/RRUZ/blog/blob/master/RTTI/Getting%20the%20getter%20and%20setter%20of%20a%20property%20using%20RTTI/uRttiHelper.pas
///  </summary>

function IsField(P: Pointer): Boolean; inline;
begin
  Result := (IntPtr(P) and PROPSLOT_MASK) = PROPSLOT_FIELD;
end;

function GetCodePointer(Instance: TObject; P: Pointer): Pointer; inline;
begin
  if (IntPtr(P) and PROPSLOT_MASK) = PROPSLOT_VIRTUAL then // Virtual Method
    Result := PPointer(PNativeUInt(Instance)^ + (UIntPtr(P) and $FFFF))^
  else // Static method
    Result := P;
end;

function PascalToSnakeCase(AValue: string): string;
begin
  Result := AValue.Substring(0, 1).ToLower + AValue.Substring(1);
end;

function SnakeCaseToPascal(AValue: string): string;
begin
  Result := AValue.Substring(0, 1).ToUpper + AValue.Substring(1);
end;

function IsNullableType(ATypeInfo: PTypeInfo): Boolean;
begin
  Result :=
    (ATypeInfo = TypeInfo(Nullable<TGUID>)) or
    (ATypeInfo = TypeInfo(Nullable<string>)) or
    (ATypeInfo = TypeInfo(Nullable<Integer>)) or
    (ATypeInfo = TypeInfo(Nullable<Int64>)) or
    (ATypeInfo = TypeInfo(Nullable<Double>)) or
    (ATypeInfo = TypeInfo(Nullable<Currency>)) or
    (ATypeInfo = TypeInfo(Nullable<TDate>)) or
    (ATypeInfo = TypeInfo(Nullable<TDateTime>)) or
    (ATypeInfo = TypeInfo(Nullable<TTime>));
end;

function IsNullableNull(ATypeInfo: PTypeInfo; AValue: TValue): Boolean;
begin
  if ATypeInfo = TypeInfo(Nullable<TGUID>) then
    Result := not AValue.AsType<Nullable<TGUID>>.HasValue
  else if ATypeInfo = TypeInfo(Nullable<string>) then
    Result := not AValue.AsType<Nullable<string>>.HasValue
  else if ATypeInfo = TypeInfo(Nullable<Integer>) then
    Result := not AValue.AsType<Nullable<Integer>>.HasValue
  else if ATypeInfo = TypeInfo(Nullable<Int64>) then
    Result := not AValue.AsType<Nullable<Int64>>.HasValue
  else if ATypeInfo = TypeInfo(Nullable<Double>) then
    Result := not AValue.AsType<Nullable<Double>>.HasValue
  else if ATypeInfo = TypeInfo(Nullable<Currency>) then
    Result := not AValue.AsType<Nullable<Double>>.HasValue
  else if ATypeInfo = TypeInfo(Nullable<TDate>) then
    Result := not AValue.AsType<Nullable<TDate>>.HasValue
  else if ATypeInfo = TypeInfo(Nullable<TDateTime>) then
    Result := not AValue.AsType<Nullable<TDateTime>>.HasValue
  else if ATypeInfo = TypeInfo(Nullable<TTime>) then
    Result := not AValue.AsType<Nullable<TTime>>.HasValue
  else
    raise Exception.Create('IsNullableNull: ' + TRttiContext.Create.GetType(ATypeInfo).Name + ' is not implemented.');
end;

function GetNullableActualType(ATypeInfo: PTypeInfo): PTypeInfo;
var
  AField: TRTTIField;
begin
  AField := TRttiContext.Create.GetType(ATypeInfo).GetField('FValue');
  Result := AField.FieldType.Handle;
end;

function GetNullableActualValue(ATypeInfo: PTypeInfo; AData: Pointer): TValue;
var
  AField: TRTTIField;
begin
  AField := TRttiContext.Create.GetType(ATypeInfo).GetField('FValue');
  Result := AField.GetValue(AData);
end;

{ TDataSetMarshaller }

procedure TDvDataSetMarshaller.AssignFieldDef(AFieldDef: TFieldDef; AFieldInfo: TFieldInfo);
begin
  AFieldDef.Name := AFieldInfo.TypeName;
  AFieldDef.Required := not IsNullableType(AFieldInfo.TypeInfo);
  if not AFieldDef.Required then
    AFieldDef.DataType := TypeInfoToDataType(GetNullableActualType(AFieldInfo.TypeInfo))
  else
    AFieldDef.DataType := TypeInfoToDataType(AFieldInfo.TypeInfo);
  if (AFieldInfo.TypeInfo^.Kind = tkString) and (AFieldInfo.MaxLength = 0) then
    AFieldDef.DataType := ftMemo;
  if AFieldDef.DataType = ftGuid then
     AFieldDef.Size := 38;
end;

procedure TDvDataSetMarshaller.AssignFieldsFromType<T>(ADataSet: TDataSet; AItem: T; AType: TRttiInstanceType);
var
  AFieldInfo: TFieldInfo;
  AProperty: TRttiProperty;
  AField: TField;
  AReadOnly: Boolean;
begin
  for AFieldInfo in GetFieldInfoFromType<T> do
  begin
    AProperty := AType.GetProperty(AFieldInfo.TypeName);
    if AProperty = nil then
      raise Exception.Create('Förväntad property saknas: ' + AFieldInfo.TypeName);

    AField := ADataSet.FindField(AFieldInfo.TypeName);
    if AField = nil then
      Continue;

    AReadOnly := AField.ReadOnly;
    if AReadOnly and not FAllowModifyReadOnlyField then
      raise Exception.Create('ReadOnly-fält får ej ändras på.');

    if AReadOnly then
      AField.ReadOnly := False;
    AField.Value := GetValueAsVariant(AProperty.PropertyType, AProperty.GetValue(TObject(AItem)));
    if AReadOnly then
      AField.ReadOnly := True;
  end;
end;

procedure TDvDataSetMarshaller.AssignTypeFromDataSet<T>(AItem: T; ADataSet: TDataSet; AType: TRttiInstanceType);
var
  AFieldInfo: TFieldInfo;
  AProperty: TRttiProperty;
  AField: TRttiField;
  AValue: TValue;
  ADBField: TField;
begin
  for AFieldInfo in GetFieldInfoFromType<T> do
  begin
    AProperty := AType.GetProperty(AFieldInfo.TypeName);
    if AProperty = nil then
      raise Exception.Create('Förväntat fält saknas: ' + AFieldInfo.TypeName);

    ADBField := ADataSet.FindField(AFieldInfo.TypeName);
    if not AProperty.IsWritable then
    begin
      if ADBField <> nil then
      begin
        AField := GetPropGetterField(AProperty);
        if (AField <> nil) then
          AField.SetValue(TObject(AItem), GetFieldAsValue(AField.FieldType, ADBField));
      end;
    end
    else if ADBField = nil then
      raise Exception.Create('Fält saknas i DataSet: ' + AFieldInfo.TypeName)
    else
      AProperty.SetValue(TObject(AItem), GetFieldAsValue(AProperty.PropertyType, ADBField));
  end;
end;

constructor TDvDataSetMarshaller.Create;
begin
  inherited;
  FAllowModifyReadOnlyField := False;
end;

procedure TDvDataSetMarshaller.DataSetToType<T>(ADataSet: TDataSet; AItems: TList<T>);
var
  AContext: TRttiContext;
  AType: TRttiInstanceType;
  AFieldInfoList: TList<TFieldInfo>;
  AFieldInfo: TFieldInfo;
  I, J: Integer;
  ABookmark: TBookmark;
  AItem: T;
  ATypeKind: TTypeKind;
begin
  AContext := TRttiContext.Create;
  ADataSet.DisableControls;
  try
    AType := AContext.GetType(TypeInfo(T)) as TRttiInstanceType;
    ABookmark := ADataSet.Bookmark;
    ADataSet.First;
    while not ADataSet.Eof do
    begin
      AItem := CreateInstance<T>;
      try
        AssignTypeFromDataSet<T>(AItem, ADataSet, AType);
      except
        AItem.Free;
        raise;
      end;
      AItems.Add(AItem);
      ADataSet.Next;
    end;
    if ADataSet.BookmarkValid(ABookmark) then
      ADataSet.Bookmark := ABookmark
    else
      ADataSet.First;
  finally
    ADataSet.EnableControls;
  end;
end;

function TDvDataSetMarshaller.GetFieldAsValue(AType: TRttiType; AField: TField): TValue;
begin
  if IsNullableType(AType.Handle) then
  begin
    if AField.DataType in [ftString, ftWideString, ftMemo, ftWideMemo] then
      Result := TValue.From(Nullable<string>(AField.Value))
    else if AField.DataType in [ftGuid] then
      Result := TValue.From(Nullable<TGUID>(AField.Value))
    else if AField.DataType in [ftInteger] then
      Result := TValue.From(Nullable<Integer>(AField.Value))
    else if AField.DataType in [ftSmallint] then
      Result := TValue.From(Nullable<SmallInt>(AField.Value))
    else if AField.DataType in [ftLargeint] then
      Result := TValue.From(Nullable<Int64>(AField.Value))
    else if AField.DataType in [ftFloat] then
      Result := TValue.From(Nullable<Double>(AField.Value))
    else if AField.DataType in [ftCurrency] then
      Result := TValue.From(Nullable<Currency>(AField.Value))
    else if AField.DataType in [ftDate, ftTime, ftDateTime] then
      Result := TValue.From(Nullable<TDateTime>(AField.Value))
    else
      raise Exception.Create('Typen ' + AField.ClassName + ' kan ej ännu konverteras till Nullable<T>');
  end
  else
  begin
    if AField is TGUIDField then
      Result := TValue.From(TGUIDField(AField).AsGuid)
    else
      Result := TValue.FromVariant(AField.Value);
  end;
end;

function TDvDataSetMarshaller.GetValueAsVariant(AType: TRttiType; AValue: TValue): Variant;
var
  ANullableString: Nullable<string>;
  ANullableGuid: Nullable<TGUID>;
  ANullableDouble: Nullable<Double>;
  ANullableInteger: Nullable<Integer>;
  ANullableDateTime: Nullable<TDateTime>;
begin
  if IsNullableType(AType.Handle) then
  begin
    if AValue.TryAsType<Nullable<string>>(ANullableString) then
      Result := ANullableString.ToVariant
    else if AValue.TryAsType<Nullable<TGUID>>(ANullableGuid) then
      Result := ANullableGuid.ToVariant
    else if AValue.TryAsType<Nullable<Double>>(ANullableDouble) then
      Result := ANullableDouble.ToVariant
    else if AValue.TryAsType<Nullable<Integer>>(ANullableInteger) then
      Result := ANullableInteger.ToVariant
    else if AValue.TryAsType<Nullable<TDatetime>>(ANullableDateTime) then
      Result := ANullableDateTime.ToVariant
    else
      raise Exception.Create('Typen ' + AType.Name + ' kan ej ännu konverteras till Variant');
  end
  else if AValue.TypeInfo = TypeInfo(TGUID) then
    Result := GUIDToString(AValue.AsType<TGUID>)
  else
    Result := AValue.AsVariant;
end;

function TDvDataSetMarshaller.TypeInfoToDataType(ATypeInfo: PTypeInfo): TFieldType;
begin
  if ATypeInfo = TypeInfo(TGUID) then
    Result := ftGuid
  else if ATypeInfo = TypeInfo(TDate) then
    Result := ftDate
  else if ATypeInfo = TypeInfo(TDateTime) then
    Result := ftDateTime
  else if ATypeInfo = TypeInfo(Currency) then
    Result := ftCurrency
  else
    case ATypeInfo^.Kind of
      tkClass : Result := ftObject;
      tkInteger: Result := ftInteger;
      tkInt64: Result := ftLargeint;
      tkFloat: Result := ftFloat;
      tkChar, tkString, tkUString, tkWChar, tkWString, tkLString: Result := ftString;
      tkEnumeration: Result := ftString;
      else raise Exception.Create('TypeInfoToDataType: Unhandled TTypeKind: ' + IntToStr(Ord(ATypeInfo^.Kind)));
    end;
end;

procedure TDvDataSetMarshaller.TypeToDataSet<T>(AItems: TList<T>; ADataSet: TDataSet);
var
  AContext: TRttiContext;
  AType: TRttiInstanceType;
  AFieldInfoList: TList<TFieldInfo>;
  AFieldInfo: TFieldInfo;
  AProperty: TRttiProperty;
  AKeyFields: TArray<string>;
  AValues: TArray<Variant>;

  I, J: Integer;
  AItem: T;
begin
  AContext := TRttiContext.Create;
  Try
    ADataSet.DisableControls;
    try
      AType := AContext.GetType(TypeInfo(T)) as TRttiInstanceType;
      AFieldInfoList := GetFieldInfoFromType<T>;
      AKeyFields := [];
      for AFieldInfo in AFieldInfoList do
        if AFieldInfo.Key then
          AKeyFields := AKeyFields + [AFieldInfo.TypeName];
      SetLength(AValues, Length(AKeyFields));
      for I := 0 to AItems.Count - 1 do
      begin
        AItem := AItems[I];
        for J := Low(AKeyFields) to High(AKeyFields) do
        begin
          AProperty := AType.GetProperty(AKeyFields[J]);
          AValues[J] := GetValueAsVariant(AProperty.PropertyType, AProperty.GetValue(TObject(AItem)));
        end;
        if ADataSet.Locate(string.Join(';', AKeyFields), VarArrayOf(AValues), []) then
          ADataSet.Edit
        else
          ADataSet.Append;
        AssignFieldsFromType<T>(ADataSet, AItem, AType);
        ADataSet.Post;
      end;
      ADataSet.First;
    finally
      ADataSet.EnableControls;
    end;
  finally
    AContext.Free;
  end;
end;

{ TCustomSDFMarshaller }

constructor TCustomDvMarshaller.Create;
begin
  inherited;
  FFieldInfoDict := TDictionary<PTypeInfo, TList<TFieldInfo>>.Create;
end;

function TCustomDvMarshaller.CreateInstance<T>: T;
var
  xInValue, xOutValue: TValue;
begin
  xInValue := GetTypeData(PTypeInfo(TypeInfo(T)))^.ClassType.Create;
  xInValue.TryCast(TypeInfo(T), xOutValue);
  Result := xOutValue.AsType<T>;
end;

destructor TCustomDvMarshaller.Destroy;
var
  AValue: TList<TFieldInfo>;
begin
  for AValue in FFieldInfoDict.Values do
    AValue.Free;
  FFieldInfoDict.Free;
  inherited;
end;

function TCustomDvMarshaller.GetDataTypeFromTypeKind(ATypeKind: TTypeKind): TFieldType;
begin
  case ATypeKind of
    tkEnumeration: Result := ftInteger;
    tkInteger: Result := ftInteger;
    tkInt64: Result := ftLargeint;
    tkChar, tkString, tkWideChar, tkWideString, tkLString, tkUString: Result := ftString;
    tkVariant: Result := ftVariant;
    tkFloat: Result := ftFloat;
    else Result := ftUnknown;
  end;
end;

function TCustomDvMarshaller.GetFieldInfoFromType<T>: TList<TFieldInfo>;
begin
  Result := GetFieldInfoFromTypeInfo(TypeInfo(T));
end;

function TCustomDvMarshaller.GetFieldInfoFromTypeInfo(ATypeInfo: PTypeInfo): TList<TFieldInfo>;
begin
  if not FFieldInfoDict.TryGetValue(ATypeInfo, Result) then
  begin
    Result := TObjectList<TFieldInfo>.Create;
    InitFieldInfo(ATypeInfo, Result);
    FFieldInfoDict.Add(ATypeInfo, Result);
  end;
end;

function TCustomDvMarshaller.GetKeyFields<T>: TArray<TFieldInfo>;
var
  I: Integer;
  AList: TList<TFieldInfo>;
begin
  Result := [];
  AList := GetFieldInfoFromType<T>;
  for I := 0 to AList.Count - 1 do
    if AList[I].Key then
      Result := Result + [AList[I]];
end;

class function TCustomDvMarshaller.GetName<T>: string;
begin
  Result := GetNameFromTypeInfo(TypeInfo(T));
end;

class function TCustomDvMarshaller.GetNameFromTypeInfo(ATypeInfo: PTypeInfo): string;
var
  AContext: TRTTIContext;
  AType: TRTTIType;
  AAttributes: TArray<TCustomAttribute>;
  AAttr: TCustomAttribute;
begin
  Result := '';
  AContext := TRttiContext.Create;
  try
    AType := AContext.GetType(ATypeInfo);
    AAttributes := AType.GetAttributes;
    // If attribute is specified
    for AAttr in AAttributes do
      if AAttr is NameAttribute then
      begin
        Result := NameAttribute(AAttr).Name;
        Exit;
      end;
    // Otherwise calculate from class name
    Result := AType.Name;
    if Result.StartsWith('T') then
      Result := Result.Substring(1);
  finally
    AContext.Free;
  end;
end;

function TCustomDvMarshaller.GetPropGetterField(AProp: TRttiProperty): TRttiField;
var
  LPropInfo : PPropInfo;
  LField: TRttiField;
  LOffset : Integer;
begin
  Result:=nil;
  //Is a readable property?
  if (AProp.IsReadable) and (AProp.ClassNameIs('TRttiInstancePropertyEx')) then
  begin
    //get the propinfo of the porperty
    LPropInfo:=TRttiInstanceProperty(AProp).PropInfo;
    //check if the GetProc represent a field
    if (LPropInfo<>nil) and (LPropInfo.GetProc<>nil) and IsField(LPropInfo.GetProc) then
    begin
      //get the offset of the field
      LOffset:= IntPtr(LPropInfo.GetProc) and PROPSLOT_MASK_F;
      //iterate over the fields of the class
      for LField in AProp.Parent.GetFields do
         //compare the offset the current field with the offset of the getter
         if LField.Offset=LOffset then
           Exit(LField);
    end;
  end;
end;

procedure TCustomDvMarshaller.InitFieldInfo(ATypeInfo: PTypeInfo; AFieldInfoList: TList<TFieldInfo>);
var
  AContext: TRTTIContext;
  AType: TRttiInstanceType;
  APropertyList: TArray<TRttiProperty>;
  AProperty: TRttiProperty;
  AAttr: TCustomAttribute;
  AFieldInfo: TFieldInfo;
begin
  AContext := TRttiContext.Create;
  try
    AType := AContext.GetType(ATypeInfo) as TRttiInstanceType;
    APropertyList := AType.GetProperties;
    for AProperty in APropertyList do
    begin
      if AProperty.Visibility in [mvPublic, mvPublished] then
      begin
        AFieldInfo := TFieldInfo.Create;
        AFieldInfoList.Add(AFieldInfo);
        AFieldInfo.TypeName := AProperty.Name;
        AFieldInfo.Nullable := IsNullableType(AProperty.PropertyType.Handle);
        AFieldInfo.ReadOnly := not AProperty.IsWritable;
        // Get from attributes
        for AAttr in AProperty.GetAttributes do
        begin
          if AAttr is MaxLengthAttribute then
            AFieldInfo.MaxLength := MaxLengthAttribute(AAttr).Value
          else if AAttr is MinLengthAttribute then
            AFieldInfo.MinLength := MinLengthAttribute(AAttr).Value
          else if AAttr is KeyAttribute then
            AFieldInfo.Key := True;
        end;
        AFieldInfo.TypeInfo := AProperty.PropertyType.Handle;
      end;
    end;
  finally
    AContext.Free;
  end;
end;

{ TSDFJsonMarshaller }

procedure TDvJsonMarshaller.AssignObjectFromType(AJSON: TJSONObject; AItem: Pointer; AType: TRttiInstanceType);
var
  AFieldInfo: TFieldInfo;
  AProperty: TRttiProperty;
  AJSONValue: TJSONValue;
begin
  for AFieldInfo in GetFieldInfoFromTypeInfo(AType.Handle) do
  begin
    AProperty := AType.GetProperty(AFieldInfo.TypeName);
    if AProperty = nil then
      raise Exception.Create('Förväntad property saknas: ' + AFieldInfo.TypeName);
    AJSON.AddPair(PascalToSnakeCase(AFieldInfo.TypeName), GetJSONFromValue(AProperty.PropertyType, AProperty.GetValue(TObject(AItem))));
  end;
end;

procedure TDvJsonMarshaller.AssignTypeFromObject<T>(AItem: T; AJSON: TJSONObject; AType: TRttiInstanceType);
var
  AFieldInfo: TFieldInfo;
  AProperty: TRttiProperty;
  AField: TRttiField;
  AValue: TValue;
  AJSONValue: TJSONValue;
begin
  for AFieldInfo in GetFieldInfoFromType<T> do
  begin
    AProperty := AType.GetProperty(AFieldInfo.TypeName);
    if AProperty = nil then
      raise Exception.Create('Förväntat fält saknas: ' + AFieldInfo.TypeName);

    AJSONValue := AJSON.GetValue(PascalToSnakeCase(AProperty.Name));
    if AJSONValue = nil then
      Continue;

    if not AProperty.IsWritable then
    begin
      AField := GetPropGetterField(AProperty);
      if (AField <> nil) then
        AField.SetValue(TObject(AItem), GetValueFromJSON(AField.FieldType.Handle, AJSONValue));
    end
    else
      AProperty.SetValue(TObject(AItem), GetValueFromJSON(AProperty.PropertyType.Handle, AJSONValue));
  end;
end;

function TDvJsonMarshaller.GetJSONFromValue(AType: TRttiType; AValue: TValue): TJSONValue;
var
  AInnerValue: TValue;
  AGUID: TGUID;
begin
  if IsNullableType(AType.Handle) then
  begin
    if IsNullableNull(AType.Handle, AValue) then
      Result := TJSONNull.Create
    else
    begin
      AInnerValue := GetNullableActualValue(AType.Handle, AValue.GetReferenceToRawData);
      Result := GetJSONFromValue(TRttiContext.Create.GetType(AInnerValue.TypeInfo), AInnerValue);
    end;
  end
  else if AValue.TryAsType<TGUID>(AGUID) then
    Result := TJSONString.Create(GuidToString(AGUID))
  else
    Result := TJSONUnMarshal.TValueToJson(AValue);
end;

function TDvJsonMarshaller.GetValueFromJSON(AType: PTypeInfo; AValue: TJSONValue): TValue;
var
  AName: TSymbolName;
  AInnerType: PTypeInfo;
  AInnerValue: TValue;
begin
  AName := AType.Name;
  if IsNullableType(AType) then
  begin
    if AValue.Null then
      Result := TValue.Empty
    else
    begin
      AInnerType := GetNullableActualType(AType);
      AInnerValue := GetValueFromJSON(AInnerType, AValue);
      if AInnerType = TypeInfo(TGUID) then
        Result := TValue.From<Nullable<TGUID>>(AInnerValue.AsType<TGUID>)
      else if AInnerType = TypeInfo(TDate) then
        Result := TValue.From<Nullable<TDate>>(AInnerValue.AsType<TDate>)
      else if AInnerType = TypeInfo(TDateTime) then
        Result := TValue.From<Nullable<TDateTime>>(AInnerValue.AsType<TDateTime>)
      else if AInnerType = TypeInfo(Integer) then
        Result := TValue.From<Nullable<Integer>>(AInnerValue.AsType<Integer>)
      else if AInnerType = TypeInfo(Int64) then
        Result := TValue.From<Nullable<Int64>>(AInnerValue.AsType<Int64>)
      else if AInnerType = TypeInfo(Boolean) then
        Result := TValue.From<Nullable<Boolean>>(AInnerValue.AsType<Boolean>)
      else if AInnerType = TypeInfo(Double) then
        Result := TValue.From<Nullable<Double>>(AInnerValue.AsType<Double>)
      else if AInnerType = TypeInfo(Currency) then
        Result := TValue.From<Nullable<Currency>>(AInnerValue.AsType<Currency>)
      else if AInnerType = TypeInfo(string) then
        Result := TValue.From<Nullable<string>>(AInnerValue.AsType<string>)
      else
        raise Exception.Create('GetValueFromJSON: Unhandled Nullable type: ' + Ord(AInnerType^.Kind).ToString);
    end;
  end
  else if AType = TypeInfo(TGUID) then
    Result := TValue.From(StringToGuid(AValue.Value))
  else if AType = TypeInfo(TDate) then
    Result := StrToDate(AValue.Value, GetJSONFormat)
  else if AType = TypeInfo(TDateTime) then
    Result := StrToDateTime(AValue.Value, GetJSONFormat)
  else if AType = TypeInfo(Integer) then
    Result := AValue.GetValue<Integer>
  else if AType = TypeInfo(Int64) then
    Result := AValue.GetValue<Int64>
  else if AType = TypeInfo(Boolean) then
    Result := AValue.GetValue<Boolean>
  else if AType = TypeInfo(Double) then
    Result := AValue.GetValue<Double>
  else if AType = TypeInfo(Currency) then
    Result := AValue.GetValue<Currency>
  else if AType = TypeInfo(string) then
    Result := AValue.GetValue<string>
  else
    raise Exception.Create('GetValueFromJSON: Unhandled type: ' + Ord(AType^.Kind).ToString);
end;

procedure TDvJsonMarshaller.JSONToType<T>(AJSON: TJSONArray; AItems: TList<T>);
var
  AContext: TRttiContext;
  AType: TRttiInstanceType;
  AJSONValue: TJSONValue;
  AItem: T;
begin
  AContext := TRttiContext.Create;
  AType := AContext.GetType(TypeInfo(T)) as TRttiInstanceType;
  for AJSONValue in AJSON do
  begin
    if not (AJSONValue is TJSONObject) then
      raise Exception.Create('JSONToType: Invalid JSON value. Expecting Array of TJSONObject.');
    AItem := CreateInstance<T>;
    try
      AssignTypeFromObject<T>(AItem, AJSONValue as TJSONObject, AType);
    except
      AItem.Free;
      raise;
    end;
    AItems.Add(AItem);
  end;
end;

procedure TDvJsonMarshaller.TypeToJSON<T>(AItems: TList<T>; AJSON: TJSONArray);
var
  AContext: TRttiContext;
  AType: TRttiInstanceType;
  AFieldInfoList: TList<TFieldInfo>;
  AFieldInfo: TFieldInfo;
  AProperty: TRttiProperty;
  //AKeyFields: TArray<string>;
  //AValues: TArray<Variant>;
  AJSONObject: TJSONObject;

  I, J: Integer;
  AItem: T;
begin
  AContext := TRttiContext.Create;
  Try
    AType := AContext.GetType(TypeInfo(T)) as TRttiInstanceType;
    AFieldInfoList := GetFieldInfoFromType<T>;
//    AKeyFields := [];
//    for AFieldInfo in AFieldInfoList do
//      if AFieldInfo.Key then
//        AKeyFields := AKeyFields + [AFieldInfo.TypeName];
//    SetLength(AValues, Length(AKeyFields));
    for I := 0 to AItems.Count - 1 do
    begin
      AItem := AItems[I];
//      for J := Low(AKeyFields) to High(AKeyFields) do
//      begin
//        AProperty := AType.GetProperty(AKeyFields[J]);
//        AValues[J] := GetValueAsVariant(AProperty.PropertyType, AProperty.GetValue(TObject(AItem)));
//      end;
      AJSONObject := TJSONObject.Create;
      AssignObjectFromType(AJSONObject, @AItem, AType);
      AJSON.AddElement(AJSONObject);
    end;
  finally
    AContext.Free;
  end;
end;

end.

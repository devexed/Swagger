unit Dv.SwaggerAPI;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.TypInfo,
  IdHTTP,
  REST.JSON,
  Dv.Marshaller;

type

  TSwaggerDataType = (dtNone, dtString, dtInteger, dtFloat, dtBoolean, dtArray, dtObject, dtFile);

  TSwaggerParameterLocation = (plPath, plQuery, plBody, plFormData, plHeader);

  TSwaggerDataFormat = string;

  TSwaggerDefinition = class
  public
    _Ref: string;
    Description: string;
    DataType: TSwaggerDataType;
    Format: TSwaggerDataFormat;
    MaxLength: Integer;
    Enum: TArray<string>;
    Properties: TDictionary<string, TSwaggerDefinition>;
    constructor Create;
    destructor Destroy; override;
  end;

  TSwaggerParameter = class
    Location: TSwaggerParameterLocation; // called 'in' in the swagger spec
    Name: string;
    Description: string;
    Required: Boolean;
    Schema: TSwaggerDefinition;
    destructor Destroy; override;
  end;

  TSwaggerResponse = class
    Description: string;
    Schema: TSwaggerDefinition;
    destructor Destroy; override;
  end;

  TSwaggerRequest = class
    Summary: string;
    OperationId: string;
    Responses: TDictionary<string, TSwaggerResponse>; // Key is HTTP Reponse codes + 'default'
    Parameters: TObjectList<TSwaggerParameter>;
    constructor Create;
    destructor Destroy; override;
  end;

  TSwaggerPath = class
    Get: TSwaggerRequest;
    Post: TSwaggerRequest;
    Put: TSwaggerRequest;
    Delete: TSwaggerRequest;
    destructor Destroy; override;
  end;

  TSwaggerAPI = class
  private
    FMarshaller: TSDFJSONMarshaller;

    FSwaggerVersion: string;
    FTitle: string;
    FVersion: string;
    FDefinitions: TDictionary<string, TSwaggerDefinition>;
    FPaths: TDictionary<string, TSwaggerPath>;
    // General conversions
    function StrToDataType(AValue: string): TSwaggerDataType;
    function DataTypeToStr(AValue: TSwaggerDataType): string;
    function ParamLocationToStr(AValue: TSwaggerParameterLocation): string;
    function TypeInfoToDataType(ATypeInfo: PTypeInfo): TSwaggerDataType;
    function FieldInfoToDefType(AFieldInfo: TFieldInfo): TSwaggerDataType;
    function FieldInfoToFormat(AFieldInfo: TFieldInfo): TSwaggerDataFormat;
    // Load from JSON
    //
    function GetDefinition(AJSON: TJSONValue): TSwaggerDefinition;
    function GetPath(AJSON: TJSONValue): TSwaggerPath;
    function GetRequest(AJSON: TJSONValue): TSwaggerRequest;
    function GetResponse(AJSON: TJSONValue): TSwaggerResponse;
    // Save to JSON
    //
    function GetDefinitionListJSON: TJSONObject;
    function GetDefinitionJSON(ADefinition: TSwaggerDefinition): TJSONObject;
    function GetPathListJSON: TJSONObject;
    function GetPathJSON(APath: TSwaggerPath): TJSONObject;
    function GetRequestJSON(ARequest: TSwaggerRequest): TJSONObject;
    function GetParameterJSON(AParam: TSwaggerParameter): TJSONObject;
    function GetResponseJSON(AResponse: TSwaggerResponse): TJSONObject;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadFromURL(AURL: string);
    procedure LoadFromStream(AStream: TStream);
    procedure LoadFromString(AString: string);
    procedure SaveToStream(AStream: TStream; APretty: Boolean = False);

    function GetRefDefinition<T: class>: TSwaggerDefinition;
    procedure AddDefinitionFromType<T: class>;

    property Title: string read FTitle write FTitle;
    property Version: string read FVersion write FVersion;
    property Definitions: TDictionary<string, TSwaggerDefinition> read FDefinitions;
    property Paths: TDictionary<string, TSwaggerPath> read FPaths;
  end;

const
  // https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md#dataTypeFormat
  sFormatNone = '';
  sFormatInt32 = 'int32'; // signed 32 bits
  sFormatInt64 = 'int64';	// signed 64 bits
  sFormatCurrency = 'currency';
  sFormatGuid = 'uuid';
  sFormatByte = 'byte';	// base64 encoded characters
  sFormatBinary = 'binary';	// any sequence of octets
  sFormatDate = 'date'; // As defined by full-date - RFC3339
  sFormatDateTime = 'date-time';	// As defined by date-time - RFC3339
  sFormatPassword = 'password'; // Used to hint UIs the input needs to be obscured

implementation

{ TSwaggerDefinition }

constructor TSwaggerDefinition.Create;
begin
  inherited;
  Properties := TDictionary<string, TSwaggerDefinition>.Create;
  DataType := dtNone;
  Format := sFormatNone;
end;

destructor TSwaggerDefinition.Destroy;
var
  AProp: TSwaggerDefinition;
begin
  for AProp in Properties.Values do
    AProp.Free;
  Properties.Free;
  inherited;
end;

{ TSwaggerAPI }

function TSwaggerAPI.GetResponse(AJSON: TJSONValue): TSwaggerResponse;
var
  AStrValue: string;
  AJSONValue: TJSONValue;
begin
  Result := TSwaggerResponse.Create;
  if AJSON.TryGetValue<string>('description', AStrValue) then
    Result.Description := AStrValue;
  if AJSON.TryGetValue<TJSONValue>('schema', AJSONValue) then
    Result.Schema := GetDefinition(AJSONValue);
end;

function TSwaggerAPI.GetResponseJSON(AResponse: TSwaggerResponse): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('description', AResponse.Description);
  if AResponse.Schema <> nil then
    Result.AddPair('schema', GetDefinitionJSON(AResponse.Schema));
end;

procedure TSwaggerAPI.AddDefinitionFromType<T>;
var
  ADefinition: TSwaggerDefinition;
  AProperty: TSwaggerDefinition;
  AFieldInfoList: TList<TFieldInfo>;
  AFieldInfo: TFieldInfo;
begin
  ADefinition := TSwaggerDefinition.Create;
  ADefinition.DataType := dtObject;
  AFieldInfoList := FMarshaller.GetFieldInfoFromType<T>;
  for AFieldInfo in AFieldInfoList do
  begin
    AProperty := TSwaggerDefinition.Create;

    AProperty.DataType := FieldInfoToDefType(AFieldInfo);
    AProperty.Format := FieldInfoToFormat(AFieldInfo);

    ADefinition.Properties.Add(PascalToSnakeCase(AFieldInfo.TypeName), AProperty);
  end;

  Definitions.Add(FMarshaller.GetName<T>, ADefinition);
end;

constructor TSwaggerAPI.Create;
begin
  inherited Create;
  FMarshaller := TSDFJsonMarshaller.Create;
  FSwaggerVersion := '2.0';
  FDefinitions := TDictionary<string, TSwaggerDefinition>.Create;
  FPaths := TDictionary<string, TSwaggerPath>.Create;
end;

function TSwaggerAPI.StrToDataType(AValue: string): TSwaggerDataType;
begin
  if AValue = 'object' then
    Result := dtObject
  else if AValue = 'integer' then
    Result := dtInteger
  else if AValue = 'float' then
    Result := dtFloat
  else if AValue = 'string' then
    Result := dtString
  else if AValue = 'boolean' then
    Result := dtBoolean
  else if AValue = 'array' then
    Result := dtArray
  else if AValue = 'file' then
    Result := dtFile
  else
    raise Exception.Create('StrToDefType: Unknown Definition type: ' + AValue);
end;

function TSwaggerAPI.TypeInfoToDataType(ATypeInfo: PTypeInfo): TSwaggerDataType;
begin
  if ATypeInfo = TypeInfo(TGUID) then
    Result := dtString
  else
    case ATypeInfo^.Kind of
      tkClass : Result := dtObject;
      tkInteger, tkInt64: Result := dtInteger;
      tkFloat: Result := dtFloat;
      tkChar, tkString, tkUString, tkWChar, tkWString, tkLString: Result := dtString;
      tkEnumeration: Result := dtString;
      else raise Exception.Create('FieldInfoToDefType: Unhandled TTypeKind: ' + IntToStr(Ord(ATypeInfo^.Kind)));
    end;
end;

destructor TSwaggerAPI.Destroy;
var
  ADef: TSwaggerDefinition;
  APath: TSwaggerPath;
begin
  for ADef in FDefinitions.Values do
    ADef.Free;
  FDefinitions.Free;

  for APath in FPaths.Values do
    APath.Free;
  FPaths.Free;

  FMarshaller.Free;

  inherited;
end;

function TSwaggerAPI.FieldInfoToDefType(AFieldInfo: TFieldInfo): TSwaggerDataType;
begin
  if IsNullableType(AFieldInfo.TypeInfo) then
    Result := TypeInfoToDataType(GetNullableActualType(AFieldInfo.TypeInfo))
  else
    Result := TypeInfoToDataType(AFieldInfo.TypeInfo);
end;

function TSwaggerAPI.FieldInfoToFormat(AFieldInfo: TFieldInfo): TSwaggerDataFormat;
begin
  if AFieldInfo.TypeInfo = TypeInfo(TGUID) then
    Result := sFormatGuid
  else if AFieldInfo.TypeInfo = TypeInfo(Currency) then
    Result := sFormatCurrency
  else if AFieldInfo.TypeInfo = TypeInfo(TDate) then
    Result := sFormatDate
  else if AFieldInfo.TypeInfo = TypeInfo(TDateTime) then
    Result := sFormatDateTime
  else
    case AFieldInfo.TypeInfo^.Kind of
      tkInteger: Result := sFormatInt32;
      tkInt64: Result := sFormatInt64;
      else Result := sFormatNone;
    end;
end;

function TSwaggerAPI.DataTypeToStr(AValue: TSwaggerDataType): string;
begin
  case AValue of
    dtString: Result := 'string';
    dtObject: Result := 'object';
    dtBoolean: Result := 'boolean';
    dtInteger: Result := 'integer';
    dtFloat: Result := 'float';
    dtArray: result := 'array';
    dtFile: result := 'file';
    else raise Exception.Create('DefTypeToStr: Unhandled TDefinitionType: ' + IntToStr(Ord(AValue)));
  end;
end;

function TSwaggerAPI.GetDefinition(AJSON: TJSONValue): TSwaggerDefinition;
var
  AJSONPropList: TJSONObject;
  AJSONProp: TJSONPair;
  AProp: TSwaggerDefinition;
  AStrValue: string;
begin
  Result := TSwaggerDefinition.Create;
  if AJSON.TryGetValue<string>('$ref', AStrValue) then
  begin
    Result._Ref := AStrValue;
    Exit;
  end;
  Result.DataType := StrToDataType(AJSON.GetValue<string>('type'));
  if AJSON.TryGetValue<string>('format', AStrValue) then
    Result.Format := AStrValue;
  if AJSON.TryGetValue<string>('description', AStrValue) then
    Result.Description := AStrValue;
  if AJSON.TryGetValue<string>('maxLength', AStrValue) then
    Result.MaxLength := AStrValue.ToInteger;
//  if AJSON.TryGetValue<TJSONArray>('enum', AArrayValue) then
//    ADefinition.Enum := ;
  if (Result.DataType = dtObject) and AJSON.TryGetValue<TJSONObject>('properties', AJSONPropList) then
  begin
    for AJSONProp in AJSONPropList do
    begin
      AProp := GetDefinition(AJSONProp.JsonValue);
      Result.Properties.Add(AJSONProp.JsonString.Value, AProp);
    end;
  end;
end;

function TSwaggerAPI.GetDefinitionJSON(ADefinition: TSwaggerDefinition): TJSONObject;
var
  AProp: TPair<string, TSwaggerDefinition>;
  AJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  if ADefinition._Ref <> '' then
  begin
    Result.AddPair('$ref', ADefinition._Ref);
    Exit;
  end;
  if ADefinition.DataType <> dtNone then
    Result.AddPair('type', DataTypeToStr(ADefinition.DataType));
  if ADefinition.Format <> sFormatNone then
    Result.AddPair('format', ADefinition.Format);
  if ADefinition.Description <> '' then
    Result.AddPair('description', ADefinition.Description);
  if ADefinition.MaxLength <> 0 then
    Result.AddPair('maxLength', ADefinition.MaxLength.ToString);
  if ADefinition.Properties.Count > 0 then
  begin
    AJSON := TJSONObject.Create;
    for AProp in ADefinition.Properties do
      AJSON.AddPair(AProp.Key, GetDefinitionJSON(AProp.Value));
    Result.AddPair('properties', AJSON);
  end;
end;

function TSwaggerAPI.GetDefinitionListJSON: TJSONObject;
var
  ADefinition: TPair<string, TSwaggerDefinition>;
begin
  Result := TJSONObject.Create;
  for ADefinition in FDefinitions do
    Result.AddPair(ADefinition.Key, GetDefinitionJSON(ADefinition.Value));
end;

function TSwaggerAPI.GetParameterJSON(AParam: TSwaggerParameter): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('in', ParamLocationToStr(AParam.Location));
  Result.AddPair('name', AParam.Name);
  Result.AddPair('description', AParam.Description);
  Result.AddPair('required', TJSONBool.Create(AParam.Required));

  if AParam.Location = plPath then
  begin
    if AParam.Schema <> nil then
    begin
      Result.AddPair('type', DataTypeToStr(AParam.Schema.DataType));
      if AParam.Schema.Format <> sFormatNone then
        Result.AddPair('format', AParam.Schema.Format);
    end
    else
      raise Exception.Create('Parameter Schema is not defined: ' + AParam.Name);
  end
  else if AParam.Schema <> nil then
    Result.AddPair('schema', GetDefinitionJSON(AParam.Schema));
end;

function TSwaggerAPI.GetPath(AJSON: TJSONValue): TSwaggerPath;
var
  AJSONObject: TJSONObject;
begin
  Result := TSwaggerPath.Create;
  if AJSON.TryGetValue<TJSONObject>('get', AJSONObject) then
    Result.Get := GetRequest(AJSONObject);
  if AJSON.TryGetValue<TJSONObject>('post', AJSONObject) then
    Result.Post := GetRequest(AJSONObject);
  if AJSON.TryGetValue<TJSONObject>('put', AJSONObject) then
    Result.Put := GetRequest(AJSONObject);
  if AJSON.TryGetValue<TJSONObject>('delete', AJSONObject) then
    Result.Delete := GetRequest(AJSONObject);
end;

function TSwaggerAPI.GetPathJSON(APath: TSwaggerPath): TJSONObject;
begin
  Result := TJSONObject.Create;
  if APath.Get <> nil then
    Result.AddPair('get', GetRequestJSON(APath.Get));
  if APath.Post <> nil then
    Result.AddPair('post', GetRequestJSON(APath.Post));
  if APath.Put <> nil then
    Result.AddPair('put', GetRequestJSON(APath.Put));
  if APath.Delete <> nil then
    Result.AddPair('delete', GetRequestJSON(APath.Delete));
end;

function TSwaggerAPI.GetPathListJSON: TJSONObject;
var
  APath: TPair<string, TSwaggerPath>;
begin
  Result := TJSONObject.Create;
  for APath in FPaths do
    Result.AddPair(APath.Key, GetPathJSON(APath.Value));
end;

function TSwaggerAPI.GetRefDefinition<T>: TSwaggerDefinition;
begin
  Result := TSwaggerDefinition.Create;
  Result._Ref := '#/definitions/' + FMarshaller.GetName<T>;
end;

function TSwaggerAPI.GetRequest(AJSON: TJSONValue): TSwaggerRequest;
var
  AStrValue: string;
  AJSONList: TJSONObject;
  AJSONResponse: TJSONPair;
  AResponse: TSwaggerResponse;
begin
  Result := TSwaggerRequest.Create;
  if AJSON.TryGetValue<string>('summary', AStrValue) then
    Result.Summary := AStrValue;
  if AJSON.TryGetValue<string>('operationId', AStrValue) then
    Result.OperationId := AStrValue;

  AJSONList := AJSON.GetValue<TJSONObject>('responses');
  for AJSONResponse in AJSONList do
  begin
    AResponse := GetResponse(AJSONResponse.JsonValue);
    Result.Responses.Add(AJSONResponse.JsonString.GetValue<string>, AResponse);
  end;
end;

function TSwaggerAPI.GetRequestJSON(ARequest: TSwaggerRequest): TJSONObject;
var
  AJSON: TJSONObject;
  AJSONArray: TJSONArray;
  AResponse: TPair<string, TSwaggerResponse>;
  AParameter: TSwaggerParameter;
begin
  Result := TJSONObject.Create;
  Result.AddPair('summary', ARequest.Summary);
  Result.AddPair('operationId', ARequest.OperationId);
  if ARequest.Responses.Count > 0 then
  begin
    AJSON := TJSONObject.Create;
    for AResponse in ARequest.Responses do
      AJSON.AddPair(AResponse.Key, GetResponseJSON(AResponse.Value));
    Result.AddPair('responses', AJSON);
  end;
  if ARequest.Parameters.Count > 0 then
  begin
    AJSONArray := TJSONArray.Create;
    for AParameter in ARequest.Parameters do
      AJSONArray.Addelement(GetParameterJSON(AParameter));
    Result.AddPair('parameters', AJSONArray);
  end;
end;

procedure TSwaggerAPI.LoadFromStream(AStream: TStream);
var
  AStreamReader: TStreamReader;
begin
  AStreamReader := TStreamReader.Create(AStream);
  try
    LoadFromString(AStreamReader.ReadToEnd);
  finally
    AStreamReader.Free;
  end;
end;

procedure TSwaggerAPI.LoadFromString(AString: string);
var
  AJSON: TJSONValue;
  AJSONList: TJSONObject;
  AJSONPair: TJSONPair;
  ADef: TSwaggerDefinition;
  APath: TSwaggerPath;
begin
  AJSON := nil;
  try
    AJSON := TJSONObject.ParseJSONValue(AString);
    if AJSON = nil then
      raise Exception.Create('Kunde inte läsa JSON: ' + AString + '...');
    FTitle := AJSON.GetValue<string>('info.title');
    FVersion := AJSON.GetValue<string>('info.version');
    // Definitions
    AJSONList := AJSON.GetValue<TJSONObject>('definitions');
    for AJSONPair in AJSONList do
    begin
      ADef := GetDefinition(AJSONPair.JsonValue);
      FDefinitions.Add(AJSONPair.JsonString.Value, ADef);
    end;
    // Paths
    AJSONList := AJSON.GetValue<TJSONObject>('paths');
    for AJSONPair in AJSONList do
    begin
      APath := GetPath(AJSONPair.JsonValue);
      FPaths.Add(AJSONPair.JsonString.Value, APath);
    end;
  finally
    AJSON.Free;
  end;
end;

procedure TSwaggerAPI.LoadFromURL(AURL: string);
var
  AClient: TIdHTTP;
begin
  AClient := TIdHTTP.Create;
  try
    LoadFromString(AClient.Get(AURL));
  finally
    AClient.Free;
  end;
end;

function TSwaggerAPI.ParamLocationToStr(AValue: TSwaggerParameterLocation): string;
begin
  case AValue of
    plPath: Result := 'path';
    plQuery: Result := 'query';
    plBody: Result := 'body';
    plFormData: Result := 'form-data';
    plHeader: Result := 'header';
    else raise Exception.Create('Unknown TSwaggerParameterLocation: ' + IntToStr(Ord(AValue)));
  end;
end;

procedure TSwaggerAPI.SaveToStream(AStream: TStream; APretty: Boolean);
var
  AStreamWriter: TStreamWriter;
  AJSON: TJSONObject;
  AInfo: TJSONObject;
begin
  AStreamWriter := TStreamWriter.Create(AStream);
  AJSON := nil;
  try
    AJSON := TJSONObject.Create;
    AJSON.AddPair('swagger', FSwaggerVersion);
    // Info
    AInfo := TJSONObject.Create;
    AInfo.AddPair('title', FTitle);
    AInfo.AddPair('version', FVersion);
    AJSON.AddPair('info', AInfo);
    // Paths
    AJSON.AddPair('paths', GetPathListJSON);
    // Definitions
    AJSON.AddPair('definitions', GetDefinitionListJSON);
    // Save
    if APretty then
      AStreamWriter.Write(TJson.Format(AJSON))
    else
      AStreamWriter.Write(AJSON.ToString);
  finally
    AJSON.Free;
    AStreamWriter.Free;
  end;
end;

{ TSwaggerRequest }

constructor TSwaggerRequest.Create;
begin
  Responses := TDictionary<string, TSwaggerResponse>.Create;
  Parameters := TObjectList<TSwaggerParameter>.Create;
end;

destructor TSwaggerRequest.Destroy;
var
  AResponse: TSwaggerResponse;
begin
  for AResponse in Responses.Values do
    AResponse.Free;
  Responses.Free;
  Parameters.Free;
  inherited;
end;

{ TSwaggerPath }

destructor TSwaggerPath.Destroy;
begin
  Get.Free;
  Post.Free;
  Put.Free;
  Delete.Free;
  inherited;
end;

{ TSwaggerResponse }

destructor TSwaggerResponse.Destroy;
begin
  Schema.Free;
  inherited;
end;

{ TSwaggerParameter }

destructor TSwaggerParameter.Destroy;
begin
  Schema.Free;
  inherited;
end;

end.

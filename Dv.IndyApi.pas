unit Dv.IndyApi;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.TypInfo,
  System.Rtti,
  System.RegularExpressions,
  System.JSON,
  Dv.Marshaller,
  IdCustomHTTPServer,
  REST.JSON;

type

  TDvIndyApi = class
  private
    FPathRegEx: TRegEx;
  private
    FUrlFormatSettings: TFormatSettings;
    FJsonMarshaller: TDvJsonMarshaller;
    FMethods: TDictionary<string, TMethod>;
    function TryGetMethod(AURI: string; out AMethod: TMethod; out APathParams: TArray<string>): Boolean;
    function TryURIParamToValue(AStr: string; ATypeInfo: PTypeInfo; out AValue: TValue): Boolean;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    procedure AddMethod(APath: string; AData, ACode: Pointer);
    procedure ExectueRequest(ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
  end;

implementation

{ TSwaggerIndyServer }

procedure TDvIndyApi.AddMethod(APath: string; AData, ACode: Pointer);
var
  AMethod: TMethod;
begin
  AMethod.Data := AData;
  AMethod.Code := ACode;
  FMethods.Add(APath, AMethod);
end;

constructor TDvIndyApi.Create;
begin
  FUrlFormatSettings := TFormatSettings.Invariant;
  FJsonMarshaller := TDvJsonMarshaller.Create;
  FMethods := TDictionary<string, TMethod>.Create;
  //FPathRegEx := TRegEx.Create('\/[a-z]+', [roSingleLine, roIgnoreCase]);
end;

destructor TDvIndyApi.Destroy;
begin
  FMethods.Free;
  FJsonMarshaller.Free;
  inherited;
end;

procedure TDvIndyApi.ExectueRequest(ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo);
var
  AContext: TRttiContext;

  AType: TRttiInstanceType;
  AMethod: TMethod;
  APathParams: TArray<string>;
  AMethodParams: TArray<TRttiParameter>;
  AInputParamList: TArray<TValue>;
  AInputParam: TValue;
  I: Integer;

  AFound: Boolean;
  ARttiMethod: TRttiMethod;
  
  AResult: TValue;
  AResultType: TRttiType;
  AResultItem: TValue;

  AJSONArray: TJSONArray;
  AJSONObject: TJSONObject;
  AArrayItemType: TRttiInstanceType;
begin
  AResponseInfo.CharSet := 'utf-8'; // Den här är viktig för UTF-8
  AResponseInfo.ContentType := 'application/json';
  if TryGetMethod(ARequestInfo.URI, AMethod, APathParams) then
  begin
    AContext := TRttiContext.Create;
//    if not (AFunction.Data is TObject) then
//      raise Exception.Create('Registered instance is not a TObject.');
    AType := AContext.GetType(TObject(AMethod.Data).ClassType) as TRttiInstanceType;
    AFound := False;
    AResult := nil;
    for ARttiMethod in AType.GetMethods do
      if ARttiMethod.CodeAddress = AMethod.Code then
      begin
        AFound := True;
        AInputParamList := [];
        AMethodParams := ARttiMethod.GetParameters;
        for I := 0 to High(AMethodParams) do
          if not (pfOut in AMethodParams[I].Flags) and
            TryURIParamToValue(APathParams[I], AMethodParams[I].ParamType.Handle, AInputParam) then
            AInputParamList := AInputParamList + [AInputParam];

        if Length(AInputParamList) <> Length(APathParams) then
          raise Exception.CreateFmt('Invalid URL params in request: %s', [ARequestInfo.URI]);

        AResult := ARttiMethod.Invoke(TObject(AMethod.Data), AInputParamList);
        Break;
      end;
    if not AFound then
      raise Exception.CreateFmt('Method not found for URI: %s', [ARequestInfo.URI]);
                 
    AResultType := AContext.GetType(AResult.TypeInfo);
    if AResult.IsObject and (AResult.AsObject is TJSONValue) then
    begin
      AResponseInfo.ContentText := TJson.Format(AResult.AsType<TJSONValue>);
      AResult.AsObject.Free;
    end
    else if AResult.IsArray then
    begin           
      AJSONArray := TJSONArray.Create;
      try
        AArrayItemType := nil;
        for I := 0 to AResult.GetArrayLength - 1 do
        begin
          AResultItem := AResult.GetArrayElement(I);
          
          if AArrayItemType = nil then
            AArrayItemType := AContext.GetType(AResultItem.AsObject.ClassType) as TRttiInstanceType;

          if not AResultItem.IsObject then
            raise Exception.Create('Unhandled array item type: ' + AArrayItemType.Name);
                               
          AJSONObject := TJSONObject.Create;
          FJsonMarshaller.AssignObjectFromType(AJSONObject, AResultItem.AsObject, AArrayItemType);
          AJSONArray.AddElement(AJSONObject);

          AResultItem.AsObject.Free;
        end;
        AResponseInfo.ContentText := AJSONArray.ToString;
      finally
        AJSONArray.Free;
      end;
    end
    else if AResult.IsObject then
    begin
      AJSONObject := TJSONObject.Create;
      try
        FJsonMarshaller.AssignObjectFromType(AJSONObject, AResult.AsObject, AResultType as TRttiInstanceType);
        AResponseInfo.ContentText := AJSONObject.ToString;
        AResult.AsObject.Free;
      finally
        AJSONObject.Free;
      end;
    end
    else
      raise Exception.Create('Unhandled result type: ' + AResultType.Name);
  end
  else
  begin
    AResponseInfo.ResponseNo := 404;
    AResponseInfo.ContentText := '"Not found"';
    Exit;
  end;
end;

function TDvIndyApi.TryGetMethod(AURI: string; out AMethod: TMethod; out APathParams: TArray<string>): Boolean;
var
  APart: string;
  AMethodPair: TPair<string, TMethod>;
  AMethodParts: TArray<string>;
  AUriParts: TArray<string>;
  I: Integer;
begin
  Result := False;
  APathParams := [];
  for AMethodPair in FMethods do
  begin
    AMethodParts := AMethodPair.Key.Split(['/']);
    AUriParts := AURI.Split(['/']);
    if Length(AMethodParts) <> Length(AUriParts) then
      Continue;

    for I := Low(AMethodParts) to High(AUriParts) do
    begin
      if AMethodParts[I].StartsWith('{') and AMethodParts[I].EndsWith('}') then
        APathParams := APathParams + [AUriParts[I]] // Match
      else if AMethodParts[I] = AUriParts[I] then
        // Match
      else
        Break;
      // All matched
      if I = High(AUriParts) then
      begin
        AMethod := AMethodPair.Value;
        Exit(True);
      end;
    end;
  end;
end;

function TDvIndyApi.TryURIParamToValue(AStr: string; ATypeInfo: PTypeInfo; out AValue: TValue): Boolean;
begin
  Result := False;
  if ATypeInfo = TypeInfo(TGUID) then
  begin
    if not AStr.StartsWith('{') and not AStr.EndsWith('}') then
      AStr := '{' + AStr + '}';
    try
      AValue := TValue.From<TGUID>(StringToGuid(AStr));
      Result := True;
    except
      Result := False;
    end;
  end
  else
    Result := TValue.FromVariant(AStr).TryCast(ATypeInfo, AValue);
end;

end.

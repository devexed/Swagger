unit FormServer;

interface

uses
  System.JSON,
  System.Generics.Collections,
  Data.DB,
  Winapi.ActiveX,
  IdUri,
  Dv.SwaggerAPI,
  Dv.Marshaller,
  Dv.IndyApi,
  DemoTypes,
  // Auto
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, IdContext, IdCustomHTTPServer, IdBaseComponent, IdComponent, IdCustomTCPServer,
  IdHTTPServer, Data.Win.ADODB, Vcl.AppEvnts, IdScheduler, IdSchedulerOfThread, IdSchedulerOfThreadPool;

type

//  TArborderController = class(TApiResource)
//  public
//    [HttpGet('arborder/{id})]
//    function Get(AId: TGUID): TApiResponse;
//  end;

  TForm2 = class(TForm)
    IdHTTPServer1: TIdHTTPServer;
    ADOConnection: TADOConnection;
    DataSetHelp: TADODataSet;
    procedure IdHTTPServer1CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    procedure FormCreate(Sender: TObject);
    procedure IdHTTPServer1Connect(AContext: TIdContext);
    procedure IdHTTPServer1Disconnect(AContext: TIdContext);
  public
    function GetSwagger: TJSONValue;
    function GetOrder(AId: TGUID): TArborder;
  end;

var
  Form2: TForm2;

implementation

{$R *.dfm}

procedure TForm2.FormCreate(Sender: TObject);
begin
  ReportMemoryLeaksOnShutdown := True;
  IdHTTPServer1.Active := True;
end;

function TForm2.GetOrder(AId: TGUID): TArborder;
var
  ADatasetMarshaller: TDvDataSetMarshaller;
  AList: TList<TArborder>;
begin
  CoInitialize(nil);
  DataSetHelp.Close;
  DataSetHelp.CommandText := 'select * from ARBORDER where Id = ' + AId.ToString.QuotedString;
  DataSetHelp.Open;
  ADatasetMarshaller := TDvDataSetMarshaller.Create;
  try
    AList := TList<TArborder>.Create;
    ADatasetMarshaller.DataSetToType<TArborder>(DataSetHelp, AList);
    Result := AList[0];//.ToArray;
    AList.Free;
  finally
    ADatasetMarshaller.Free;
  end;
  DataSetHelp.Close;
  CoUninitialize;
end;

function TForm2.GetSwagger: TJSONValue;
var
  ASwaggerAPI: TSwaggerAPI;
  AParam: TSwaggerParameter;
begin
  ASwaggerAPI := TSwaggerAPI.Create;
  ASwaggerAPI.Title := 'SDF API';
  ASwaggerAPI.Version := '0.1';

  ASwaggerAPI.AddDefinitionFromType<TArborder>;

  ASwaggerAPI.Paths.Add('/arborder/{id}', TSwaggerPath.Create);
  ASwaggerAPI.Paths.Items['/arborder/{id}'].Get := TSwaggerRequest.Create;
  ASwaggerAPI.Paths.Items['/arborder/{id}'].Get.Summary := 'Hämta order per ID.';
  ASwaggerAPI.Paths.Items['/arborder/{id}'].Get.OperationId := 'GetArborderById';
  ASwaggerAPI.Paths.Items['/arborder/{id}'].Get.Responses.Add('200', TSwaggerResponse.Create);
  ASwaggerAPI.Paths.Items['/arborder/{id}'].Get.Responses.Items['200'].Description := 'Hämtning av order lyckades.';
  ASwaggerAPI.Paths.Items['/arborder/{id}'].Get.Responses.Items['200'].Schema := ASwaggerAPI.GetRefDefinition<TArborder>;

  AParam := TSwaggerParameter.Create;
  AParam.Name := 'id';
  AParam.Location := plPath;
  AParam.Description := 'Arbetsorderns ID';
  AParam.Required := True;
  AParam.Schema := TSwaggerDefinition.Create;
  AParam.Schema.DataType := dtString;
  AParam.Schema.Format := sFormatGuid;
  ASwaggerAPI.Paths.Items['/arborder/{id}'].Get.Parameters.Add(AParam);

  Result := TJSONObject.Create;
  ASwaggerAPI.SaveToJSON(Result as TJSONObject);
end;

procedure TForm2.IdHTTPServer1CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo);
var
  AIndyApi: TDvIndyApi;
begin
  AIndyApi := AContext.Data as TDvIndyApi;
  AIndyApi.ExectueRequest(ARequestInfo, AResponseInfo);
end;

procedure TForm2.IdHTTPServer1Connect(AContext: TIdContext);
var
  AIndyApi: TDvIndyApi;
begin
  AContext.Data := TDvIndyApi.Create;
  AIndyApi := TDvIndyApi(AContext.Data);
  AIndyApi.AddMethod('/swagger.json', Self, @TForm2.GetSwagger);
  AIndyApi.AddMethod('/arborder/{id}', Self, @TForm2.GetOrder);
end;

procedure TForm2.IdHTTPServer1Disconnect(AContext: TIdContext);
begin
  TDvIndyApi(AContext.Data).Free;
  AContext.Data := nil;
end;

end.

program Server;

uses
  Vcl.Forms,
  FormServer in 'FormServer.pas' {Form2},
  Dv.SwaggerAPI in 'Dv.SwaggerAPI.pas',
  Dv.Marshaller in 'Dv.Marshaller.pas',
  Dv.Rtti.Attributes in 'Dv.Rtti.Attributes.pas',
  Dv.Types in 'Dv.Types.pas',
  DemoTypes in 'DemoTypes.pas',
  Dv.IndyApi in 'Dv.IndyApi.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.

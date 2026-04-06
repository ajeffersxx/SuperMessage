program SuperMessageDemo;

uses
  System.StartUpCopy,
  FMX.Forms,
  UMainForm in 'UMainForm.pas' {Form11},
  SuperMessage in 'SuperMessage.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm11, Form11);
  Application.Run;
end.

unit UMainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.StdCtrls, FMX.Layouts, FMX.Controls.Presentation,
  SuperMessage;

type
  TForm11 = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    FLayout : TLayout;
    procedure AddDemoButton(const ACaption: string; AOnClick: TNotifyEvent);

    procedure OnShowInfo(Sender: TObject);
    procedure OnShowSuccess(Sender: TObject);
    procedure OnShowWarning(Sender: TObject);
    procedure OnShowError(Sender: TObject);
    procedure OnShowFatal(Sender: TObject);
    procedure OnShowQuestion(Sender: TObject);
    procedure OnShowNonModal(Sender: TObject);
    procedure OnShowMore(Sender: TObject);
  public
    { Public declarations }
  end;

var
  Form11: TForm11;

implementation

{$R *.fmx}

procedure TForm11.FormCreate(Sender: TObject);
var
  Title: TLabel;
begin
  Caption := 'SuperMessage Demo';
  Width   := 380;
  Height  := 540;

  Title := TLabel.Create(Self);
  Title.Parent := Self;
  Title.Align  := TAlignLayout.Top;
  Title.Height := 48;
  Title.Text   := 'SuperMessage Component Demo';
  Title.TextSettings.Font.Size  := 15;
  Title.TextSettings.Font.Style := [TFontStyle.fsBold];
  Title.TextSettings.HorzAlign  := TTextAlign.Center;
  Title.TextSettings.VertAlign  := TTextAlign.Center;

  FLayout := TLayout.Create(Self);
  FLayout.Parent         := Self;
  FLayout.Align          := TAlignLayout.Client;
  FLayout.Padding.Left   := 32;
  FLayout.Padding.Right  := 32;
  FLayout.Padding.Top    := 8;
  FLayout.Padding.Bottom := 16;

  AddDemoButton('Show Info',                      OnShowInfo);
  AddDemoButton('Show Success',                   OnShowSuccess);
  AddDemoButton('Show Warning',                   OnShowWarning);
  AddDemoButton('Show Error',                     OnShowError);
  AddDemoButton('Show Fatal',                     OnShowFatal);
  AddDemoButton('Show Question (Yes / No / Cancel)', OnShowQuestion);
  AddDemoButton('Show Non-Modal (with callback)', OnShowNonModal);
  AddDemoButton('Show with More... / Help button',OnShowMore);
end;

procedure TForm11.AddDemoButton(const ACaption: string; AOnClick: TNotifyEvent);
var
  Btn: TButton;
begin
  Btn := TButton.Create(Self);
  Btn.Parent         := FLayout;
  Btn.Align          := TAlignLayout.Top;
  Btn.Height         := 44;
  Btn.Margins.Bottom := 6;
  Btn.Text           := ACaption;
  Btn.OnClick        := AOnClick;
end;

{ ---- Demo handlers -------------------------------------------------------- }

procedure TForm11.OnShowInfo(Sender: TObject);
begin
  TSuperMessage.Show(
    'Information',
    'Your document has been saved successfully to the cloud.',
    smtInfo, [smbOK]);
end;

procedure TForm11.OnShowSuccess(Sender: TObject);
begin
  TSuperMessage.Show(
    'Upload Complete',
    'All 247 files were uploaded without errors.' + sLineBreak +
    'Total size: 1.4 GB',
    smtSuccess, [smbOK]);
end;

procedure TForm11.OnShowWarning(Sender: TObject);
begin
  TSuperMessage.Show(
    'Low Disk Space',
    'Your system drive has less than 500 MB of free space.' + sLineBreak +
    'Some features may stop working if disk space runs out.' + sLineBreak +
    'Please free up space or move your data to another drive.',
    smtWarning, [smbOK, smbIgnore]);
end;

procedure TForm11.OnShowError(Sender: TObject);
var
  Res: TSuperMessageResult;
begin
  Res := TSuperMessage.Show(
    'File Not Found',
    'The file "report_final_v3.docx" could not be opened.' + sLineBreak +
    'It may have been moved or deleted.',
    smtError, [smbRetry, smbCancel]);

  if Res = smrRetry then
    ShowMessage('Retrying...');
end;

procedure TForm11.OnShowFatal(Sender: TObject);
begin
  TSuperMessage.Show(
    'Fatal Error',
    'An unrecoverable error has occurred and the application must close.' +
    sLineBreak + sLineBreak +
    'Error code: 0xC0000005 — Access Violation at address 00401A2C',
    smtFatal, [smbClose]);
end;

procedure TForm11.OnShowQuestion(Sender: TObject);
var
  Res: TSuperMessageResult;
begin
  Res := TSuperMessage.Show(
    'Delete Files?',
    'Are you sure you want to permanently delete the selected 12 files?' +
    sLineBreak + 'This action cannot be undone.',
    smtQuestion, [smbYes, smbNo, smbCancel]);

  case Res of
    smrYes    : ShowMessage('Deleting files...');
    smrNo     : ShowMessage('Cancelled — files kept.');
    smrCancel : ShowMessage('Cancelled.');
  end;
end;

procedure TForm11.OnShowNonModal(Sender: TObject);
begin
  TSuperMessage.ShowNonModal(
    'Background Sync',
    'Synchronisation is running in the background.' + sLineBreak +
    'You can continue working while this completes.',
    smtInfo, [smbOK, smbCancel],
    procedure(R: TSuperMessageResult)
    begin
      if R = smrCancel then
        ShowMessage('Non-modal callback: sync was cancelled.');
    end);
end;

procedure TForm11.OnShowMore(Sender: TObject);
var
  Cfg: TSuperMessageConfig;
begin
  Cfg := TSuperMessageConfig.Create;
  try
    Cfg.Title       := 'Connection Error';
    Cfg.Message     := 'Unable to connect to the server.' + sLineBreak +
                       'Check your network settings and try again, or click ' +
                       'Help for troubleshooting steps.';
    Cfg.MsgType     := smtError;
    Cfg.Buttons     := [smbRetry, smbCancel, smbMore];
    Cfg.MoreCaption := 'Help';
    Cfg.OnMore      := procedure
                       begin
                         ShowMessage('Help action fired.' + sLineBreak +
                           '(In production this would open a browser or help form.)');
                       end;
    TSuperMessage.ShowConfig(Cfg);
  finally
    Cfg.Free;
  end;
end;

end.

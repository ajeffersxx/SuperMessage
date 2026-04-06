unit SuperMessage;

{
  SuperMessage.pas
  A flexible, cross-platform FMX message dialog component.

  Usage (modal):
    var Res: TSuperMessageResult;
    Res := TSuperMessage.Show('File not found', 'The file could not be opened.',
      smtError, [smbOK]);

  Usage (non-modal with callback):
    TSuperMessage.ShowNonModal(
      'Delete file?', 'This action cannot be undone.',
      smtWarning, [smbYes, smbNo],
      procedure(Result: TSuperMessageResult)
      begin
        if Result = smrYes then
          DeleteFile(FileName);
      end);

  Usage (with More... button linking to a URL or custom action):
    var Config: TSuperMessageConfig;
    Config := TSuperMessageConfig.Create;
    try
      Config.Title      := 'Connection Failed';
      Config.Message    := 'Unable to connect to the server.';
      Config.MsgType    := smtError;
      Config.Buttons    := [smbRetry, smbCancel, smbMore];
      Config.MoreCaption := 'Help';
      Config.OnMore     := procedure begin
                             TTMSFNCUtils.OpenURL('https://help.example.com');
                           end;
      TSuperMessage.ShowConfig(Config);
    finally
      Config.Free;
    end;
}

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.StdCtrls, FMX.Layouts, FMX.Objects, FMX.Ani,
  FMX.Controls.Presentation, FMX.ImgList, FMX.Styles;

type
  { Message type — drives the default icon and title bar colour }
  TSuperMessageType = (
    smtInfo,       // Blue  — general information
    smtSuccess,    // Green — operation completed successfully
    smtWarning,    // Amber — issue / potential problem
    smtError,      // Red   — recoverable error
    smtFatal,      // Dark red — fatal / unrecoverable error
    smtQuestion,   // Teal  — question requiring user decision
    smtCustom      // No default icon; caller supplies their own bitmap
  );

  { Available response buttons }
  TSuperMessageButton  = (smbOK, smbCancel, smbYes, smbNo, smbRetry,
                          smbAbort, smbIgnore, smbClose, smbMore);
  TSuperMessageButtons = set of TSuperMessageButton;

  { Value returned from a modal call, or passed to the non-modal callback }
  TSuperMessageResult = (smrNone, smrOK, smrCancel, smrYes, smrNo,
                         smrRetry, smrAbort, smrIgnore, smrClose, smrMore);

  { Non-modal result callback }
  TSuperMessageCallback = reference to procedure(AResult: TSuperMessageResult);

  { Configuration object — covers every option }
  TSuperMessageConfig = class
  public
    { Text }
    Title       : string;             // Dialog title bar text
    Message     : string;             // Main message body (may be multi-line)

    { Behaviour }
    MsgType     : TSuperMessageType;
    Buttons     : TSuperMessageButtons;
    Modal       : Boolean;            // True = ShowModal; False = Show (non-blocking)
    Callback    : TSuperMessageCallback; // Called on close (modal or non-modal)

    { Icon / bitmap — leave nil to use the built-in SVG icon for MsgType }
    CustomBitmap : TBitmap;           // Optional; not freed by SuperMessage

    { "More..." button customisation }
    MoreCaption : string;             // Default 'More...'
    OnMore      : TProc;             // Called when More button is clicked
                                      // (dialog stays open unless OnMore closes it)

    { Appearance overrides }
    MaxWidth    : Single;             // 0 = use default (560)
    MinWidth    : Single;             // 0 = use default (320)
    Font        : TFont;              // nil = system default
    StyleBook   : TStyleBook;         // nil = inherit Application style

    constructor Create;
    destructor  Destroy; override;
  end;

  { Forward }
  TSuperMessageForm = class;

  { ------------------------------------------------------------------ }
  {  Public facade — all entry points are class methods                 }
  { ------------------------------------------------------------------ }
  TSuperMessage = class
  public
    { Simple modal shortcut }
    class function Show(const ATitle, AMessage: string;
                        AMsgType: TSuperMessageType;
                        AButtons: TSuperMessageButtons = [smbOK])
                        : TSuperMessageResult;

    { Full config — modal or non-modal depending on Config.Modal }
    class function ShowConfig(AConfig: TSuperMessageConfig)
                              : TSuperMessageResult;

    { Non-modal shortcut with inline callback }
    class procedure ShowNonModal(const ATitle, AMessage: string;
                                 AMsgType: TSuperMessageType;
                                 AButtons: TSuperMessageButtons;
                                 ACallback: TSuperMessageCallback = nil);
  end;

  { ------------------------------------------------------------------ }
  {  Internal dialog form — not intended for direct use                 }
  { ------------------------------------------------------------------ }
  TSuperMessageForm = class(TForm)
  private
    { Layout panels }
    FRootLayout    : TLayout;
    FHeaderPanel   : TRectangle;
    FBodyLayout    : TLayout;
    FIconLayout    : TLayout;
    FTextLayout    : TLayout;
    FButtonBar     : TLayout;

    { Header }
    FHeaderLabel   : TLabel;
    FHeaderLine    : TLine;

    { Body }
    FIconImage     : TImage;
    FMessageLabel  : TLabel;

    { Buttons }
    FButtons       : TObjectList<TButton>;

    { State }
    FResult        : TSuperMessageResult;
    FConfig        : TSuperMessageConfig;    // reference only, not owned

    { Build helpers }
    procedure BuildLayout;
    procedure BuildIcon;
    procedure BuildButtons;
    procedure ApplySizeConstraints;

    { Button click handler }
    procedure ButtonClick(Sender: TObject);
    { OnClose handler for non-modal auto-free }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);

    { Returns the accent colour for the given message type }
    class function AccentColor(AMsgType: TSuperMessageType): TAlphaColor;
    { Paints a simple vector icon onto a bitmap }
    class procedure DrawDefaultIcon(ABitmap: TBitmap;
                                    AMsgType: TSuperMessageType);
  public
    constructor CreateForConfig(AOwner: TComponent;
                                AConfig: TSuperMessageConfig);
    destructor  Destroy; override;

    property Result: TSuperMessageResult read FResult;
  end;

implementation

uses
  System.Math,
  FMX.Platform;

{ ========================================================================== }
{ TSuperMessageConfig                                                         }
{ ========================================================================== }

constructor TSuperMessageConfig.Create;
begin
  inherited Create;
  MsgType     := smtInfo;
  Buttons     := [smbOK];
  Modal       := True;
  MoreCaption := 'More...';
  MaxWidth    := 0;   // use defaults
  MinWidth    := 0;
  Font        := nil;
  StyleBook   := nil;
  CustomBitmap := nil;
  OnMore      := nil;
  Callback    := nil;
end;

destructor TSuperMessageConfig.Destroy;
begin
  { Font and CustomBitmap are NOT freed here — caller owns them }
  inherited;
end;

{ ========================================================================== }
{ TSuperMessage (facade)                                                      }
{ ========================================================================== }

class function TSuperMessage.Show(const ATitle, AMessage: string;
  AMsgType: TSuperMessageType; AButtons: TSuperMessageButtons): TSuperMessageResult;
var
  Cfg: TSuperMessageConfig;
begin
  Cfg := TSuperMessageConfig.Create;
  try
    Cfg.Title   := ATitle;
    Cfg.Message := AMessage;
    Cfg.MsgType := AMsgType;
    Cfg.Buttons := AButtons;
    Cfg.Modal   := True;
    Result := ShowConfig(Cfg);
  finally
    Cfg.Free;
  end;
end;

class function TSuperMessage.ShowConfig(AConfig: TSuperMessageConfig): TSuperMessageResult;
var
  Frm: TSuperMessageForm;
begin
  Result := smrNone;
  Frm := TSuperMessageForm.CreateForConfig(Application, AConfig);
  try
    if AConfig.Modal then
    begin
      Frm.ShowModal;
      Result := Frm.Result;
      if Assigned(AConfig.Callback) then
        AConfig.Callback(Result);
    end
    else
    begin
      { Non-modal: form frees itself via OnClose }
      Frm.Show;
      { Result is smrNone until the callback fires }
    end;
  except
    Frm.Free;
    raise;
  end;
  { For modal, form was shown and is now done; free it }
  if AConfig.Modal then
    Frm.Free;
end;

class procedure TSuperMessage.ShowNonModal(const ATitle, AMessage: string;
  AMsgType: TSuperMessageType; AButtons: TSuperMessageButtons;
  ACallback: TSuperMessageCallback);
var
  Cfg: TSuperMessageConfig;
begin
  Cfg := TSuperMessageConfig.Create;
  try
    Cfg.Title    := ATitle;
    Cfg.Message  := AMessage;
    Cfg.MsgType  := AMsgType;
    Cfg.Buttons  := AButtons;
    Cfg.Modal    := False;
    Cfg.Callback := ACallback;
    ShowConfig(Cfg);
  finally
    Cfg.Free;
  end;
end;

{ ========================================================================== }
{ TSuperMessageForm — layout constants                                        }
{ ========================================================================== }

const
  { Geometry }
  HEADER_HEIGHT   = 44;
  ICON_SIZE       = 48;
  ICON_AREA_WIDTH = 72;
  BODY_PADDING    = 16;
  BTN_HEIGHT      = 36;
  BTN_MIN_WIDTH   = 90;
  BTN_SPACING     = 8;
  BTN_BAR_HEIGHT  = 60;
  MSG_FONT_SIZE   = 13;
  TITLE_FONT_SIZE = 14;
  CORNER_RADIUS   = 8;
  DEFAULT_MAX_W   = 560;
  DEFAULT_MIN_W   = 320;

  { Button display order — leftmost to rightmost.
    Windows convention: affirmative (Yes/OK) left, Cancel/Close rightmost.
    Positioning pass iterates this list right-to-left so higher-index
    buttons land furthest right. }
  BUTTON_ORDER: array[0..8] of TSuperMessageButton = (
    smbMore, smbAbort, smbIgnore, smbRetry,
    smbYes, smbOK,
    smbNo, smbClose, smbCancel);

  BUTTON_CAPTIONS: array[TSuperMessageButton] of string = (
    'OK', 'Cancel', 'Yes', 'No', 'Retry', 'Abort', 'Ignore', 'Close', 'More...');

  BUTTON_RESULTS: array[TSuperMessageButton] of TSuperMessageResult = (
    smrOK, smrCancel, smrYes, smrNo, smrRetry,
    smrAbort, smrIgnore, smrClose, smrMore);

{ ========================================================================== }
{ TSuperMessageForm — construction                                            }
{ ========================================================================== }

constructor TSuperMessageForm.CreateForConfig(AOwner: TComponent;
  AConfig: TSuperMessageConfig);
begin
  inherited CreateNew(AOwner);

  FConfig  := AConfig;
  FResult  := smrNone;
  FButtons := TObjectList<TButton>.Create(False); // buttons owned by FButtonBar

  { Basic form style }
  BorderStyle    := TFmxFormBorderStyle.Single;
  Caption        := AConfig.Title;
  Position       := TFormPosition.ScreenCenter;
  FormStyle      := TFormStyle.Normal;
  Transparency   := False;

  { Inherit the caller's StyleBook so buttons/background match the app theme.
    If nil, FMX falls back to the Application's StyleBook automatically. }
  if Assigned(AConfig.StyleBook) then
    StyleBook := AConfig.StyleBook;

  { Build all visual elements }
  BuildLayout;
  BuildIcon;
  BuildButtons;
  ApplySizeConstraints;

  { For non-modal, free the form automatically when closed }
  OnClose := FormClose;
end;

destructor TSuperMessageForm.Destroy;
begin
  FButtons.Free;
  inherited;
end;

{ ========================================================================== }
{ TSuperMessageForm — BuildLayout                                             }
{ ========================================================================== }

procedure TSuperMessageForm.BuildLayout;
var
  MaxW, MinW: Single;
begin
  MaxW := IfThen(FConfig.MaxWidth > 0, FConfig.MaxWidth, DEFAULT_MAX_W);
  MinW := IfThen(FConfig.MinWidth > 0, FConfig.MinWidth, DEFAULT_MIN_W);

  { --- Root layout fills the form --- }
  FRootLayout := TLayout.Create(Self);
  FRootLayout.Parent := Self;
  FRootLayout.Align  := TAlignLayout.Client;

  { --- Header panel with colour accent --- }
  FHeaderPanel := TRectangle.Create(Self);
  FHeaderPanel.Parent  := FRootLayout;
  FHeaderPanel.Align   := TAlignLayout.Top;
  FHeaderPanel.Height  := HEADER_HEIGHT;
  FHeaderPanel.Stroke.Kind := TBrushKind.None;
  FHeaderPanel.Fill.Color  := AccentColor(FConfig.MsgType);
  FHeaderPanel.XRadius := 0;
  FHeaderPanel.YRadius := 0;

  FHeaderLabel := TLabel.Create(Self);
  FHeaderLabel.Parent    := FHeaderPanel;
  FHeaderLabel.Align     := TAlignLayout.Client;
  FHeaderLabel.Margins.Left  := BODY_PADDING + ICON_AREA_WIDTH;
  FHeaderLabel.Margins.Right := BODY_PADDING;
  FHeaderLabel.Text      := FConfig.Title;
  FHeaderLabel.TextSettings.FontColor := TAlphaColorRec.White;
  FHeaderLabel.TextSettings.Font.Size := TITLE_FONT_SIZE;
  FHeaderLabel.TextSettings.Font.Style := [TFontStyle.fsBold];
  FHeaderLabel.TextSettings.VertAlign := TTextAlign.Center;
  if Assigned(FConfig.Font) then
    FHeaderLabel.TextSettings.Font.Family := FConfig.Font.Family;

  { --- Thin line under header --- }
  FHeaderLine := TLine.Create(Self);
  FHeaderLine.Parent  := FRootLayout;
  FHeaderLine.Align   := TAlignLayout.Top;
  FHeaderLine.Height  := 1;
  FHeaderLine.Stroke.Color     := AccentColor(FConfig.MsgType);
  FHeaderLine.Stroke.Thickness := 1;

  { --- Body area: icon on left, text on right --- }
  FBodyLayout := TLayout.Create(Self);
  FBodyLayout.Parent  := FRootLayout;
  FBodyLayout.Align   := TAlignLayout.Client;
  FBodyLayout.Padding.Left   := BODY_PADDING;
  FBodyLayout.Padding.Right  := BODY_PADDING;
  FBodyLayout.Padding.Top    := BODY_PADDING;
  FBodyLayout.Padding.Bottom := 0;

  FIconLayout := TLayout.Create(Self);
  FIconLayout.Parent := FBodyLayout;
  FIconLayout.Align  := TAlignLayout.Left;
  FIconLayout.Width  := ICON_AREA_WIDTH;

  FTextLayout := TLayout.Create(Self);
  FTextLayout.Parent := FBodyLayout;
  FTextLayout.Align  := TAlignLayout.Client;

  FMessageLabel := TLabel.Create(Self);
  FMessageLabel.Parent     := FTextLayout;
  FMessageLabel.Align      := TAlignLayout.Client;
  FMessageLabel.WordWrap   := True;
  FMessageLabel.AutoSize   := False;
  FMessageLabel.Text       := FConfig.Message;
  FMessageLabel.TextSettings.Font.Size  := MSG_FONT_SIZE;
  FMessageLabel.TextSettings.VertAlign  := TTextAlign.Leading;
  FMessageLabel.TextSettings.HorzAlign  := TTextAlign.Leading;
  FMessageLabel.TextSettings.Trimming   := TTextTrimming.None;
  if Assigned(FConfig.Font) then
    FMessageLabel.TextSettings.Font.Family := FConfig.Font.Family;

  { --- Button bar at bottom --- }
  FButtonBar := TLayout.Create(Self);
  FButtonBar.Parent  := FRootLayout;
  FButtonBar.Align   := TAlignLayout.Bottom;
  FButtonBar.Height  := BTN_BAR_HEIGHT;
  FButtonBar.Padding.Right  := BODY_PADDING;
  FButtonBar.Padding.Left   := BODY_PADDING;
  FButtonBar.Padding.Top    := (BTN_BAR_HEIGHT - BTN_HEIGHT) div 2;
  FButtonBar.Padding.Bottom := (BTN_BAR_HEIGHT - BTN_HEIGHT) div 2;
end;

{ ========================================================================== }
{ TSuperMessageForm — BuildIcon                                               }
{ ========================================================================== }

procedure TSuperMessageForm.BuildIcon;
var
  Bmp: TBitmap;
begin
  FIconImage := TImage.Create(Self);
  FIconImage.Parent   := FIconLayout;
  FIconImage.Align    := TAlignLayout.Center;
  FIconImage.Width    := ICON_SIZE;
  FIconImage.Height   := ICON_SIZE;
  FIconImage.WrapMode := TImageWrapMode.Fit;

  if (FConfig.MsgType = smtCustom) and Assigned(FConfig.CustomBitmap) then
    FIconImage.Bitmap.Assign(FConfig.CustomBitmap)
  else
  begin
    { Draw into a local bitmap then Assign — never set TImage.Bitmap directly
      as the property setter copies the value and the Create result leaks. }
    Bmp := TBitmap.Create(ICON_SIZE * 2, ICON_SIZE * 2);
    try
      DrawDefaultIcon(Bmp, FConfig.MsgType);
      FIconImage.Bitmap.Assign(Bmp);
    finally
      Bmp.Free;
    end;
  end;
end;

{ ========================================================================== }
{ TSuperMessageForm — BuildButtons                                            }
{ ========================================================================== }

procedure TSuperMessageForm.BuildButtons;
var
  B       : TSuperMessageButton;
  Btn     : TButton;
  i       : Integer;
  Caption : string;
begin
  { Create buttons in display order (left to right = low to high index).
    Positions are set later in ApplySizeConstraints once FinalW is known. }
  for i := 0 to High(BUTTON_ORDER) do
  begin
    B := BUTTON_ORDER[i];
    if not (B in FConfig.Buttons) then Continue;

    Btn := TButton.Create(Self);
    Btn.Parent  := FButtonBar;
    Btn.Align   := TAlignLayout.None;
    Btn.Height  := BTN_HEIGHT;
    Btn.Tag     := Ord(B);

    if B = smbMore then Caption := FConfig.MoreCaption
    else Caption := BUTTON_CAPTIONS[B];
    Btn.Text  := Caption;
    Btn.Width := Max(BTN_MIN_WIDTH, Length(Caption) * 9 + 32);

    Btn.OnClick := ButtonClick;
    if B in [smbOK, smbYes]              then Btn.Default := True;
    if B in [smbCancel, smbNo, smbClose] then Btn.Cancel  := True;

    FButtons.Add(Btn);
  end;
end;

{ ========================================================================== }
{ TSuperMessageForm — ApplySizeConstraints                                   }
{ ========================================================================== }

procedure TSuperMessageForm.ApplySizeConstraints;
var
  MaxW, MinW   : Single;
  TextH        : Single;
  BodyH        : Single;
  TotalH       : Single;
  TotalBtnW    : Single;
  I            : Integer;
  TempBmp      : TBitmap;
  TextRect     : TRectF;
  FinalW       : Single;
  BtnRight     : Single;
begin
  MaxW := IfThen(FConfig.MaxWidth > 0, FConfig.MaxWidth, DEFAULT_MAX_W);
  MinW := IfThen(FConfig.MinWidth > 0, FConfig.MinWidth, DEFAULT_MIN_W);

  { Calculate minimum width needed for all buttons }
  TotalBtnW := BODY_PADDING * 2;
  for I := 0 to FButtons.Count - 1 do
    TotalBtnW := TotalBtnW + FButtons[I].Width + BTN_SPACING;

  { Desired inner text width (subtract icon area and padding) }
  FinalW := Max(MinW, TotalBtnW);
  FinalW := Min(FinalW, MaxW);

  { Estimate the text height at the chosen width using a scratch bitmap }
  TextH := MSG_FONT_SIZE * 2.4;  // safe default
  TempBmp := TBitmap.Create(1, 1);
  try
    if TempBmp.Canvas.BeginScene then
    try
      TempBmp.Canvas.Font.Size   := MSG_FONT_SIZE;
      TempBmp.Canvas.Font.Family := FMessageLabel.TextSettings.Font.Family;

      TextRect := RectF(0, 0,
        FinalW - ICON_AREA_WIDTH - BODY_PADDING * 3,
        10000);

      TempBmp.Canvas.MeasureText(TextRect,
        FConfig.Message, True,
        [], TTextAlign.Leading, TTextAlign.Leading);

      TextH := TextRect.Height;
    finally
      TempBmp.Canvas.EndScene;
    end;
  finally
    TempBmp.Free;
  end;

  { Clamp text height: at least 3 lines, at most ~12 lines }
  TextH := Max(TextH, MSG_FONT_SIZE * 3.5);
  TextH := Min(TextH, MSG_FONT_SIZE * 14);

  { Body height = max(icon, text) + top padding }
  BodyH := Max(TextH, ICON_SIZE) + BODY_PADDING * 2;

  { Check if we need a wider form to fit text on fewer lines }
  if TextH > MSG_FONT_SIZE * 6 then
    FinalW := MaxW;

  TotalH := HEADER_HEIGHT + 1 {line} + BodyH + BTN_BAR_HEIGHT;

  { Apply to form }
  Width  := Round(FinalW);
  Height := Round(TotalH);

  { Position buttons right-to-left.  We use BODY_PADDING * 2 as the right
    margin because Windows 11's drop-shadow / resize frame consumes ~8-10px
    of the logical window edge, so a single BODY_PADDING (16) appeared as
    ~0px visually.  32px gives a correct ~16px visual gap. }
  BtnRight := FinalW - BODY_PADDING * 2;
  for I := FButtons.Count - 1 downto 0 do
  begin
    FButtons[I].Position.X := BtnRight - FButtons[I].Width;
    FButtons[I].Position.Y := (BTN_BAR_HEIGHT - BTN_HEIGHT) / 2;
    BtnRight := FButtons[I].Position.X - BTN_SPACING;
  end;
end;

{ ========================================================================== }
{ TSuperMessageForm — ButtonClick                                             }
{ ========================================================================== }

procedure TSuperMessageForm.ButtonClick(Sender: TObject);
var
  Btn : TButton;
  B   : TSuperMessageButton;
begin
  Btn := Sender as TButton;
  B   := TSuperMessageButton(Btn.Tag);

  if B = smbMore then
  begin
    { More button: invoke the callback but don't close the dialog }
    if Assigned(FConfig.OnMore) then
      FConfig.OnMore();
    Exit;
  end;

  FResult := BUTTON_RESULTS[B];

  if Assigned(FConfig.Callback) then
    FConfig.Callback(FResult);

  if FConfig.Modal then
    ModalResult := mrOk    // signals ShowModal to return
  else
    Close;
end;

procedure TSuperMessageForm.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  if not FConfig.Modal then
    Action := TCloseAction.caFree;
  { Modal: leave Action at its default (caHide); ShowConfig frees the form
    explicitly after ShowModal returns. }
end;

{ ========================================================================== }
{ TSuperMessageForm — AccentColor                                             }
{ ========================================================================== }

class function TSuperMessageForm.AccentColor(
  AMsgType: TSuperMessageType): TAlphaColor;
begin
  case AMsgType of
    smtInfo     : Result := $FF2196F3;  // Material Blue
    smtSuccess  : Result := $FF4CAF50;  // Material Green
    smtWarning  : Result := $FFFF9800;  // Material Amber
    smtError    : Result := $FFF44336;  // Material Red
    smtFatal    : Result := $FF7B1FA2;  // Deep Purple
    smtQuestion : Result := $FF009688;  // Teal
    smtCustom   : Result := $FF607D8B;  // Blue Grey
  else
    Result := $FF607D8B;
  end;
end;

{ ========================================================================== }
{ TSuperMessageForm — DrawDefaultIcon                                         }
{                                                                             }
{ Draws a simple flat-style icon for each message type directly onto the     }
{ supplied bitmap.  No external images required.                              }
{ ========================================================================== }

class procedure TSuperMessageForm.DrawDefaultIcon(ABitmap: TBitmap;
  AMsgType: TSuperMessageType);
var
  C     : TCanvas;
  W, H  : Single;
  Cx, Cy, R : Single;
  BgColor, FgColor : TAlphaColor;
  Glyph : string;
begin
  if not Assigned(ABitmap) then Exit;

  C := ABitmap.Canvas;
  if not C.BeginScene then Exit;
  try
    W  := ABitmap.Width;
    H  := ABitmap.Height;
    Cx := W / 2;
    Cy := H / 2;
    R  := W * 0.44;

    { Background: transparent }
    C.ClearRect(RectF(0, 0, W, H), TAlphaColorRec.Null);

    BgColor := AccentColor(AMsgType);
    FgColor := TAlphaColorRec.White;

    { Draw filled circle }
    C.Fill.Color := BgColor;
    C.Fill.Kind  := TBrushKind.Solid;
    C.Stroke.Kind := TBrushKind.None;
    C.FillEllipse(RectF(Cx - R, Cy - R, Cx + R, Cy + R), 1);

    { Choose glyph / symbol }
    case AMsgType of
      smtInfo     : Glyph := 'i';
      smtSuccess  : Glyph := #$2713;   // check mark
      smtWarning  : Glyph := '!';
      smtError    : Glyph := #$00D7;   // multiply (X)
      smtFatal    : Glyph := #$2716;   // heavy X
      smtQuestion : Glyph := '?';
    else
      Glyph := '';
    end;

    if Glyph <> '' then
    begin
      C.Fill.Color := FgColor;
      C.Fill.Kind  := TBrushKind.Solid;
      C.Font.Size  := Round(R * 1.1);
      C.Font.Style := [TFontStyle.fsBold];

      C.FillText(
        RectF(0, 0, W, H),
        Glyph,
        False, 1,
        [],
        TTextAlign.Center,
        TTextAlign.Center);
    end;

    { Extra decoration for smtFatal: draw a second concentric ring }
    if AMsgType = smtFatal then
    begin
      C.Stroke.Color     := FgColor;
      C.Stroke.Thickness := W * 0.03;
      C.Stroke.Kind      := TBrushKind.Solid;
      C.Fill.Kind        := TBrushKind.None;
      C.DrawEllipse(
        RectF(Cx - R * 0.75, Cy - R * 0.75,
              Cx + R * 0.75, Cy + R * 0.75), 0.5);
    end;

  finally
    C.EndScene;
  end;
end;

end.
